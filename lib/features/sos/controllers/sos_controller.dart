import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/sms_service.dart';
import '../../../core/services/user_preferences.dart';
import '../../../core/services/emergency_contacts_service.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/database/db_helper.dart';
import '../../../data/local/models/sos_log_model.dart';
import '../../bluetooth/controllers/bluetooth_controller.dart';
import '../../../core/services/ble_broadcast_service.dart';
import '../../../data/remote/firebase/fcm_service.dart';
import '../../../core/services/connectivity_service.dart';

enum SosState {
  idle,
  countdown,
  sending,
  active,
  cancelled,
}

class SosController extends ChangeNotifier {
  final BluetoothController _bluetoothController;

  // ── ConnectivityService instance (not static) ────────────────────
  final ConnectivityService _connectivityService = ConnectivityService();

  SosController({
    required BluetoothController bluetoothController,
  }) : _bluetoothController = bluetoothController {
    _bluetoothController.addListener(_onBluetoothChanged);
  }

  // ── State ────────────────────────────────────────────────────────
  SosState _state = SosState.idle;
  SosState get state => _state;

  int _countdown = 5;
  int get countdown => _countdown;

  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;

  String _statusMessage = 'Press and hold to send SOS';
  String get statusMessage => _statusMessage;

  // ── Real send results ────────────────────────────────────────────
  bool _smsSent = false;
  bool _bluetoothSent = false;
  bool _onlineSent = false;

  bool get smsSent => _smsSent;
  bool get onlineSent => _onlineSent;

  // ── Bluetooth tick — real time ───────────────────────────────────
  bool get bluetoothSent =>
      _state == SosState.active
          ? _bluetoothSent
          : _bluetoothController.isConnected;

  // ── Internet tick — real time ────────────────────────────────────
  bool _hasInternet = false;
  bool get hasInternet => _hasInternet;

  // ── SMS tick — real time: true if contacts exist ─────────────────
  bool _hasEmergencyContacts = false;
  bool get hasEmergencyContacts => _hasEmergencyContacts;

  int _smsSentCount = 0;
  int get smsSentCount => _smsSentCount;

  Timer? _countdownTimer;
  Timer? _connectivityTimer;

