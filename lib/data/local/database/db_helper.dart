  import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../local/models/message_model.dart';
import '../../local/models/sos_log_model.dart';
import '../../../core/utils/logger.dart';

class DbHelper {
  static const String _dbName = 'safe_connect.db';
  static const int _dbVersion = 1;

  // Table names
  static const String messagesTable = 'messages';
  static const String sosLogsTable = 'sos_logs';

  static Database? _database;

  // ── Singleton ────────────────────────────────────────────────────
  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    AppLogger.info('Opening database at: $path', tag: 'DB');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  // ── Create Tables ────────────────────────────────────────────────
  static Future<void> _onCreate(Database db, int version) async {
    // Messages table
    await db.execute('''
      CREATE TABLE $messagesTable (
        id TEXT PRIMARY KEY,
        senderId TEXT NOT NULL,
        senderName TEXT NOT NULL,
        content TEXT NOT NULL,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        isMe INTEGER NOT NULL,
        hopCount INTEGER DEFAULT 0,
        isEncrypted INTEGER DEFAULT 0,
        channel TEXT DEFAULT 'bluetooth'
      )
    ''');

    // SOS Logs table
    await db.execute('''
      CREATE TABLE $sosLogsTable (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        locationText TEXT,
        userName TEXT NOT NULL,
        bluetoothSent INTEGER DEFAULT 0,
        onlineSent INTEGER DEFAULT 0,
        smsSentCount INTEGER DEFAULT 0,
        status TEXT NOT NULL
      )
    ''');

    AppLogger.success('Database tables created ✅', tag: 'DB');
  }

  // ════════════════════════════════════════════════════════════════
  // MESSAGES
  // ════════════════════════════════════════════════════════════════

  // ── Insert message ───────────────────────────────────────────────
  static Future<void> insertMessage(
    MessageModel message, {
    String channel = 'bluetooth',
  }) async {
    try {
      final db = await database;
      await db.insert(
        messagesTable,
        {
          'id': message.id,
          'senderId': message.senderId,
          'senderName': message.senderName,
          'content': message.content,
          'type': message.type.name,
          'status': message.status.name,
          'timestamp': message.timestamp.toIso8601String(),
          'isMe': message.isMe ? 1 : 0,
          'hopCount': message.hopCount,
          'isEncrypted': message.isEncrypted ? 1 : 0,
          'channel': channel,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      AppLogger.info('Message saved to DB: ${message.id}', tag: 'DB');
    } catch (e) {
      AppLogger.error('Failed to save message', tag: 'DB', error: e);
    }
  }

  // ── Get all messages ─────────────────────────────────────────────
  static Future<List<MessageModel>> getMessages({int limit = 100}) async {
    try {
      final db = await database;
      final maps = await db.query(
        messagesTable,
        orderBy: 'timestamp ASC',
        limit: limit,
      );

      return maps.map((map) => MessageModel(
        id: map['id'] as String,
        senderId: map['senderId'] as String,
        senderName: map['senderName'] as String,
        content: map['content'] as String,
        type: MessageType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => MessageType.text,
        ),
        status: MessageStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => MessageStatus.delivered,
        ),
        timestamp: DateTime.parse(map['timestamp'] as String),
        isMe: (map['isMe'] as int) == 1,
        hopCount: map['hopCount'] as int? ?? 0,
        isEncrypted: (map['isEncrypted'] as int? ?? 0) == 1,
      )).toList();
    } catch (e) {
      AppLogger.error('Failed to load messages', tag: 'DB', error: e);
      return [];
    }
  }

  // ── Delete all messages ──────────────────────────────────────────
  static Future<void> clearMessages() async {
    try {
      final db = await database;
      await db.delete(messagesTable);
      AppLogger.info('All messages cleared', tag: 'DB');
    } catch (e) {
      AppLogger.error('Failed to clear messages', tag: 'DB', error: e);
    }
  }

  // ── Get message count ────────────────────────────────────────────
  static Future<int> getMessageCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $messagesTable',
      );
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // SOS LOGS
  // ════════════════════════════════════════════════════════════════

  // ── Insert SOS log ───────────────────────────────────────────────
  static Future<void> insertSosLog(SosLog log) async {
    try {
      final db = await database;
      await db.insert(
        sosLogsTable,
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      AppLogger.sos('SOS log saved to DB ✅');
    } catch (e) {
      AppLogger.error('Failed to save SOS log', tag: 'DB', error: e);
    }
  }

  // ── Get all SOS logs ─────────────────────────────────────────────
  static Future<List<SosLog>> getSosLogs() async {
    try {
      final db = await database;
      final maps = await db.query(
        sosLogsTable,
        orderBy: 'timestamp DESC',
      );
      return maps.map((m) => SosLog.fromMap(m)).toList();
    } catch (e) {
      AppLogger.error('Failed to load SOS logs', tag: 'DB', error: e);
      return [];
    }
  }

  // ── Clear SOS logs ───────────────────────────────────────────────
  static Future<void> clearSosLogs() async {
    try {
      final db = await database;
      await db.delete(sosLogsTable);
      AppLogger.info('SOS logs cleared', tag: 'DB');
    } catch (e) {
      AppLogger.error('Failed to clear SOS logs', tag: 'DB', error: e);
    }
  }

  // ── Close database ───────────────────────────────────────────────
  static Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}