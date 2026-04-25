class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relation; // e.g. "Father", "Friend"

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'relation': relation,
      };

  factory EmergencyContact.fromMap(Map<String, dynamic> map) =>
      EmergencyContact(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String,
        relation: map['relation'] as String,
      );

  // Convert list to JSON string for SharedPreferences
  static String listToJson(List<EmergencyContact> contacts) {
    final list = contacts.map((c) => c.toMap()).toList();
    return list.toString(); // We'll use proper encoding below
  }
}