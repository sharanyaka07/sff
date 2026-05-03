import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/encryption_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/local/models/message_model.dart';
import '../../../data/local/database/db_helper.dart';

enum BtConnectionState {
  unknown,
  unavailable,
  off,
  scanning,
  idle,
  connecting,
  connected,
}

class BluetoothController extends ChangeNotifier {

  // ── Native channel to talk to MainActivity GATT server ───────────
  static const _gattChannel    = MethodChannel('com.safeconnect.gatt/server');
  static const _messageChannel = EventChannel('com.safeconnect.gatt/messages');

  // ── BLE UUIDs — must match MainActivity.kt ───────────────────────
  static const String serviceUuid = '12345678-1234-1234-1234-123456789abc';
  static const String charUuid    = 'abcd1234-1234-1234-1234-abcdef123456';

  // ── State ────────────────────────────────────────────────────────
  BtConnectionState _state = BtConnectionState.unknown;
  BtConnectionState get state => _state;

  final List<ScanResult> _scanResults = [];
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);

  // Only show devices that have a real name (not just MAC address)
  List<ScanResult> get namedScanResults => _scanResults
      .where((r) => _getDeviceName(r) != r.device.remoteId.str)
      .toList();

  // GATT client connections (when WE connect TO another device)
  final List<BluetoothDevice> _connectedDevices = [];
  List<BluetoothDevice> get connectedDevices =>
      List.unmodifiable(_connectedDevices);

  // Write characteristics for each GATT client connection
  final Map<String, BluetoothCharacteristic> _writeChars = {};

  // Chunk buffers for reassembling split messages (client side)
  final Map<String, StringBuffer> _chunkBuffers = {};
  final Map<String, int> _expectedChunks = {};
  final Map<String, int> _receivedChunks = {};

  final List<MessageModel> _messages = [];
  List<MessageModel> get messages => List.unmodifiable(_messages);

  String _deviceName = 'Unknown';
  String get deviceName => _deviceName;

  String _deviceId = '';
  String get deviceId => _deviceId;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  // True if either: we connected to someone, OR someone connected to us
  bool get isConnected =>
    _connectedDevices.isNotEmpty || _serverHasClients;
