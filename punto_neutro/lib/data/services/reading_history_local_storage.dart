import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/models/reading_history.dart';

/// Local SQLite storage for reading history.
/// 
/// This is the primary storage for reading history - all history is stored
/// locally first (100% offline by default). Optional server sync can be
/// enabled for analytics purposes.
/// 
/// Features:
/// - Write-through: instant local storage when user opens article
/// - Privacy-first: data stays local unless sync is explicitly enabled
/// - Automatic cleanup: old entries can be deleted to save space
/// - Batch upload support: can mark entries as synced after upload
class ReadingHistoryLocalStorage {
  static final ReadingHistoryLocalStorage _instance =
      ReadingHistoryLocalStorage._internal();
  static Database? _database;

  factory ReadingHistoryLocalStorage() => _instance;

  ReadingHistoryLocalStorage._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'reading_history.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reading_history (
        read_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_profile_id INTEGER,
        news_item_id INTEGER NOT NULL,
        category_id INTEGER,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        duration_seconds INTEGER,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        last_sync_attempt TEXT
      )
    ''');

    // Indexes for common queries
    await db.execute(
        'CREATE INDEX idx_reading_history_news ON reading_history(news_item_id)');
    await db.execute(
        'CREATE INDEX idx_reading_history_created ON reading_history(created_at DESC)');
    await db.execute(
        'CREATE INDEX idx_reading_history_synced ON reading_history(is_synced)');
  }

  /// Start a new reading session
  /// This is called when user opens an article
  Future<int> startReadingSession({
    required int newsItemId,
    int? categoryId,
    int? userProfileId,
  }) async {
    final db = await database;
    final history = ReadingHistory.startSession(
      newsItemId: newsItemId,
      categoryId: categoryId,
      userProfileId: userProfileId,
    );

    return await db.insert('reading_history', history.toJson());
  }

  /// End a reading session by updating endedAt and calculating duration
  Future<void> endReadingSession(int readId, DateTime endedAt) async {
    final db = await database;

    // Get the original record to calculate duration
    final result = await db.query(
      'reading_history',
      where: 'read_id = ?',
      whereArgs: [readId],
    );

    if (result.isEmpty) return;

    final history = ReadingHistory.fromJson(result.first);
    final duration = endedAt.difference(history.startedAt).inSeconds;

    await db.update(
      'reading_history',
      {
        'ended_at': endedAt.toIso8601String(),
        'duration_seconds': duration,
      },
      where: 'read_id = ?',
      whereArgs: [readId],
    );
  }

  /// Get all reading history (most recent first)
  Future<List<ReadingHistory>> getAllHistory({
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final results = await db.query(
      'reading_history',
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );

    return results.map((json) => ReadingHistory.fromJson(json)).toList();
  }

  /// Get reading history for a specific news item
  Future<List<ReadingHistory>> getHistoryForNewsItem(int newsItemId) async {
    final db = await database;
    final results = await db.query(
      'reading_history',
      where: 'news_item_id = ?',
      whereArgs: [newsItemId],
      orderBy: 'created_at DESC',
    );

    return results.map((json) => ReadingHistory.fromJson(json)).toList();
  }

  /// Get reading history within a date range
  Future<List<ReadingHistory>> getHistoryInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    final results = await db.query(
      'reading_history',
      where: 'created_at BETWEEN ? AND ?',
      whereArgs: [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'created_at DESC',
    );

    return results.map((json) => ReadingHistory.fromJson(json)).toList();
  }

  /// Get total reading time in seconds
  Future<int> getTotalReadingTime({DateTime? since}) async {
    final db = await database;
    final where = since != null ? 'created_at >= ?' : null;
    final whereArgs = since != null ? [since.toIso8601String()] : null;

    final result = await db.rawQuery(
      '''
      SELECT SUM(duration_seconds) as total
      FROM reading_history
      ${where != null ? 'WHERE $where' : ''}
      ''',
      whereArgs,
    );

    return (result.first['total'] as int?) ?? 0;
  }

  /// Count total articles read
  Future<int> getArticlesReadCount({DateTime? since}) async {
    final db = await database;
    final where = since != null ? 'created_at >= ?' : null;
    final whereArgs = since != null ? [since.toIso8601String()] : null;

    final result = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT news_item_id) as count
      FROM reading_history
      ${where != null ? 'WHERE $where' : ''}
      ''',
      whereArgs,
    );

    return (result.first['count'] as int?) ?? 0;
  }

  /// Delete a specific history entry
  Future<void> deleteHistoryEntry(int readId) async {
    final db = await database;
    await db.delete(
      'reading_history',
      where: 'read_id = ?',
      whereArgs: [readId],
    );
  }

  /// Clear all reading history
  Future<void> clearAllHistory() async {
    final db = await database;
    await db.delete('reading_history');
  }

  /// Delete history older than specified days
  Future<int> deleteOldHistory(int daysOld) async {
    final db = await database;
    final cutoffDate =
        DateTime.now().subtract(Duration(days: daysOld)).toIso8601String();

    return await db.delete(
      'reading_history',
      where: 'created_at < ?',
      whereArgs: [cutoffDate],
    );
  }

  // ============================================================================
  // Optional Server Sync Methods (only used if sync is enabled)
  // ============================================================================

  /// Get entries that haven't been synced to server yet
  Future<List<ReadingHistory>> getUnsyncedHistory({int? limit}) async {
    final db = await database;
    final results = await db.query(
      'reading_history',
      where: 'is_synced = ? AND ended_at IS NOT NULL',
      whereArgs: [0],
      orderBy: 'created_at ASC',
      limit: limit,
    );

    return results.map((json) => ReadingHistory.fromJson(json)).toList();
  }

  /// Mark entries as synced after successful upload
  Future<void> markAsSynced(List<int> readIds) async {
    if (readIds.isEmpty) return;

    final db = await database;
    await db.update(
      'reading_history',
      {
        'is_synced': 1,
        'last_sync_attempt': DateTime.now().toIso8601String(),
      },
      where: 'read_id IN (${readIds.map((_) => '?').join(', ')})',
      whereArgs: readIds,
    );
  }

  /// Record a failed sync attempt
  Future<void> recordSyncAttempt(List<int> readIds) async {
    if (readIds.isEmpty) return;

    final db = await database;
    await db.update(
      'reading_history',
      {'last_sync_attempt': DateTime.now().toIso8601String()},
      where: 'read_id IN (${readIds.map((_) => '?').join(', ')})',
      whereArgs: readIds,
    );
  }

  /// Get count of unsynced entries
  Future<int> getUnsyncedCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM reading_history WHERE is_synced = 0 AND ended_at IS NOT NULL',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get statistics about reading history
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;

    final totalEntries = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM reading_history'),
    );

    final totalTime = await getTotalReadingTime();
    final articlesRead = await getArticlesReadCount();
    final unsyncedCount = await getUnsyncedCount();

    return {
      'total_entries': totalEntries ?? 0,
      'total_reading_time_seconds': totalTime,
      'unique_articles_read': articlesRead,
      'unsynced_entries': unsyncedCount,
    };
  }

  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