  // ── Init: start polling internet + contacts ──────────────────────
  void startMonitoring() {
    _checkInternet();
    _checkEmergencyContacts();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        _checkInternet();
        _checkEmergencyContacts();
      },
    );
  }

  // ── Use instance .isOnline (NOT static) ─────────────────────────
  Future<void> _checkInternet() async {
    try {
      await _connectivityService.checkConnectivity();
      final connected = _connectivityService.isOnline; // ← instance property
      if (_hasInternet != connected) {
        _hasInternet = connected;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _checkEmergencyContacts() async {
    try {
      final contacts = await EmergencyContactsService.getContacts();
      final hasContacts = contacts.isNotEmpty;
      if (_hasEmergencyContacts != hasContacts) {
        _hasEmergencyContacts = hasContacts;
        notifyListeners();
      }
    } catch (_) {}
  }

  void _onBluetoothChanged() {
    notifyListeners();
  }

  // ── Start SOS Countdown ──────────────────────────────────────────
  void startCountdown() {
    if (_state != SosState.idle) return;

    _countdown = 5;
    _state = SosState.countdown;
    _statusMessage = 'Sending SOS in $_countdown seconds...';
    _smsSent = false;
    _bluetoothSent = false;
    _onlineSent = false;
    _smsSentCount = 0;
    notifyListeners();

    HapticFeedback.heavyImpact();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdown--;
      _statusMessage = 'Sending SOS in $_countdown seconds...';
      HapticFeedback.mediumImpact();
      notifyListeners();

      if (_countdown <= 0) {
        timer.cancel();
        _sendSOS();
      }
    });
  }

  // ── Cancel SOS ───────────────────────────────────────────────────
  void cancelSOS() {
    if (_state != SosState.countdown) return;

    _countdownTimer?.cancel();
    _state = SosState.cancelled;
    _statusMessage = 'SOS Cancelled';
    HapticFeedback.lightImpact();
    notifyListeners();

    Future.delayed(const Duration(seconds: 2), () {
      _state = SosState.idle;
      _statusMessage = 'Press and hold to send SOS';
      notifyListeners();
    });
  }

  // ── Send SOS ─────────────────────────────────────────────────────
  Future<void> _sendSOS() async {
    _state = SosState.sending;
    _statusMessage = 'Getting your location...';
    notifyListeners();

    AppLogger.sos('SOS triggered! Getting location...');

    _lastPosition = await LocationService.getCurrentPosition();
    final locationText = _lastPosition != null
        ? LocationService.formatLocationForSOS(_lastPosition!)
        : 'Location unavailable';

    final locationShort = _lastPosition != null
        ? LocationService.formatShort(_lastPosition!)
        : 'Unknown';

    final userName = await UserPreferences.getUserName();

    final sosMessage =
        '🆘 SOS ALERT from $userName!\n'
        '📍 Location: $locationShort\n'
        'https://maps.google.com/?q='
        '${_lastPosition?.latitude ?? 0},'
        '${_lastPosition?.longitude ?? 0}';

    _statusMessage = 'Sending SOS alert...';
    notifyListeners();

    await Future.wait([
      _sendViaBluetooth(
        userName: userName,
        latitude: _lastPosition?.latitude,
        longitude: _lastPosition?.longitude,
      ),
      _sendViaFirebase(sosMessage),
      _sendAllSMS(
        userName: userName,
        locationText: locationText,
      ),
    ]);

    final log = SosLog.create(
      userName: userName,
      latitude: _lastPosition?.latitude,
      longitude: _lastPosition?.longitude,
      locationText: locationText,
      bluetoothSent: _bluetoothSent,
      onlineSent: _onlineSent,
      smsSentCount: _smsSentCount,
      status: 'sent',
    );
    await DbHelper.insertSosLog(log);
    AppLogger.sos('SOS log saved ✅');

    _state = SosState.active;
    _statusMessage = 'SOS ACTIVE — Help is on the way';
    HapticFeedback.heavyImpact();
    notifyListeners();

    AppLogger.sos(
      'SOS sent! BT: $_bluetoothSent, '
      'Online: $_onlineSent, '
      'SMS: $_smsSentCount contacts',
    );
  }

  // ── Send via Bluetooth ───────────────────────────────────────────
  Future<void> _sendViaBluetooth({
    required String userName,
    required double? latitude,
    required double? longitude,
  }) async {
    try {
      final bleResult = await BleBroadcastService.broadcastSOS(
        userName: userName,
        latitude: latitude,
        longitude: longitude,
      );

      if (_bluetoothController.isConnected) {
        final sosMessage =
            '🆘 SOS ALERT from $userName!\n'
            '📍 GPS: ${latitude ?? "unknown"}, ${longitude ?? "unknown"}';
        await _bluetoothController.sendMessage(sosMessage);
      }

      _bluetoothSent = bleResult || _bluetoothController.isConnected;
      AppLogger.sos('SOS Bluetooth: $_bluetoothSent');

      if (bleResult) {
        Future.delayed(const Duration(seconds: 60), () {
          BleBroadcastService.stopBroadcast();
        });
      }
    } catch (e) {
      AppLogger.error('BT SOS failed', error: e);
      _bluetoothSent = false;
    }
    notifyListeners();
  }

  // ── Send via Firebase ────────────────────────────────────────────
  Future<void> _sendViaFirebase(String message) async {
    try {
      // ← Use instance .isOnline (NOT static)
      final connected = _connectivityService.isOnline;
      if (!connected) {
        _onlineSent = false;
        AppLogger.sos('No internet — skipping Firebase SOS');
        notifyListeners();
        return;
      }

      final fcmService = FcmService();
      final result = await fcmService.sendMessageToToken(
        targetToken: 'broadcast',
        content: message,
        senderId: _bluetoothController.deviceId,
        senderName: _bluetoothController.deviceName,
      );
      _onlineSent = result;
      AppLogger.sos('SOS via Firebase: $result');
    } catch (e) {
      AppLogger.error('Firebase SOS failed', error: e);
      _onlineSent = false;
    }
    notifyListeners();
  }

  // ── Send SMS ─────────────────────────────────────────────────────
  Future<void> _sendAllSMS({
    required String userName,
    required String locationText,
  }) async {
    final contacts = await EmergencyContactsService.getContacts();

    if (contacts.isEmpty) {
      AppLogger.warning('No emergency contacts saved — skipping SMS');
      _smsSent = false;
      notifyListeners();
      return;
    }

    AppLogger.sos('Sending SMS to ${contacts.length} contacts...');

    final results = await Future.wait(
      contacts.map(
        (contact) => SmsService.sendSos(
          phoneNumber: contact.phone,
          userName: userName,
          locationText: locationText,
        ),
      ),
    );

    _smsSentCount = results.where((r) => r == true).length;
    _smsSent = _smsSentCount > 0;

    AppLogger.sos('SMS sent to $_smsSentCount/${contacts.length} contacts');
    notifyListeners();
  }

  // ── Reset SOS ────────────────────────────────────────────────────
  void resetSOS() {
    _countdownTimer?.cancel();
    _state = SosState.idle;
    _statusMessage = 'Press and hold to send SOS';
    _smsSent = false;
    _bluetoothSent = false;
    _onlineSent = false;
    _smsSentCount = 0;
    BleBroadcastService.stopBroadcast();
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _connectivityTimer?.cancel();
    _connectivityService.dispose();
    _bluetoothController.removeListener(_onBluetoothChanged);
    super.dispose();
  }
}