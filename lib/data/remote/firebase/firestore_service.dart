import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../local/models/message_model.dart';
import '../../local/models/sos_log_model.dart';
import '../../local/models/emergency_contact_model.dart';
import '../../../core/utils/logger.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static const _messagesCol = 'messages';
  static const _sosLogsCol  = 'sos_logs';
  static const _contactsCol = 'emergency_contacts';

  // ── Anonymous sign-in (call once at startup) ─────────────────────
  static Future<String?> signInAnonymously() async {
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      AppLogger.success('Auth UID: ${cred.user?.uid}', tag: 'FS');
      return cred.user?.uid;
    } catch (e) {
      AppLogger.error('Anonymous sign-in failed', tag: 'FS', error: e);
      return null;
    }
  }

  static String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  // ════════════════════════════════════════════════════════════════
  // MESSAGES
  // ════════════════════════════════════════════════════════════════

  static Future<void> saveMessage(
    MessageModel msg, {
    String channel = 'bluetooth',
  }) async {
    try {
      await _db.collection(_messagesCol).doc(msg.id).set({
        'id':             msg.id,
        'senderId':       msg.senderId,
        'senderName':     msg.senderName,
        'content':        msg.content,
        'type':           msg.type.name,
        'status':         msg.status.name,
        'timestamp':      Timestamp.fromDate(msg.timestamp),
        'isMe':           msg.isMe,
        'hopCount':       msg.hopCount,
        'isEncrypted':    msg.isEncrypted,
        'channel':        channel,
        'conversationId': msg.conversationId,
      });
      AppLogger.info('Firestore: message saved ${msg.id}', tag: 'FS');
    } catch (e) {
      AppLogger.error('Firestore: save message failed', tag: 'FS', error: e);
    }
  }

  static Future<List<MessageModel>> getMessages({int limit = 500}) async {
    try {
      final snap = await _db
          .collection(_messagesCol)
          .orderBy('timestamp')
          .limit(limit)
          .get();
      return snap.docs.map(_docToMessage).toList();
    } catch (e) {
      AppLogger.error('Firestore: load messages failed', tag: 'FS', error: e);
      return [];
    }
  }

  static Stream<List<MessageModel>> messagesStream({String? conversationId}) {
    Query<Map<String, dynamic>> q =
        _db.collection(_messagesCol).orderBy('timestamp');

    if (conversationId != null && conversationId.isNotEmpty) {
      q = q.where('conversationId', isEqualTo: conversationId);
    }
    return q.snapshots().map(
          (snap) => snap.docs.map(_docToMessage).toList(),
        );
  }

  static MessageModel _docToMessage(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return MessageModel(
      id:             d['id'] as String,
      senderId:       d['senderId'] as String,
      senderName:     d['senderName'] as String,
      content:        d['content'] as String,
      type:           MessageType.values.firstWhere(
                        (e) => e.name == d['type'],
                        orElse: () => MessageType.text),
      status:         MessageStatus.values.firstWhere(
                        (e) => e.name == d['status'],
                        orElse: () => MessageStatus.delivered),
      timestamp:      (d['timestamp'] as Timestamp).toDate(),
      isMe:           d['isMe'] as bool? ?? false,
      hopCount:       d['hopCount'] as int? ?? 0,
      isEncrypted:    d['isEncrypted'] as bool? ?? false,
      conversationId: d['conversationId'] as String? ?? '',
    );
  }

  static Future<void> deleteMessage(String messageId) async {
    try {
      await _db.collection(_messagesCol).doc(messageId).delete();
      AppLogger.info('Firestore: message deleted $messageId', tag: 'FS');
    } catch (e) {
      AppLogger.error('Firestore: delete message failed', tag: 'FS', error: e);
    }
  }

  static Future<void> clearAllMessages() async {
    try {
      final snap  = await _db.collection(_messagesCol).get();
      final batch = _db.batch();
      for (final doc in snap.docs) { batch.delete(doc.reference); }
      await batch.commit();
    } catch (e) {
      AppLogger.error('Firestore: clear messages failed', tag: 'FS', error: e);
    }
  }

  // ════════════════════════════════════════════════════════════════
  // SOS LOGS
  // ════════════════════════════════════════════════════════════════

  static Future<void> saveSosLog(SosLog log) async {
    try {
      await _db.collection(_sosLogsCol).doc(log.id).set({
        'id':            log.id,
        'timestamp':     Timestamp.fromDate(log.timestamp),
        'latitude':      log.latitude,
        'longitude':     log.longitude,
        'locationText':  log.locationText,
        'userName':      log.userName,
        'bluetoothSent': log.bluetoothSent,
        'onlineSent':    log.onlineSent,
        'smsSentCount':  log.smsSentCount,
        'status':        log.status,
      });
      AppLogger.sos('Firestore: SOS log saved');
    } catch (e) {
      AppLogger.error('Firestore: save SOS log failed', tag: 'FS', error: e);
    }
  }

  static Future<List<SosLog>> getSosLogs() async {
    try {
      final snap = await _db
          .collection(_sosLogsCol)
          .orderBy('timestamp', descending: true)
          .get();
      return snap.docs.map((doc) {
        final d = doc.data();
        return SosLog(
          id:            d['id'] as String,
          timestamp:     (d['timestamp'] as Timestamp).toDate(),
          latitude:      (d['latitude'] as num?)?.toDouble(),
          longitude:     (d['longitude'] as num?)?.toDouble(),
          locationText:  d['locationText'] as String?,
          userName:      d['userName'] as String,
          bluetoothSent: d['bluetoothSent'] as bool? ?? false,
          onlineSent:    d['onlineSent'] as bool? ?? false,
          smsSentCount:  d['smsSentCount'] as int? ?? 0,
          status:        d['status'] as String,
        );
      }).toList();
    } catch (e) {
      AppLogger.error('Firestore: load SOS logs failed', tag: 'FS', error: e);
      return [];
    }
  }

  static Stream<List<SosLog>> sosLogsStream() {
    return _db
        .collection(_sosLogsCol)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return SosLog(
                id:            d['id'] as String,
                timestamp:     (d['timestamp'] as Timestamp).toDate(),
                latitude:      (d['latitude'] as num?)?.toDouble(),
                longitude:     (d['longitude'] as num?)?.toDouble(),
                locationText:  d['locationText'] as String?,
                userName:      d['userName'] as String,
                bluetoothSent: d['bluetoothSent'] as bool? ?? false,
                onlineSent:    d['onlineSent'] as bool? ?? false,
                smsSentCount:  d['smsSentCount'] as int? ?? 0,
                status:        d['status'] as String,
              );
            }).toList());
  }

  // ════════════════════════════════════════════════════════════════
  // EMERGENCY CONTACTS  (per-user subcollection)
  // ════════════════════════════════════════════════════════════════

  static Future<void> saveContacts(List<EmergencyContact> contacts) async {
    final uid = currentUid;
    if (uid == null) return;

    try {
      final colRef = _db.collection(_contactsCol).doc(uid).collection('list');
      final batch  = _db.batch();

      final existing = await colRef.get();
      for (final doc in existing.docs) { batch.delete(doc.reference); }
      for (final c in contacts) { batch.set(colRef.doc(c.id), c.toMap()); }

      await batch.commit();
      AppLogger.info('Firestore: contacts saved (${contacts.length})', tag: 'FS');
    } catch (e) {
      AppLogger.error('Firestore: save contacts failed', tag: 'FS', error: e);
    }
  }

  static Future<List<EmergencyContact>> getContacts() async {
    final uid = currentUid;
    if (uid == null) return [];

    try {
      final snap = await _db
          .collection(_contactsCol)
          .doc(uid)
          .collection('list')
          .get();
      return snap.docs
          .map((doc) => EmergencyContact.fromMap(doc.data()))
          .toList();
    } catch (e) {
      AppLogger.error('Firestore: load contacts failed', tag: 'FS', error: e);
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════════
  // FCM TOKEN  (so devices can message each other)
  // ════════════════════════════════════════════════════════════════

  static Future<void> saveFcmToken({
    required String deviceId,
    required String deviceName,
    required String fcmToken,
  }) async {
    try {
      await _db.collection('devices').doc(deviceId).set({
        'deviceId':   deviceId,
        'deviceName': deviceName,
        'fcmToken':   fcmToken,
        'lastSeen':   FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      AppLogger.info('Firestore: FCM token saved', tag: 'FS');
    } catch (e) {
      AppLogger.error('Firestore: save FCM token failed', tag: 'FS', error: e);
    }
  }

  static Future<String?> getFcmToken(String deviceId) async {
    try {
      final doc = await _db.collection('devices').doc(deviceId).get();
      return doc.data()?['fcmToken'] as String?;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllDevices() async {
    try {
      final snap = await _db.collection('devices').get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      return [];
    }
  }
}