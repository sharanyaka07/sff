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
  reconnecting,
}

class BluetoothController extends ChangeNotifier {

  static const _gattChannel    = MethodChannel('com.safeconnect.gatt/server');
  static const _messageChannel = EventChannel('com.safeconnect.gatt/messages');

  static const String serviceUuid = '12345678-1234-1234-1234-123456789abc';
  static const String charUuid    = 'abcd1234-1234-1234-1234-abcdef123456';

  static final _macRegex =
      RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');

  static const int _maxReconnectAttempts = 5;
  final Map<String, int>            _reconnectAttempts = {};
  final Map<String, BluetoothDevice> _reconnectTargets = {};
  final Map<String, Timer>           _reconnectTimers  = {};

  BtConnectionState _state = BtConnectionState.unknown;
  BtConnectionState get state => _state;

  final List<ScanResult>      _scanResults      = [];
  final List<BluetoothDevice> _connectedDevices = [];
  final Map<String, BluetoothCharacteristic> _writeChars = {};
  final Map<String, StringBuffer> _chunkBuffers   = {};
  final Map<String, int>          _expectedChunks = {};
  final Map<String, int>          _receivedChunks = {};
  final List<MessageModel>        _messages       = [];

  List<ScanResult>      get scanResults      => List.unmodifiable(_scanResults);
  List<ScanResult>      get namedScanResults => List.unmodifiable(_scanResults);
  List<BluetoothDevice> get connectedDevices => List.unmodifiable(_connectedDevices);
  List<MessageModel>    get messages         => List.unmodifiable(_messages);

  String _deviceName = 'Unknown';
  String _deviceId   = '';
  String get deviceName => _deviceName;
  String get deviceId   => _deviceId;

  bool _isScanning      = false;
  bool _serverHasClients = false;
  bool get isScanning       => _isScanning;
  bool get serverHasClients => _serverHasClients;
  bool get isConnected      => _connectedDevices.isNotEmpty || _serverHasClients;
  bool get isAdvertising    => true;

  // ── Name caches (peer names only — never own name) ────────────
  final Map<String, String> _clientNames = {}; // senderId → name
  final Map<String, String> _macToName   = {}; // MAC      → name

  // ── connectedClientName: peer's name from handshake ───────────
  String _connectedClientName = '';
  String get connectedClientName => _connectedClientName;

  // ── connectedPeerId: peer's senderId from handshake ───────────
  // Used to stamp conversationId on outgoing messages.
  // Set from EITHER direction:
  //   - We receive their handshake (they connected to us as server)
  //   - We connect to them (client role) and their handshake arrives
  //   - Fallback: use their device MAC until handshake arrives
  String _connectedPeerId = '';
  String get connectedPeerId => _connectedPeerId;

  // ── MAC of the device we connected TO (client role) ──────────
  // Used as a fallback conversationId before the peer's handshake arrives
  String _connectedDeviceMac = '';

  Timer? _heartbeatTimer;
  static const _heartbeatInterval = Duration(seconds: 2);

  StreamSubscription? _scanSubscription;
  StreamSubscription? _adapterStateSubscription;
  StreamSubscription? _nativeMessageSubscription;
  bool _isInitialized = false;

  // ── Init ──────────────────────────────────────────────────────
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

  Future<void> _startNativeGattServer() async {
    try {
      await _gattChannel.invokeMethod('startGattServer');
      AppLogger.bluetooth('Native GATT server started ✅');
    } catch (e) {
      AppLogger.error('Failed to start GATT server', error: e);
    }
  }

