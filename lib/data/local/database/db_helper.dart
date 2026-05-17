import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../local/models/message_model.dart';
import '../../local/models/sos_log_model.dart';
import '../../../core/utils/logger.dart';

class DbHelper {
  static const String _dbName    = 'safe_connect.db';
  static const int    _dbVersion = 2; // ← bumped for migration

  static const String messagesTable = 'messages';
  static const String sosLogsTable  = 'sos_logs';

  static Database? _database;

  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path   = join(dbPath, _dbName);
    AppLogger.info('Opening database at: $path', tag: 'DB');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ── Create Tables (fresh install) ────────────────────────────────
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $messagesTable (
        id             TEXT PRIMARY KEY,
        senderId       TEXT NOT NULL,
        senderName     TEXT NOT NULL,
        content        TEXT NOT NULL,
        type           TEXT NOT NULL,
        status         TEXT NOT NULL,
        timestamp      TEXT NOT NULL,
        isMe           INTEGER NOT NULL,
        hopCount       INTEGER DEFAULT 0,
        isEncrypted    INTEGER DEFAULT 0,
        channel        TEXT DEFAULT 'bluetooth',
        conversationId TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE $sosLogsTable (
        id             TEXT PRIMARY KEY,
        timestamp      TEXT NOT NULL,
        latitude       REAL,
        longitude      REAL,
        locationText   TEXT,
        userName       TEXT NOT NULL,
        bluetoothSent  INTEGER DEFAULT 0,
        onlineSent     INTEGER DEFAULT 0,
        smsSentCount   INTEGER DEFAULT 0,
        status         TEXT NOT NULL
      )
    ''');

    AppLogger.success('Database tables created ✅', tag: 'DB');
  }

  // ── Migration: add conversationId to existing installs ───────────
  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          "ALTER TABLE $messagesTable ADD COLUMN conversationId TEXT DEFAULT ''",
        );

        // Back-fill: for received messages (isMe=0) set conversationId = senderId
        await db.execute(
          "UPDATE $messagesTable SET conversationId = senderId WHERE isMe = 0",
        );

        // For sent messages (isMe=1) we can't know who they were sent to
        // from old data, so leave as '' — they'll be excluded from
        // specific conversations but won't pollute other chats
        AppLogger.info('Migration v2: conversationId column added ✅', tag: 'DB');
      } catch (e) {
        AppLogger.error('Migration v2 failed', tag: 'DB', error: e);
      }
    }
  }

  // ════════════════════════════════════════════════════════════════
  // MESSAGES
  // ════════════════════════════════════════════════════════════════

  static Future<void> insertMessage(
    MessageModel message, {
    String channel = 'bluetooth',
  }) async {
    try {
      final db = await database;
      await db.insert(
        messagesTable,
        {
          'id':             message.id,
          'senderId':       message.senderId,
          'senderName':     message.senderName,
          'content':        message.content,
          'type':           message.type.name,
          'status':         message.status.name,
          'timestamp':      message.timestamp.toIso8601String(),
          'isMe':           message.isMe ? 1 : 0,
          'hopCount':       message.hopCount,
          'isEncrypted':    message.isEncrypted ? 1 : 0,
          'channel':        channel,
          'conversationId': message.conversationId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      AppLogger.info('Message saved: ${message.id}', tag: 'DB');
    } catch (e) {
      AppLogger.error('Failed to save message', tag: 'DB', error: e);
    }
  }

  static Future<List<MessageModel>> getMessages({int limit = 500}) async {
    try {
      final db   = await database;
      final maps = await db.query(
        messagesTable,
        orderBy: 'timestamp ASC',
        limit: limit,
      );

      return maps.map((map) => MessageModel(
        id:             map['id'] as String,
        senderId:       map['senderId'] as String,
        senderName:     map['senderName'] as String,
        content:        map['content'] as String,
        type: MessageType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => MessageType.text,
        ),
        status: MessageStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => MessageStatus.delivered,
        ),
        timestamp:      DateTime.parse(map['timestamp'] as String),
        isMe:           (map['isMe'] as int) == 1,
        hopCount:       map['hopCount'] as int? ?? 0,
        isEncrypted:    (map['isEncrypted'] as int? ?? 0) == 1,
        conversationId: map['conversationId'] as String? ?? '',
      )).toList();
    } catch (e) {
      AppLogger.error('Failed to load messages', tag: 'DB', error: e);
      return [];
    }
  }

  static Future<void> clearMessages() async {
    try {
      final db = await database;
      await db.delete(messagesTable);
      AppLogger.info('All messages cleared', tag: 'DB');
    } catch (e) {
      AppLogger.error('Failed to clear messages', tag: 'DB', error: e);
    }
  }

  static Future<void> clearMessagesForSender(String senderId) async {
    try {
      final db = await database;
      // Clear both received messages FROM sender AND sent messages TO sender
      await db.delete(
        messagesTable,
        where: 'senderId = ? OR conversationId = ?',
        whereArgs: [senderId, senderId],
      );
      AppLogger.info('Messages cleared for: $senderId', tag: 'DB');
    } catch (e) {
      AppLogger.error('Failed to clear messages for sender', tag: 'DB', error: e);
    }
  }

  static Future<int> getMessageCount() async {
    try {
      final db     = await database;
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

  static Future<void> insertSosLog(SosLog log) async {
    try {
      final db = await database;
      await db.insert(
        sosLogsTable,
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      AppLogger.sos('SOS log saved ✅');
    } catch (e) {
      AppLogger.error('Failed to save SOS log', tag: 'DB', error: e);
    }
  }

  static Future<List<SosLog>> getSosLogs() async {
    try {
      final db   = await database;
      final maps = await db.query(sosLogsTable, orderBy: 'timestamp DESC');
      return maps.map((m) => SosLog.fromMap(m)).toList();
    } catch (e) {
      AppLogger.error('Failed to load SOS logs', tag: 'DB', error: e);
      return [];
    }
  }

  static Future<void> clearSosLogs() async {
    try {
      final db = await database;
      await db.delete(sosLogsTable);
      AppLogger.info('SOS logs cleared', tag: 'DB');
    } catch (e) {
      AppLogger.error('Failed to clear SOS logs', tag: 'DB', error: e);
    }
  }

  static Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}