import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

class ContactsSyncService {
  // ── Fetch all phone contacts ──────────────────────────────────────
  static Future<List<Contact>> getPhoneContacts() async {
    try {
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        AppLogger.warning('Contacts permission denied');
        return [];
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      // Only return contacts that have phone numbers
      final withPhone = contacts
          .where((c) => c.phones.isNotEmpty)
          .toList();

      AppLogger.success(
        'Loaded ${withPhone.length} contacts with phone numbers',
      );
      return withPhone;
    } catch (e) {
      AppLogger.error('Failed to load contacts', error: e);
      return [];
    }
  }

  // ── Format contact phone for display ─────────────────────────────
  static String getDisplayPhone(Contact contact) {
    if (contact.phones.isEmpty) return '';
    return contact.phones.first.number;
  }
}