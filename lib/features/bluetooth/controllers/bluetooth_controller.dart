import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/encryption_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/local/models/message_model.dart';
import '../../../data/local/database/db_helper.dart';

const String kServiceUUID = '12345678-1234-1234-1234-123456789abc';
const String kCharacteristicUUID = 'abcd1234-ab12-ab12-ab12-abcdef123456';

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
  // ── State ────────────────────────────────────────────────────────
  BtConnectionState _state = BtConnectionState.unknown;
  BtConnectionState get state => _state;

  final List<ScanResult> _scanResults = [];
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);

  final List<BluetoothDevice> _connectedDevices = [];
  List<BluetoothDevice> get connectedDevices =>
      List.unmodifiable(_connectedDevices);

  final List<MessageModel> _messages = [];
  List<MessageModel> get messages => List.unmodifiable(_messages);

  String _deviceName = 'Unknown';
  String get deviceName => _deviceName;

  String _deviceId = '';
  String get deviceId => _deviceId;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  // ── Internal ─────────────────────────────────────────────────────
  final Map<String, BluetoothCharacteristic> _characteristics = {};
  final Set<String> _seenMessageIds = {};
  // Per-device buffers to avoid mixing packets from different devices
  final Map<String, List<int>> _deviceBuffers = {};
  StreamSubscription? _scanSubscription;
  StreamSubscription? _adapterStateSubscription;

  // ── Init ─────────────────────────────────────────────────────────
  Future<void> initialize() async {

    
    await _loadDeviceIdentity();
    _listenToAdapterState();
    await _loadMessagesFromDb();
    AppLogger.bluetooth(
      'BluetoothController initialized. Device: $_deviceName',
    );
  }

  Future<void> _loadDeviceIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceName =
        prefs.getString('user_name') ?? 'User_${_generateShortId()}';
    _deviceId = prefs.getString('device_id') ?? const Uuid().v4();
    await prefs.setString('device_id', _deviceId);
    notifyListeners();
  }

  String _generateShortId() {
    return DateTime.now().millisecondsSinceEpoch.toString().substring(8);
  }

  void _listenToAdapterState() {
    _adapterStateSubscription =
        FlutterBluePlus.adapterState.listen((adapterState) {
      AppLogger.bluetooth('Adapter state: $adapterState');
      if (adapterState == BluetoothAdapterState.on) {
        _setState(BtConnectionState.idle);
      } else if (adapterState == BluetoothAdapterState.off) {
        _setState(BtConnectionState.off);
        _scanResults.clear();
        _connectedDevices.clear();
        notifyListeners();
      }
    });
  }

  // ── Load messages from DB on startup ─────────────────────────────
  Future<void> _loadMessagesFromDb() async {
    try {
      final savedMessages = await DbHelper.getMessages();
      _messages.addAll(savedMessages);
      AppLogger.info(
        'Loaded ${savedMessages.length} messages from DB',
        tag: 'DB',
      );
      notifyListeners();
    } catch (e) {
      AppLogger.error('Failed to load messages from DB', error: e);
    }
  }

  // ── Get best available device name ────────────────────────────────
  String _getDeviceName(ScanResult result) {
    // 1. Try advertisement local name (most reliable)
    final advName = result.advertisementData.advName;
    if (advName.isNotEmpty) return advName;

    // 2. Try platform name
    final platformName = result.device.platformName;
    if (platformName.isNotEmpty) return platformName;

    // 3. Fall back to MAC address
    return result.device.remoteId.str;
  }

  // Public getter for UI to use same logic
  String getDisplayName(ScanResult result) => _getDeviceName(result);

  // ── Scanning ─────────────────────────────────────────────────────
  Future<void> startScan() async {
    if (_isScanning) return;

    AppLogger.bluetooth('Starting scan process...');

    final locationStatus = await Permission.locationWhenInUse.request();
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final bluetoothAdvertise = await Permission.bluetoothAdvertise.request();

    AppLogger.bluetooth(
      'Permissions → Location: $locationStatus | '
      'Scan: $bluetoothScan | Connect: $bluetoothConnect | '
      'Advertise: $bluetoothAdvertise',
    );

    final granted = locationStatus.isGranted &&
        bluetoothScan.isGranted &&
        bluetoothConnect.isGranted;

    if (!granted) {
      if (bluetoothScan.isPermanentlyDenied ||
          bluetoothConnect.isPermanentlyDenied ||
          locationStatus.isPermanentlyDenied) {
        AppLogger.warning('Permanently denied — opening settings');
        await openAppSettings();
      }
      _setState(BtConnectionState.off);
      notifyListeners();
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      AppLogger.warning('Bluetooth is OFF — asking user to enable');
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

              // FIX: Use _getDeviceName for proper name resolution
              final name = _getDeviceName(result);

              AppLogger.bluetooth(
                'Found: $name (${result.device.remoteId}) '
                'RSSI: ${result.rssi}',
              );

              // Notify user a device is nearby
              NotificationService.showBluetoothDeviceFound(
                deviceName: name,
                deviceCount: _scanResults.length,
              );
            }
          }
          if (changed) notifyListeners();
        },
        onError: (e) => AppLogger.error('Scan stream error', error: e),
      );

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
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
    _setState(BtConnectionState.idle);
    AppLogger.bluetooth(
      'Scan stopped. Found ${_scanResults.length} devices',
    );
    notifyListeners();
  }

  // ── Connecting (with retry logic) ────────────────────────────────
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _setState(BtConnectionState.connecting);
      AppLogger.bluetooth('Connecting to ${device.platformName}...');

      // Disconnect first if already connected
      if (device.isConnected) {
        await device.disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Connect with retry — up to 3 attempts
      bool connected = false;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          await device.connect(
            timeout: const Duration(seconds: 15),
            autoConnect: false,
          );
          connected = true;
          AppLogger.bluetooth('Connected on attempt $attempt ✅');
          break;
        } catch (e) {
          AppLogger.warning('Attempt $attempt failed: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt));
          }
        }
      }

      if (!connected) {
        _setState(BtConnectionState.idle);
        return false;
      }

      // Wait for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 300));

      // Discover services with retry
      List<BluetoothService> services = [];
      for (int i = 0; i < 3; i++) {
        try {
          services = await device.discoverServices();
          if (services.isNotEmpty) break;
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          AppLogger.warning('Service discovery attempt ${i + 1} failed');
        }
      }

      AppLogger.bluetooth('Discovered ${services.length} services');

      bool characteristicFound = false;
      for (final service in services) {
        if (service.uuid.toString().toLowerCase().contains('12345678')) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid
                .toString()
                .toLowerCase()
                .contains('abcd1234')) {
              _characteristics[device.remoteId.str] = characteristic;

              // Enable notifications if supported
              if (characteristic.properties.notify) {
                await characteristic.setNotifyValue(true);
                characteristic.lastValueStream.listen((value) {
                  if (value.isNotEmpty) {
                    _onDataReceived(value, device);
                  }
                });
              }

              characteristicFound = true;
              AppLogger.bluetooth('Characteristic found ✅');
              break;
            }
          }
        }
        if (characteristicFound) break;
      }

      _connectedDevices.add(device);
      _setState(BtConnectionState.connected);

      // Listen for disconnection + auto-reconnect
      device.connectionState.listen((connectionState) {
        if (connectionState == BluetoothConnectionState.disconnected) {
          _connectedDevices.remove(device);
          _characteristics.remove(device.remoteId.str);
          _deviceBuffers.remove(device.remoteId.str);
          AppLogger.bluetooth('Disconnected: ${device.platformName}');

          // Auto-reconnect after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (!_connectedDevices.contains(device)) {
              AppLogger.bluetooth('Attempting auto-reconnect...');
              connectToDevice(device);
            }
          });

          if (_connectedDevices.isEmpty) {
            _setState(BtConnectionState.idle);
          }
          notifyListeners();
        }
      });

      AppLogger.bluetooth('Connected to ${device.platformName} ✅');
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.error('Connection failed', error: e);
      _setState(BtConnectionState.idle);
      return false;
    }
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    await device.disconnect();
    _connectedDevices.remove(device);
    _characteristics.remove(device.remoteId.str);
    _deviceBuffers.remove(device.remoteId.str);
    if (_connectedDevices.isEmpty) _setState(BtConnectionState.idle);
    notifyListeners();
  }

  // ── Sending Messages ─────────────────────────────────────────────
  Future<bool> sendMessage(String content) async {
    if (_connectedDevices.isEmpty) {
      AppLogger.warning('No connected devices');
      return false;
    }

    final encryptedContent = EncryptionService.encrypt(content);

    final message = MessageModel(
      id: const Uuid().v4(),
      senderId: _deviceId,
      senderName: _deviceName,
      content: content,
      encryptedContent: encryptedContent,
      type: MessageType.text,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
      isMe: true,
      isEncrypted: true,
    );

    _messages.add(message);
    await DbHelper.insertMessage(message, channel: 'bluetooth');
    notifyListeners();

    bool anySent = false;

    for (final device in _connectedDevices) {
      final characteristic = _characteristics[device.remoteId.str];
      if (characteristic == null) continue;

      try {
        final jsonStr = message.toJson(encryptedPayload: encryptedContent);
        final bytes = utf8.encode(jsonStr);
        await _writeInChunks(characteristic, bytes);
        AppLogger.bluetooth(
          'Encrypted message sent to ${device.platformName} ✅',
        );
        anySent = true;
      } catch (e) {
        AppLogger.error(
          'Send failed to ${device.platformName}',
          error: e,
        );
      }
    }

    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      _messages[index] = message.copyWith(
        status: anySent ? MessageStatus.sent : MessageStatus.failed,
      );
      notifyListeners();
    }

    return anySent;
  }

  // ── Write in chunks with MTU negotiation ─────────────────────────
  Future<void> _writeInChunks(
    BluetoothCharacteristic characteristic,
    List<int> bytes,
  ) async {
    // Negotiate larger MTU for faster transfer
    int chunkSize = 180; // safe default for most devices
    try {
      final mtu = await characteristic.device.requestMtu(512);
      chunkSize = mtu - 3; // subtract ATT protocol overhead
      AppLogger.bluetooth('MTU negotiated: $mtu, chunk: $chunkSize');
    } catch (_) {
      AppLogger.bluetooth('MTU negotiation failed, using default 180');
    }

    for (int i = 0; i < bytes.length; i += chunkSize) {
      final end =
          (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      final chunk = bytes.sublist(i, end);
      await characteristic.write(chunk, withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  // ── Receiving Messages (per-device buffer) ────────────────────────
  void _onDataReceived(List<int> value, BluetoothDevice fromDevice) {
    // Use per-device buffer to avoid mixing packets
    final deviceId = fromDevice.remoteId.str;
    _deviceBuffers[deviceId] ??= [];
    _deviceBuffers[deviceId]!.addAll(value);

    try {
      final jsonStr = utf8.decode(_deviceBuffers[deviceId]!);
      final trimmed = jsonStr.trim();

      // Only process when we have a complete JSON object
      if (_isCompleteJson(trimmed)) {
        _deviceBuffers[deviceId]!.clear();

        final map = jsonDecode(trimmed) as Map<String, dynamic>;
        final isEncrypted = map['isEncrypted'] as bool? ?? false;
        String? decryptedContent;

        if (isEncrypted) {
          final encryptedContent = map['content'] as String;
          decryptedContent = EncryptionService.decrypt(encryptedContent);
          AppLogger.bluetooth('Message decrypted successfully 🔓');
        }

        final message = MessageModel.fromJson(
          trimmed,
          isMe: false,
          decryptedContent: decryptedContent,
        );

        if (!_seenMessageIds.contains(message.id)) {
          _seenMessageIds.add(message.id);
          _messages.add(message);

          // Save to database
          DbHelper.insertMessage(message, channel: 'bluetooth');

          AppLogger.bluetooth(
            'Received from ${message.senderName}: ${message.content}',
          );

          // Show notification
          if (message.type == MessageType.sos ||
              message.content.contains('🆘')) {
            NotificationService.showSosAlert(
              senderName: message.senderName,
              location: message.content,
            );
          } else {
            NotificationService.showMessageNotification(
              senderName: message.senderName,
              message: message.content,
              channel: 'bluetooth',
            );
          }

          notifyListeners();
          _relayMessage(message, fromDevice);
        }
      }
      // else: JSON incomplete, keep buffering
    } catch (_) {
      // Not valid UTF-8 yet — keep buffering
    }
  }

  // ── Check if JSON string is complete (balanced braces) ───────────
  bool _isCompleteJson(String str) {
    if (!str.startsWith('{')) return false;
    int depth = 0;
    bool inString = false;
    for (int i = 0; i < str.length; i++) {
      final ch = str[i];
      if (ch == '"' && (i == 0 || str[i - 1] != '\\')) {
        inString = !inString;
      }
      if (!inString) {
        if (ch == '{') depth++;
        if (ch == '}') depth--;
      }
      if (depth == 0 && i > 0) return true;
    }
    return false;
  }

  // ── Message Relay ────────────────────────────────────────────────
  Future<void> _relayMessage(
    MessageModel message,
    BluetoothDevice fromDevice,
  ) async {
    if (message.hopCount >= 3) {
      AppLogger.bluetooth('Max hops reached — not relaying');
      return;
    }

    final relayed = MessageModel(
      id: message.id,
      senderId: message.senderId,
      senderName: message.senderName,
      content: message.content,
      type: MessageType.relay,
      status: MessageStatus.sent,
      timestamp: message.timestamp,
      isMe: false,
      hopCount: message.hopCount + 1,
    );

    for (final device in _connectedDevices) {
      if (device.remoteId == fromDevice.remoteId) continue;
      final characteristic = _characteristics[device.remoteId.str];
      if (characteristic == null) continue;

      try {
        final bytes = utf8.encode(relayed.toJson());
        await _writeInChunks(characteristic, bytes);
        AppLogger.bluetooth('Relayed to ${device.platformName}');
      } catch (e) {
        AppLogger.error('Relay failed', error: e);
      }
    }
  }

  // ── Test Helper ──────────────────────────────────────────────────
  void injectTestMessage(String content) {
    final message = MessageModel(
      id: const Uuid().v4(),
      senderId: 'test-device-001',
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

  // ── Helpers ──────────────────────────────────────────────────────
  void _setState(BtConnectionState newState) {
    _state = newState;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _seenMessageIds.clear();
    _deviceBuffers.clear();
    DbHelper.clearMessages();
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    for (final device in _connectedDevices) {
      device.disconnect();
    }
    super.dispose();
  }
}