  void _listenForNativeMessages() {
    _nativeMessageSubscription = _messageChannel
        .receiveBroadcastStream()
        .listen((dynamic payload) {
      if (payload is! String) return;

      if (payload.startsWith('CLIENT_CONNECTED:')) {
        final clientAddress = payload.replaceFirst('CLIENT_CONNECTED:', '');
        _serverHasClients = true;
        final cachedName = _macToName[clientAddress];
        if (cachedName != null &&
            !_macRegex.hasMatch(cachedName) &&
            cachedName != _deviceName) {
          _connectedClientName = cachedName;
        } else {
          _connectedClientName = clientAddress;
        }
        // Store MAC as fallback conversationId until handshake arrives
        if (_connectedPeerId.isEmpty) {
          _connectedDeviceMac = clientAddress;
        }
        _setState(BtConnectionState.connected);
        AppLogger.bluetooth('Client connected: $_connectedClientName ✅');
        notifyListeners();
        return;
      }

      if (payload.startsWith('CLIENT_NAME_UPDATE:')) {
        final parts = payload.replaceFirst('CLIENT_NAME_UPDATE:', '').split(':');
        if (parts.length >= 2) {
          final name = parts.sublist(1).join(':');
          if (name != _deviceName) {
            _connectedClientName = name;
            notifyListeners();
          }
        }
        return;
      }

      if (payload == 'CLIENT_DISCONNECTED') {
        _serverHasClients    = false;
        _connectedClientName = '';
        _connectedPeerId     = '';
        _connectedDeviceMac  = '';
        if (_connectedDevices.isEmpty) _setState(BtConnectionState.idle);
        AppLogger.bluetooth('Client disconnected');
        notifyListeners();
        return;
      }

      _serverHasClients = true;
      _processReceivedMessage(payload);
      notifyListeners();
    }, onError: (e) {
      AppLogger.error('Native message stream error', error: e);
    });
  }

