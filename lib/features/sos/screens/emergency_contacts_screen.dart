import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/emergency_contacts_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/models/emergency_contact_model.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<EmergencyContact> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await EmergencyContactsService.getContacts();
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  Future<void> _addContact() async {
    final result = await showDialog<EmergencyContact>(
      context: context,
      builder: (_) => const _AddContactDialog(),
    );
    if (result != null) {
      final updated = await EmergencyContactsService.addContact(result);
      setState(() => _contacts = updated);
    }
  }

  Future<void> _removeContact(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Contact?'),
        content: Text('Remove $name from emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final updated = await EmergencyContactsService.removeContact(id);
      setState(() => _contacts = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name removed'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.danger,
        title: const Text('Emergency Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _addContact,
            tooltip: 'Add Contact',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 16),
                  color: AppColors.danger.withValues(alpha: 0.08),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: AppColors.danger),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SOS alerts will be sent to ALL contacts below via SMS',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contact list
                Expanded(
                  child: _contacts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _contacts.length,
                          itemBuilder: (context, index) {
                            final contact = _contacts[index];
                            return _ContactCard(
                              contact: contact,
                              onRemove: () =>
                                  _removeContact(contact.id, contact.name),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addContact,
        backgroundColor: AppColors.danger,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Add Contact',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.contacts_outlined,
              size: 80, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'No Emergency Contacts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add contacts who will receive\nyour SOS alert via SMS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addContact,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            icon: const Icon(Icons.person_add),
            label: const Text('Add First Contact'),
          ),
        ],
      ),
    );
  }
}

// ── Contact Card ───────────────────────────────────────────────────
class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final VoidCallback onRemove;

  const _ContactCard({
    required this.contact,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: AppColors.danger.withValues(alpha: 0.15),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.danger.withValues(alpha: 0.1),
          radius: 24,
          child: Text(
            contact.name.isNotEmpty
                ? contact.name[0].toUpperCase()
                : '?',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.danger,
            ),
          ),
        ),
        title: Text(
          contact.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.phone,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  contact.phone,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.people,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  contact.relation,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          onPressed: onRemove,
          tooltip: 'Remove',
        ),
      ),
    );
  }
}

// ── Add Contact Dialog ─────────────────────────────────────────────
class _AddContactDialog extends StatefulWidget {
  const _AddContactDialog();

  @override
  State<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<_AddContactDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRelation = 'Family';

  final List<String> _relations = [
    'Family',
    'Father',
    'Mother',
    'Spouse',
    'Sibling',
    'Friend',
    'Doctor',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.person_add, color: AppColors.danger),
          SizedBox(width: 8),
          Text('Add Emergency Contact'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              prefixIcon: Icon(Icons.person),
              hintText: 'e.g. John Doe',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number *',
              prefixIcon: Icon(Icons.phone),
              hintText: 'e.g. +91 9876543210',
            ),
          ),
          const SizedBox(height: 12),
          // Fixed: use initialValue instead of value
          DropdownButtonFormField<String>(
            initialValue: _selectedRelation,
            decoration: const InputDecoration(
              labelText: 'Relation',
              prefixIcon: Icon(Icons.people),
            ),
            items: _relations
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedRelation = val);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger),
          onPressed: () {
            final name = _nameController.text.trim();
            final phone = _phoneController.text.trim();

            if (name.isEmpty || phone.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Name and phone are required'),
                  backgroundColor: AppColors.warning,
                ),
              );
              return;
            }

            Navigator.pop(
              context,
              EmergencyContact(
                id: const Uuid().v4(),
                name: name,
                phone: phone,
                relation: _selectedRelation,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}