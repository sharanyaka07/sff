import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/contacts_sync_service.dart';
import '../../../core/services/emergency_contacts_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/models/emergency_contact_model.dart';

class ContactPickerScreen extends StatefulWidget {
  const ContactPickerScreen({super.key});

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  List<Contact> _allContacts = [];
  List<Contact> _filtered = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final contacts = await ContactsSyncService.getPhoneContacts();
    setState(() {
      _allContacts = contacts;
      _filtered = contacts;
      _loading = false;
    });
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _allContacts;
      } else {
        _filtered = _allContacts.where((c) {
          final name = c.displayName.toLowerCase();
          final phone = ContactsSyncService
              .getDisplayPhone(c)
              .toLowerCase();
          return name.contains(query.toLowerCase()) ||
              phone.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _addToEmergency(Contact contact) async {
    final phone = ContactsSyncService.getDisplayPhone(contact);
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This contact has no phone number'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final emergencyContact = EmergencyContact(
      id: const Uuid().v4(),
      name: contact.displayName,
      phone: phone,
      relation: 'Contact',
    );

    await EmergencyContactsService.addContact(emergencyContact);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${contact.displayName} added to emergency contacts ✅',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.danger,
        title: const Text('Import from Phone'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.contacts_outlined,
                          size: 60, color: AppColors.textHint),
                      SizedBox(height: 12),
                      Text(
                        'No contacts found',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final contact = _filtered[index];
                    final phone =
                        ContactsSyncService.getDisplayPhone(contact);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.danger.withValues(alpha: 0.1),
                        child: Text(
                          contact.displayName.isNotEmpty
                              ? contact.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        contact.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        phone.isEmpty ? 'No number' : phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: phone.isEmpty
                              ? AppColors.textHint
                              : AppColors.textSecondary,
                        ),
                      ),
                      trailing: phone.isEmpty
                          ? const Icon(Icons.block,
                              color: AppColors.textHint, size: 20)
                          : IconButton(
                              icon: const Icon(Icons.person_add,
                                  color: AppColors.danger),
                              onPressed: () => _addToEmergency(contact),
                              tooltip: 'Add to emergency contacts',
                            ),
                    );
                  },
                ),
    );
  }
}