import 'package:uuid/uuid.dart';

class SosLog {
  final String id;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String? locationText;
  final String userName;
  final bool bluetoothSent;
  final bool onlineSent;
  final int smsSentCount;
  final String status;

  const SosLog({
    required this.id,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.locationText,
    required this.userName,
    required this.bluetoothSent,
    required this.onlineSent,
    required this.smsSentCount,
    required this.status,
  });

  // ── Create a new SOS log ─────────────────────────────────────────
  factory SosLog.create({
    required String userName,
    double? latitude,
    double? longitude,
    String? locationText,
    bool bluetoothSent = false,
    bool onlineSent = false,
    int smsSentCount = 0,
    String status = 'sent',
  }) {
    return SosLog(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      locationText: locationText,
      userName: userName,
      bluetoothSent: bluetoothSent,
      onlineSent: onlineSent,
      smsSentCount: smsSentCount,
      status: status,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'locationText': locationText,
        'userName': userName,
        'bluetoothSent': bluetoothSent ? 1 : 0,
        'onlineSent': onlineSent ? 1 : 0,
        'smsSentCount': smsSentCount,
        'status': status,
      };

  factory SosLog.fromMap(Map<String, dynamic> map) => SosLog(
        id: map['id'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        latitude: map['latitude'] as double?,
        longitude: map['longitude'] as double?,
        locationText: map['locationText'] as String?,
        userName: map['userName'] as String,
        bluetoothSent: (map['bluetoothSent'] as int) == 1,
        onlineSent: (map['onlineSent'] as int) == 1,
        smsSentCount: map['smsSentCount'] as int,
        status: map['status'] as String,
      );

  // ── Formatted date ───────────────────────────────────────────────
  String get formattedDate {
    final d = timestamp;
    return '${d.day}/${d.month}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  // ── Channels used ────────────────────────────────────────────────
  String get channelsSummary {
    final channels = <String>[];
    if (bluetoothSent) channels.add('Bluetooth');
    if (onlineSent) channels.add('Internet');
    if (smsSentCount > 0) channels.add('SMS×$smsSentCount');
    return channels.isEmpty ? 'None' : channels.join(' • ');
  }
}