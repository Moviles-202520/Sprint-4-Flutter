import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/models/upload_queue_entry.dart';

/// Local SQLite storage for upload queue.
/// 
/// Tracks pending news uploads with retry logic and exponential backoff.
class UploadQueueLocalStorage {
  static final UploadQueueLocalStorage _instance =
      UploadQueueLocalStorage._internal();
  static Database? _database;

  factory UploadQueueLocalStorage() => _instance;

  UploadQueueLocalStorage._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'upload_queue.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE upload_queue (
        queue_id INTEGER PRIMARY KEY AUTOINCREMENT,
        draft_id INTEGER NOT NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at TEXT,
        next_retry_at TEXT,
        upload_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_queue_status ON upload_queue(status)');
    await db.execute(
        'CREATE INDEX idx_queue_draft ON upload_queue(draft_id)');
    await db.execute(
        'CREATE INDEX idx_queue_next_retry ON upload_queue(next_retry_at)');
  }

  Future<int> enqueue(UploadQueueEntry entry) async {
    final db = await database;
    return await db.insert('upload_queue', entry.toJson());
  }

  Future<UploadQueueEntry?> getEntry(int queueId) async {
    final db = await database;
    final results = await db.query(
      'upload_queue',
      where: 'queue_id = ?',
      whereArgs: [queueId],
    );

    if (results.isEmpty) return null;
    return UploadQueueEntry.fromJson(results.first);
  }

  Future<List<UploadQueueEntry>> getPendingEntries() async {
    final db = await database;
    final results = await db.query(
      'upload_queue',
      where: 'status = ?',
      whereArgs: [UploadStatus.pending.name],
      orderBy: 'created_at ASC',
    );

    return results.map((json) => UploadQueueEntry.fromJson(json)).toList();
  }

  Future<List<UploadQueueEntry>> getRetryableEntries() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final results = await db.query(
      'upload_queue',
      where: 'status = ? AND (next_retry_at IS NULL OR next_retry_at <= ?)',
      whereArgs: [UploadStatus.failed.name, now],
      orderBy: 'created_at ASC',
    );

    return results.map((json) => UploadQueueEntry.fromJson(json)).toList();
  }

  Future<void> updateEntry(UploadQueueEntry entry) async {
    final db = await database;
    await db.update(
      'upload_queue',
      entry.toJson(),
      where: 'queue_id = ?',
      whereArgs: [entry.queueId],
    );
  }

  Future<void> deleteEntry(int queueId) async {
    final db = await database;
    await db.delete(
      'upload_queue',
      where: 'queue_id = ?',
      whereArgs: [queueId],
    );
  }

  Future<void> deleteCompleted({int? olderThanDays}) async {
    final db = await database;

    if (olderThanDays != null) {
      final cutoff =
          DateTime.now().subtract(Duration(days: olderThanDays)).toIso8601String();
      await db.delete(
        'upload_queue',
        where: 'status = ? AND updated_at < ?',
        whereArgs: [UploadStatus.completed.name, cutoff],
      );
    } else {
      await db.delete(
        'upload_queue',
        where: 'status = ?',
        whereArgs: [UploadStatus.completed.name],
      );
    }
  }

  Future<int> getQueueCount({UploadStatus? status}) async {
    final db = await database;

    if (status != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM upload_queue WHERE status = ?',
        [status.name],
      );
      return (result.first['count'] as int?) ?? 0;
    } else {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM upload_queue');
      return (result.first['count'] as int?) ?? 0;
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