  Future<void> _loadDeviceIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceName = prefs.getString('user_name') ?? 'User_${_shortId()}';
    _deviceId   = prefs.getString('device_id') ?? const Uuid().v4();
    await prefs.setString('device_id', _deviceId);
    notifyListeners();
  }

  String _shortId() =>
      DateTime.now().millisecondsSinceEpoch.toString().substring(8);

  void _listenToAdapterState() {
    _adapterStateSubscription =
        FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        _setState(BtConnectionState.idle);
        _startNativeGattServer();
      } else if (state == BluetoothAdapterState.off) {
        _cancelAllReconnects();
        _heartbeatTimer?.cancel();
        _setState(BtConnectionState.off);
        _scanResults.clear();
        _connectedDevices.clear();
        _writeChars.clear();
        _serverHasClients    = false;
        _connectedClientName = '';
        _connectedPeerId     = '';
        _connectedDeviceMac  = '';
        _clientNames.clear();
        _macToName.clear();
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

  String _getDeviceName(ScanResult result) {
    if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    }
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }
    final cached = _macToName[result.device.remoteId.str];
    if (cached != null && cached.isNotEmpty) return cached;
    return result.device.remoteId.str;
  }

  String getDisplayName(ScanResult result) => _getDeviceName(result);

  Future<void> startScan() async {
    if (_isScanning) return;

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

    try {
      await _scanSubscription?.cancel();

      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          bool changed = false;
          for (final result in results) {
            final resultName = _getDeviceName(result);
            if (resultName == _deviceName) continue; // skip own device

            final idx = _scanResults.indexWhere(
              (r) => r.device.remoteId == result.device.remoteId,
            );
            if (idx == -1) {
              _scanResults.add(result);
              changed = true;
              AppLogger.bluetooth('Found: $resultName | RSSI: ${result.rssi}');
              NotificationService.showBluetoothDeviceFound(
                deviceName: resultName,
                deviceCount: _scanResults.length,
              );
            } else {
              final existingName = _getDeviceName(_scanResults[idx]);
              if (_macRegex.hasMatch(existingName) &&
                  !_macRegex.hasMatch(resultName)) {
                _scanResults[idx] = result;
                changed = true;
              }
            }
          }
          if (changed) notifyListeners();
        },
        onError: (e) => AppLogger.error('Scan stream error', error: e),
      );

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        androidUsesFineLocation: true,
        continuousUpdates: true,
        withServices: [Guid(serviceUuid)],
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
    _setState(isConnected ? BtConnectionState.connected : BtConnectionState.idle);
    AppLogger.bluetooth('Scan stopped. Found ${_scanResults.length} devices');
    notifyListeners();
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (_connectedDevices.any((d) => d.remoteId == device.remoteId)) {
      return true;
    }

    _setState(BtConnectionState.connecting);
    notifyListeners();

    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      await device.requestConnectionPriority(
        connectionPriorityRequest: ConnectionPriority.high,
      );

      try {
        final mtu = await device.requestMtu(512);
        AppLogger.bluetooth('MTU: $mtu bytes ✅');
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 300));

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
        await device.disconnect();
        _setState(BtConnectionState.idle);
        notifyListeners();
        return false;
      }

      await targetChar.setNotifyValue(true);
      targetChar.lastValueStream.listen((data) {
        if (data.isNotEmpty) _onClientDataReceived(data, device);
      });

      _writeChars[device.remoteId.str] = targetChar;
      _connectedDevices.add(device);
      _reconnectTargets[device.remoteId.str] = device;
      _reconnectAttempts[device.remoteId.str] = 0;

      // Store the MAC as fallback conversationId until peer handshake arrives
      _connectedDeviceMac = device.remoteId.str;

      _setState(BtConnectionState.connected);
      notifyListeners();

      await Future.delayed(const Duration(milliseconds: 300));
      await _sendHandshake(targetChar);
      _startHeartbeat(device, targetChar);

      device.connectionState.listen((cs) {
        if (cs == BluetoothConnectionState.disconnected) {
          _heartbeatTimer?.cancel();
          _connectedDevices.removeWhere((d) => d.remoteId == device.remoteId);
          _writeChars.remove(device.remoteId.str);
          _chunkBuffers.remove(device.remoteId.str);
          _expectedChunks.remove(device.remoteId.str);
          _receivedChunks.remove(device.remoteId.str);
          if (device.remoteId.str == _connectedDeviceMac) {
            _connectedDeviceMac = '';
            _connectedPeerId    = '';
          }
          if (_reconnectTargets.containsKey(device.remoteId.str)) {
            _scheduleReconnect(device);
          } else {
            if (_connectedDevices.isEmpty && !_serverHasClients) {
              _setState(BtConnectionState.idle);
            }
          }
          notifyListeners();
        }
      });

      AppLogger.bluetooth('Connected to ${device.platformName} ✅');
      return true;
    } catch (e) {
      AppLogger.error('Connect failed', error: e);
      _heartbeatTimer?.cancel();
      _connectedDeviceMac = '';
      _setState(BtConnectionState.idle);
      notifyListeners();
      return false;
    }
  }

  void _scheduleReconnect(BluetoothDevice device) {
    final id       = device.remoteId.str;
    final attempts = _reconnectAttempts[id] ?? 0;

    if (attempts >= _maxReconnectAttempts) {
      _reconnectTargets.remove(id);
      _reconnectAttempts.remove(id);
      if (_connectedDevices.isEmpty && !_serverHasClients) {
        _setState(BtConnectionState.idle);
      }
      notifyListeners();
      return;
    }

    final delaySeconds = (2 << attempts).clamp(2, 32);
    _reconnectAttempts[id] = attempts + 1;
    _setState(BtConnectionState.reconnecting);
    notifyListeners();

    _reconnectTimers[id]?.cancel();
    _reconnectTimers[id] = Timer(Duration(seconds: delaySeconds), () async {
      final ok = await connectToDevice(device);
      if (ok) _reconnectAttempts[id] = 0;
    });
  }

  void _cancelAllReconnects() {
    for (final t in _reconnectTimers.values) {
      t.cancel();
    }
    _reconnectTimers.clear();
    _reconnectTargets.clear();
    _reconnectAttempts.clear();
  }

  void _startHeartbeat(BluetoothDevice device, BluetoothCharacteristic char) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      if (!_connectedDevices.any((d) => d.remoteId == device.remoteId)) {
        _heartbeatTimer?.cancel();
        return;
      }
      try {
        await _sendChunked(char,
            jsonEncode({'type': 'ping', 'senderId': _deviceId}));
      } catch (e) {
        _heartbeatTimer?.cancel();
      }
    });
  }

  Future<void> _sendHandshake(BluetoothCharacteristic char) async {
    try {
      await _sendChunked(char, jsonEncode({
        'type':       'handshake',
        'senderName': _deviceName,
        'senderId':   _deviceId,
      }));
      AppLogger.bluetooth('Handshake sent: $_deviceName ✅');
    } catch (e) {
      AppLogger.error('Handshake send failed', error: e);
    }
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    _heartbeatTimer?.cancel();
    _reconnectTargets.remove(device.remoteId.str);
    _reconnectTimers[device.remoteId.str]?.cancel();
    _reconnectTimers.remove(device.remoteId.str);
    _reconnectAttempts.remove(device.remoteId.str);
    if (device.remoteId.str == _connectedDeviceMac) {
      _connectedDeviceMac = '';
      _connectedPeerId    = '';
    }
    try { await device.disconnect(); } catch (_) {}
    _connectedDevices.removeWhere((d) => d.remoteId == device.remoteId);
    _writeChars.remove(device.remoteId.str);
    if (_connectedDevices.isEmpty && !_serverHasClients) {
      _setState(BtConnectionState.idle);
    }
    notifyListeners();
  }

  // ── Send message ─────────────────────────────────────────────────
  // conversationId resolution order:
  //   1. _connectedPeerId  — peer's UUID from handshake (most reliable)
  //   2. _connectedDeviceMac — MAC of device we connected to (client role)
  //   3. _connectedClientName — name fallback (server role before handshake)
  // This ensures sent messages ALWAYS have a non-empty conversationId
  // that matches what _processReceivedMessage stores as senderId.
  Future<bool> sendMessage(String content) async {
    if (!isConnected) return false;

    try {
      final encrypted = EncryptionService.encrypt(content);
      final msgId     = const Uuid().v4();

      // Resolve the best available conversationId
      String convId = '';
      if (_connectedPeerId.isNotEmpty) {
        convId = _connectedPeerId;          // UUID from handshake ✅
      } else if (_connectedDeviceMac.isNotEmpty) {
        convId = _connectedDeviceMac;       // MAC fallback (client role)
      } else if (_connectedClientName.isNotEmpty) {
        convId = _connectedClientName;      // name fallback (server role)
      }

      AppLogger.bluetooth('sendMessage: convId="$convId" peerId="$_connectedPeerId" mac="$_connectedDeviceMac"');

      final message = MessageModel(
        id:             msgId,
        senderId:       _deviceId,
        senderName:     _deviceName,
        content:        content,
        encryptedContent: encrypted,
        type:           MessageType.text,
        status:         MessageStatus.sending,
        timestamp:      DateTime.now(),
        isMe:           true,
        isEncrypted:    true,
        conversationId: convId,
      );

      _messages.add(message);
      await DbHelper.insertMessage(message, channel: 'bluetooth');
      notifyListeners();

      final payload = jsonEncode({
        'id':          msgId,
        'senderId':    _deviceId,
        'senderName':  _deviceName,
        'content':     encrypted,
        'timestamp':   DateTime.now().toIso8601String(),
        'isEncrypted': true,
      });

      bool anySent = false;

      for (final device in _connectedDevices) {
        final char = _writeChars[device.remoteId.str];
        if (char == null) continue;
        if (await _sendChunked(char, payload)) anySent = true;
      }

      try {
        final ok = await _gattChannel.invokeMethod<bool>(
          'sendMessage', {'payload': payload}) ?? false;
        if (ok) anySent = true;
      } catch (e) {
        AppLogger.error('Native server send failed', error: e);
      }

      final idx = _messages.indexWhere((m) => m.id == msgId);
      if (idx != -1) {
        _messages[idx] = message.copyWith(
          status: anySent ? MessageStatus.sent : MessageStatus.failed,
        );
        notifyListeners();
      }

      return anySent;
    } catch (e) {
      AppLogger.error('sendMessage failed', error: e);
      return false;
    }
  }

  Future<bool> _sendChunked(
      BluetoothCharacteristic char, String payload) async {
    try {
      final bytes     = utf8.encode(payload);
      const chunkSize = 180;
      final total     = (bytes.length / chunkSize).ceil();

      for (int i = 0; i < total; i++) {
        final start  = i * chunkSize;
        final end    = (start + chunkSize).clamp(0, bytes.length);
        final chunk  = bytes.sublist(start, end);
        final packet = Uint8List(chunk.length + 2);
        packet[0] = i;
        packet[1] = total;
        packet.setRange(2, packet.length, chunk);
        await char.write(packet, withoutResponse: false);
        await Future.delayed(const Duration(milliseconds: 30));
      }
      return true;
    } catch (e) {
      AppLogger.error('Chunked write failed', error: e);
      return false;
    }
  }

  void _onClientDataReceived(List<int> data, BluetoothDevice device) {
    try {
      if (data.length < 3) return;
      final chunkIndex  = data[0];
      final totalChunks = data[1];
      final chunkData   = data.sublist(2);
      final devId       = device.remoteId.str;

      if (chunkIndex == 0) {
        _chunkBuffers[devId]   = StringBuffer();
        _expectedChunks[devId] = totalChunks;
        _receivedChunks[devId] = 0;
      }

      _chunkBuffers[devId]?.write(utf8.decode(chunkData));
      _receivedChunks[devId] = (_receivedChunks[devId] ?? 0) + 1;

      if (_receivedChunks[devId] == _expectedChunks[devId]) {
        final full = _chunkBuffers[devId]!.toString();
        _chunkBuffers.remove(devId);
        _expectedChunks.remove(devId);
        _receivedChunks.remove(devId);
        _processReceivedMessage(full, senderMac: devId);
      }
    } catch (e) {
      AppLogger.error('Client data receive error', error: e);
    }
  }

  void _processReceivedMessage(String payload, {String? senderMac}) {
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;

      if (map['type'] == 'ping') return;

      if (map['type'] == 'handshake') {
        final senderName = map['senderName'] as String? ?? 'Unknown';
        final senderId   = map['senderId']   as String? ?? '';

        // Only cache peer names — never our own
        if (senderId != _deviceId && senderName != _deviceName) {
          if (senderId.isNotEmpty) {
            _clientNames[senderId] = senderName;
            _connectedPeerId       = senderId; // ← peer UUID now known

            // Also map MAC → UUID so existing MAC-based convIds get resolved
            if (senderMac != null) {
              _macToName[senderMac] = senderName;
              // Update any sent messages that used MAC as convId
              _upgradeMacConvIds(senderMac, senderId);
            }
          }
          _connectedClientName = senderName;
          notifyListeners();
        }
        return;
      }

      if (map['senderId'] == _deviceId) return;

      final msgId = map['id'] as String;
      if (_messages.any((m) => m.id == msgId)) return;

      final rawContent   = map['content']     as String;
      final wasEncrypted = map['isEncrypted'] as bool? ?? false;
      final senderName   = map['senderName']  as String? ?? 'Unknown';
      final senderId     = map['senderId']     as String;

      String displayContent = rawContent;
      if (wasEncrypted) {
        try {
          displayContent = EncryptionService.decrypt(rawContent);
        } catch (_) {
          displayContent = rawContent;
        }
      }

      final message = MessageModel(
        id:             msgId,
        senderId:       senderId,
        senderName:     senderName,
        content:        displayContent,
        type:           MessageType.text,
        status:         MessageStatus.delivered,
        timestamp:      DateTime.parse(map['timestamp'] as String),
        isMe:           false,
        isEncrypted:    wasEncrypted,
        conversationId: senderId, // received msg: conversationId = senderId ✅
      );

      _messages.add(message);
      DbHelper.insertMessage(message, channel: 'bluetooth');
      AppLogger.bluetooth('✅ Message from $senderName');

      NotificationService.showMessageNotification(
        senderName: senderName,
        message:    displayContent,
        channel:    'bluetooth',
      );

      notifyListeners();
    } catch (e) {
      AppLogger.error('processReceivedMessage failed', error: e);
    }
  }

  // ── When handshake reveals peer UUID, upgrade any sent messages
  // that used the MAC address as conversationId (timing race fix) ──
  void _upgradeMacConvIds(String mac, String peerId) {
    bool changed = false;
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (m.isMe && m.conversationId == mac) {
        _messages[i] = m.copyWith(conversationId: peerId);
        changed = true;
      }
    }
    if (changed) {
      // Persist upgrades to DB
      for (final m in _messages) {
        if (m.isMe && m.conversationId == peerId) {
          DbHelper.insertMessage(m, channel: 'bluetooth');
        }
      }
    }
  }

  void injectTestMessage(String content) {
    _messages.add(MessageModel(
      id:             const Uuid().v4(),
      senderId:       'test-001',
      senderName:     'Test Device',
      content:        content,
      type:           MessageType.text,
      status:         MessageStatus.delivered,
      timestamp:      DateTime.now(),
      isMe:           false,
      conversationId: 'test-001',
    ));
    notifyListeners();
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

  void clearMessagesForSender(String senderId) {
    _messages.removeWhere(
      (m) => m.senderId == senderId || m.conversationId == senderId,
    );
    DbHelper.clearMessagesForSender(senderId);
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelAllReconnects();
    _heartbeatTimer?.cancel();
    _scanSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _nativeMessageSubscription?.cancel();
    _gattChannel.invokeMethod('stopGattServer').catchError((_) {});
    super.dispose();
  }
}