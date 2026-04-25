import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local/models/emergency_contact_model.dart';
import '../utils/logger.dart';

class EmergencyContactsService {
  static const String _key = 'emergency_contacts';

  // ── Load all contacts ──────────────────────────────────────────
  static Future<List<EmergencyContact>> getContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_key);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> list = jsonDecode(jsonStr);
      return list
          .map((e) => EmergencyContact.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to load contacts', error: e);
      return [];
    }
  }

  // ── Save all contacts ──────────────────────────────────────────
  static Future<void> saveContacts(List<EmergencyContact> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(contacts.map((c) => c.toMap()).toList());
      await prefs.setString(_key, jsonStr);
      AppLogger.success('${contacts.length} contacts saved');
    } catch (e) {
      AppLogger.error('Failed to save contacts', error: e);
    }
  }

  // ── Add a contact ──────────────────────────────────────────────
  static Future<List<EmergencyContact>> addContact(
      EmergencyContact contact) async {
    final contacts = await getContacts();
    contacts.add(contact);
    await saveContacts(contacts);
    return contacts;
  }

  // ── Remove a contact ───────────────────────────────────────────
  static Future<List<EmergencyContact>> removeContact(String id) async {
    final contacts = await getContacts();
    contacts.removeWhere((c) => c.id == id);
    await saveContacts(contacts);
    return contacts;
  }
}