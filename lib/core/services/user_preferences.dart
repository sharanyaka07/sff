import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class UserPreferences {
  static const String _keyUserName = 'user_name';
  static const String _keyEmergencyContact = 'emergency_contact';
  static const String _keyDeviceId = 'device_id';

  // ── User Name ──────────────────────────────────────────────────
  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName) ?? 'Unknown User';
  }

  static Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
    AppLogger.info('Username saved: $name');
  }

  // ── Emergency Contact ──────────────────────────────────────────
  static Future<String?> getEmergencyContact() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmergencyContact);
  }

  static Future<void> setEmergencyContact(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmergencyContact, phone);
    AppLogger.info('Emergency contact saved: $phone');
  }

  // ── Device ID ──────────────────────────────────────────────────
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDeviceId) ?? 'unknown';
  }
}