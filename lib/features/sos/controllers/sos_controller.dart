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
import '../../chat/controllers/chat_controller.dart';

enum SosState {
  idle,
  countdown,
  sending,
  active,
  cancelled,
}

class SosController extends ChangeNotifier {
  final BluetoothController _bluetoothController;
  final ChatController _chatController;

  SosController({
    required BluetoothController bluetoothController,
    required ChatController chatController,
  })  : _bluetoothController = bluetoothController,
        _chatController = chatController;

  // ── State ────────────────────────────────────────────────────────
  SosState _state = SosState.idle;
  SosState get state => _state;

  int _countdown = 5;
  int get countdown => _countdown;

  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;

  String _statusMessage = 'Press and hold to send SOS';
  String get statusMessage => _statusMessage;

  bool _smsSent = false;
  bool _bluetoothSent = false;
  bool _onlineSent = false;

  bool get smsSent => _smsSent;
  bool get bluetoothSent => _bluetoothSent;
  bool get onlineSent => _onlineSent;

  int _smsSentCount = 0;
  int get smsSentCount => _smsSentCount;

  Timer? _countdownTimer;

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

    // Step 1: Get GPS location
    _lastPosition = await LocationService.getCurrentPosition();
    final locationText = _lastPosition != null
        ? LocationService.formatLocationForSOS(_lastPosition!)
        : 'Location unavailable';

    final locationShort = _lastPosition != null
        ? LocationService.formatShort(_lastPosition!)
        : 'Unknown';

    // Step 2: Get user info
    final userName = await UserPreferences.getUserName();

    final sosMessage =
        '🆘 SOS ALERT from $userName!\n'
        '📍 Location: $locationShort\n'
        'https://maps.google.com/?q='
        '${_lastPosition?.latitude ?? 0},'
        '${_lastPosition?.longitude ?? 0}';

    _statusMessage = 'Sending SOS alert...';
    notifyListeners();

    // Step 3: Send via all channels simultaneously
    await Future.wait([
      _sendViaBluetooth(sosMessage),
      _sendViaOnline(sosMessage),
      _sendAllSMS(
        userName: userName,
        locationText: locationText,
      ),
    ]);

    // Step 4: Save SOS log to database
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
    AppLogger.sos('SOS log saved to database ✅');

    // Step 5: Mark as active
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
  Future<void> _sendViaBluetooth(String message) async {
    try {
      final result = await _bluetoothController.sendMessage(message);
      _bluetoothSent = result;
      AppLogger.bluetooth('SOS via Bluetooth: $result');
    } catch (e) {
      AppLogger.error('BT SOS failed', error: e);
    }
    notifyListeners();
  }

  // ── Send via Online (Firebase) ───────────────────────────────────
  Future<void> _sendViaOnline(String message) async {
    try {
      final result = await _chatController.sendMessage(message);
      _onlineSent = result;
      AppLogger.success('SOS via Online: $result');
    } catch (e) {
      AppLogger.error('Online SOS failed', error: e);
    }
    notifyListeners();
  }

  // ── Send SMS to ALL Emergency Contacts ───────────────────────────
  Future<void> _sendAllSMS({
    required String userName,
    required String locationText,
  }) async {
    final contacts = await EmergencyContactsService.getContacts();

    if (contacts.isEmpty) {
      AppLogger.warning('No emergency contacts saved — skipping SMS');
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

    AppLogger.sos(
      'SMS sent to $_smsSentCount/${contacts.length} contacts',
    );
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
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}