bool _serverHasClients = false;
bool get serverHasClients => _serverHasClients; // ← ADD THIS

  // Connected client name (when someone connects TO us)
  String _connectedClientName = '';
  String get connectedClientName => _connectedClientName;

  // Not needed anymore — native server handles advertising
  bool get isAdvertising => true;

  StreamSubscription? _scanSubscription;
  StreamSubscription? _adapterStateSubscription;
  StreamSubscription? _nativeMessageSubscription;
  bool _isInitialized = false;

  // ── Init ─────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _loadDeviceIdentity();
    _listenToAdapterState();
    await _loadMessagesFromDb();
    await _startNativeGattServer();
    _listenForNativeMessages();
    AppLogger.bluetooth('BluetoothController ready. Name: $_deviceName');
  }

  // ── Start native GATT server in MainActivity ──────────────────────
  Future<void> _startNativeGattServer() async {
    try {
      await _gattChannel.invokeMethod('startGattServer');
      AppLogger.bluetooth('Native GATT server started ✅');
    } catch (e) {
      AppLogger.error('Failed to start GATT server', error: e);
    }
  }

  // ── Listen for messages AND connection events from native server ──
  void _listenForNativeMessages() {
    _nativeMessageSubscription = _messageChannel
        .receiveBroadcastStream()
        .listen((dynamic payload) {
      if (payload is String) {

        // ── Connection event: a phone connected TO us ─────────────
        if (payload.startsWith('CLIENT_CONNECTED:')) {
          final clientName = payload.replaceFirst('CLIENT_CONNECTED:', '');
          _serverHasClients = true;
          _connectedClientName = clientName;
          _setState(BtConnectionState.connected);
          AppLogger.bluetooth('Client connected to our server: $clientName ✅');
          notifyListeners();
          return;
        }

        // ── Disconnection event ───────────────────────────────────
        if (payload == 'CLIENT_DISCONNECTED') {
          _serverHasClients = false;
          _connectedClientName = '';
          if (_connectedDevices.isEmpty) {
            _setState(BtConnectionState.idle);
          }
          AppLogger.bluetooth('Client disconnected from our server');
          notifyListeners();
          return;
        }

        // ── Real message payload ──────────────────────────────────
        AppLogger.bluetooth('Native server received message ✅');
        _serverHasClients = true;
        _processReceivedMessage(payload);
        notifyListeners();
      }
    }, onError: (e) {
      AppLogger.error('Native message stream error', error: e);
    });
  }

  Future<void> _loadDeviceIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceName =
        prefs.getString('user_name') ?? 'User_${_shortId()}';
    _deviceId = prefs.getString('device_id') ?? const Uuid().v4();
    await prefs.setString('device_id', _deviceId);
    notifyListeners();
  }

  String _shortId() =>
      DateTime.now().millisecondsSinceEpoch.toString().substring(8);

  void _listenToAdapterState() {
    _adapterStateSubscription =
        FlutterBluePlus.adapterState.listen((adapterState) {
      AppLogger.bluetooth('Adapter state: $adapterState');
      if (adapterState == BluetoothAdapterState.on) {
        _setState(BtConnectionState.idle);
        _startNativeGattServer();
      } else if (adapterState == BluetoothAdapterState.off) {
        _setState(BtConnectionState.off);
        _scanResults.clear();
        _connectedDevices.clear();
        _writeChars.clear();
        _serverHasClients = false;
        _connectedClientName = '';
        notifyListeners();
      }
    });
  }

  Future<void> _loadMessagesFromDb() async {
    try {
      final saved = await DbHelper.getMessages();
      _messages.addAll(saved);
      AppLogger.bluetooth('Loaded ${saved.length} messages from DB');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Failed to load messages from DB', error: e);
    }
  }

  // ── Name helpers ─────────────────────────────────────────────────
  String _getDeviceName(ScanResult result) {
    if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    }
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }
    return result.device.remoteId.str;
  }

  String getDisplayName(ScanResult result) => _getDeviceName(result);

  // ── Scan for nearby devices ───────────────────────────────────────
  Future<void> startScan() async {
    if (_isScanning) return;

    AppLogger.bluetooth('Requesting permissions...');
    await Permission.locationWhenInUse.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothAdvertise.request();

    final granted = await Permission.locationWhenInUse.isGranted &&
        await Permission.bluetoothScan.isGranted &&
        await Permission.bluetoothConnect.isGranted;

    if (!granted) {
      if (await Permission.bluetoothScan.isPermanentlyDenied ||
          await Permission.locationWhenInUse.isPermanentlyDenied) {
        await openAppSettings();
      }
      _setState(BtConnectionState.off);
      notifyListeners();
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _setState(BtConnectionState.off);
      notifyListeners();
      try {
        await FlutterBluePlus.turnOn();
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        AppLogger.error('Could not turn on Bluetooth', error: e);
        return;
      }
    }

    _scanResults.clear();
    _isScanning = true;
    _setState(BtConnectionState.scanning);
    notifyListeners();

    AppLogger.bluetooth('BLE scan started ✅');

    try {
      await _scanSubscription?.cancel();

      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          bool changed = false;
          for (final result in results) {
            final exists = _scanResults.any(
              (r) => r.device.remoteId == result.device.remoteId,
            );
            if (!exists) {
              _scanResults.add(result);
              changed = true;

              final name = _getDeviceName(result);
              AppLogger.bluetooth('Found: $name | RSSI: ${result.rssi}');

              // Notify only for Safe Connect devices
              final serviceUuids = result.advertisementData.serviceUuids
                  .map((u) => u.toString().toLowerCase())
                  .toList();
              if (serviceUuids.any((u) => u.contains('12345678'))) {
                NotificationService.showBluetoothDeviceFound(
                  deviceName: name,
                  deviceCount: _scanResults.length,
                );
              }
            }
          }
          if (changed) notifyListeners();
        },
        onError: (e) => AppLogger.error('Scan stream error', error: e),
      );

      // No UUID filter — show ALL named devices
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
        continuousUpdates: true,
      );

      await FlutterBluePlus.isScanning
          .where((scanning) => scanning == false)
          .first;

      await stopScan();
    } catch (e) {
      AppLogger.error('Scan failed', error: e);
      _isScanning = false;
      _setState(BtConnectionState.idle);
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    _setState(isConnected
        ? BtConnectionState.connected
        : BtConnectionState.idle);
    AppLogger.bluetooth(
        'Scan stopped. Found ${_scanResults.length} devices');
    notifyListeners();
  }

  // ── Connect to a Safe Connect device (GATT client) ───────────────
  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (_connectedDevices.any((d) => d.remoteId == device.remoteId)) {
      AppLogger.bluetooth('Already connected to ${device.platformName}');
      return true;
    }

    _setState(BtConnectionState.connecting);
    notifyListeners();

    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      // Discover services
      final services = await device.discoverServices();
      BluetoothCharacteristic? targetChar;

      for (final svc in services) {
        if (svc.uuid.toString().toLowerCase().contains('12345678')) {
          for (final c in svc.characteristics) {
            if (c.uuid.toString().toLowerCase().contains('abcd1234')) {
              targetChar = c;
              break;
            }
          }
        }
        if (targetChar != null) break;
      }

      if (targetChar == null) {
        AppLogger.warning(
            'Safe Connect service NOT found on ${device.platformName}');
        await device.disconnect();
        _setState(BtConnectionState.idle);
        notifyListeners();
        return false;
      }

      // Subscribe to notifications — receive messages from other phone
      await targetChar.setNotifyValue(true);
      targetChar.lastValueStream.listen((data) {
        if (data.isNotEmpty) {
          _onClientDataReceived(data, device);
        }
      });

      _writeChars[device.remoteId.str] = targetChar;
      _connectedDevices.add(device);
      _setState(BtConnectionState.connected);
      notifyListeners();

      // Watch for disconnection
      device.connectionState.listen((connectionState) {
        if (connectionState == BluetoothConnectionState.disconnected) {
          _connectedDevices
              .removeWhere((d) => d.remoteId == device.remoteId);
          _writeChars.remove(device.remoteId.str);
          _chunkBuffers.remove(device.remoteId.str);
          _expectedChunks.remove(device.remoteId.str);
          _receivedChunks.remove(device.remoteId.str);
          if (_connectedDevices.isEmpty && !_serverHasClients) {
            _setState(BtConnectionState.idle);
          }
          AppLogger.bluetooth('Disconnected: ${device.platformName}');
          notifyListeners();
        }
      });

      AppLogger.bluetooth('Connected to ${device.platformName} ✅');
      return true;
    } catch (e) {
      AppLogger.error('Connect failed: $e', error: e);
      _setState(BtConnectionState.idle);
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (_) {}
    _connectedDevices.removeWhere((d) => d.remoteId == device.remoteId);
    _writeChars.remove(device.remoteId.str);
    if (_connectedDevices.isEmpty && !_serverHasClients) {
      _setState(BtConnectionState.idle);
    }
    notifyListeners();
  }

  // ── Send message to ALL connected devices ────────────────────────
  Future<bool> sendMessage(String content) async {
    if (!isConnected) {
      AppLogger.warning('No connected devices — cannot send');
      return false;
    }

    try {
      final encrypted = EncryptionService.encrypt(content);
      final msgId = const Uuid().v4();

      final message = MessageModel(
        id: msgId,
        senderId: _deviceId,
        senderName: _deviceName,
        content: content,
        encryptedContent: encrypted,
        type: MessageType.text,
        status: MessageStatus.sending,
        timestamp: DateTime.now(),
        isMe: true,
        isEncrypted: true,
      );
      _messages.add(message);
      await DbHelper.insertMessage(message, channel: 'bluetooth');
      notifyListeners();

      final payload = jsonEncode({
        'id': msgId,
        'senderId': _deviceId,
        'senderName': _deviceName,
        'content': encrypted,
        'timestamp': DateTime.now().toIso8601String(),
        'isEncrypted': true,
      });

      bool anySent = false;

      // Path 1 — Write to devices WE connected to (GATT client)
      for (final device in _connectedDevices) {
        final char = _writeChars[device.remoteId.str];
        if (char == null) continue;
        final ok = await _sendChunked(char, payload);
        if (ok) anySent = true;
      }

      // Path 2 — Notify devices connected TO US (native GATT server)
      try {
        final serverSent = await _gattChannel.invokeMethod<bool>(
          'sendMessage',
          {'payload': payload},
        ) ?? false;
        if (serverSent) anySent = true;
      } catch (e) {
        AppLogger.error('Native server send failed', error: e);
      }

      // Update status
      final idx = _messages.indexWhere((m) => m.id == msgId);
      if (idx != -1) {
        _messages[idx] = message.copyWith(
          status: anySent ? MessageStatus.sent : MessageStatus.failed,
        );
        notifyListeners();
      }

      AppLogger.bluetooth('Message sent: ${anySent ? "✅" : "❌ failed"}');
      return anySent;
    } catch (e) {
      AppLogger.error('sendMessage failed', error: e);
      return false;
    }
  }

  // ── Chunked GATT write ───────────────────────────────────────────
  Future<bool> _sendChunked(
      BluetoothCharacteristic char, String payload) async {
    try {
      final bytes = utf8.encode(payload);
      const chunkSize = 180;
      final total = (bytes.length / chunkSize).ceil();

      for (int i = 0; i < total; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize).clamp(0, bytes.length);
        final chunk = bytes.sublist(start, end);

        final packet = Uint8List(chunk.length + 2);
        packet[0] = i;
        packet[1] = total;
        packet.setRange(2, packet.length, chunk);

        await char.write(packet, withoutResponse: false);
        await Future.delayed(const Duration(milliseconds: 50));
      }
      AppLogger.bluetooth('Sent $total chunks via GATT client ✅');
      return true;
    } catch (e) {
      AppLogger.error('Chunked write failed', error: e);
      return false;
    }
  }

  // ── Receive chunks from GATT client connection ───────────────────
  void _onClientDataReceived(List<int> data, BluetoothDevice device) {
    try {
      if (data.length < 3) return;

      final chunkIndex  = data[0];
      final totalChunks = data[1];
      final chunkData   = data.sublist(2);
      final devId = device.remoteId.str;

      if (chunkIndex == 0) {
        _chunkBuffers[devId]   = StringBuffer();
        _expectedChunks[devId] = totalChunks;
        _receivedChunks[devId] = 0;
      }

      _chunkBuffers[devId]?.write(utf8.decode(chunkData));
      _receivedChunks[devId] = (_receivedChunks[devId] ?? 0) + 1;

      if (_receivedChunks[devId] == _expectedChunks[devId]) {
        final fullPayload = _chunkBuffers[devId]!.toString();
        _chunkBuffers.remove(devId);
        _expectedChunks.remove(devId);
        _receivedChunks.remove(devId);
        AppLogger.bluetooth('All chunks received from ${device.platformName}');
        _processReceivedMessage(fullPayload);
      }
    } catch (e) {
      AppLogger.error('Client data receive error', error: e);
    }
  }

  // ── Parse and store a received message ──────────────────────────
  void _processReceivedMessage(String payload) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;

      if (map['senderId'] == _deviceId) return;

      final msgId = map['id'] as String;
      if (_messages.any((m) => m.id == msgId)) return;

      final rawContent   = map['content'] as String;
      final wasEncrypted = map['isEncrypted'] as bool? ?? false;
      final senderName   = map['senderName'] as String? ?? 'Unknown';

      String displayContent = rawContent;
      if (wasEncrypted) {
        try {
          displayContent = EncryptionService.decrypt(rawContent);
        } catch (_) {
          displayContent = rawContent;
        }
      }

      final message = MessageModel(
        id: msgId,
        senderId: map['senderId'] as String,
        senderName: senderName,
        content: displayContent,
        type: MessageType.text,
        status: MessageStatus.delivered,
        timestamp: DateTime.parse(map['timestamp'] as String),
        isMe: false,
        isEncrypted: wasEncrypted,
      );

      _messages.add(message);
      DbHelper.insertMessage(message, channel: 'bluetooth');
      AppLogger.bluetooth('✅ Message received from $senderName');

      NotificationService.showMessageNotification(
        senderName: senderName,
        message: displayContent,
        channel: 'bluetooth',
      );

      notifyListeners();
    } catch (e) {
      AppLogger.error('processReceivedMessage failed', error: e);
    }
  }

  void injectTestMessage(String content) {
    final message = MessageModel(
      id: const Uuid().v4(),
      senderId: 'test-001',
      senderName: 'Test Device',
      content: content,
      type: MessageType.text,
      status: MessageStatus.delivered,
      timestamp: DateTime.now(),
      isMe: false,
    );
    _messages.add(message);
    notifyListeners();
    AppLogger.bluetooth('Test message injected: $content');
  }

  void _setState(BtConnectionState newState) {
    _state = newState;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    DbHelper.clearMessages();
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _nativeMessageSubscription?.cancel();
    _gattChannel.invokeMethod('stopGattServer').catchError((_) {});
    super.dispose();
  }
}