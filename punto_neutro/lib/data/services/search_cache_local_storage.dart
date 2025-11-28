import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../../domain/models/search_query.dart';
import '../../domain/models/search_result.dart';

/// Search Cache Local Storage
///
/// Implements persistent search result caching with LRU (Least Recently Used)
/// eviction policy and TTL (Time-To-Live) expiration.
///
/// Features:
/// - SQLite persistence (survives app restart)
/// - LRU eviction (removes least recently accessed entries when cache full)
/// - TTL expiration (configurable per query or global default)
/// - Cache key based on query + filters (deduplication)
/// - Access tracking (last_accessed_at updates on cache hit)
/// - Configurable max cache size (default 100 entries)
///
/// Database Schema:
/// - Table: search_cache
///   - cache_key (PK): Unique identifier for query
///   - query_text: Original search query
///   - result_data: JSON serialized SearchResult
///   - cached_at: When result was stored
///   - last_accessed_at: Last cache hit (for LRU)
///   - expires_at: TTL expiration timestamp
///   - access_count: Number of cache hits
///
/// Usage:
///   final storage = SearchCacheLocalStorage();
///   await storage.initialize();
///   
///   // Store result
///   await storage.cacheResult(query, result, ttl: Duration(hours: 1));
///   
///   // Retrieve result
///   final cached = await storage.getCachedResult(query);
///   if (cached != null) print('Cache hit!');

class SearchCacheLocalStorage {
  static const String _dbName = 'search_cache.db';
  static const int _dbVersion = 1;
  static const String _tableName = 'search_cache';

  Database? _database;

  /// Default TTL: 1 hour (search results can get stale quickly)
  static const Duration defaultTTL = Duration(hours: 1);

  /// Default max cache entries (LRU eviction kicks in after this)
  static const int defaultMaxCacheSize = 100;

  /// Initialize database and create tables
  Future<void> initialize() async {
    if (_database != null) return;

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);

    _database = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  /// Create database schema
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        cache_key TEXT PRIMARY KEY,
        query_text TEXT NOT NULL,
        result_data TEXT NOT NULL,
        cached_at TEXT NOT NULL,
        last_accessed_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        access_count INTEGER DEFAULT 1
      )
    ''');

    // Index on expires_at for efficient TTL cleanup
    await db.execute('''
      CREATE INDEX idx_search_cache_expires 
      ON $_tableName(expires_at)
    ''');

    // Index on last_accessed_at for efficient LRU eviction
    await db.execute('''
      CREATE INDEX idx_search_cache_lru 
      ON $_tableName(last_accessed_at)
    ''');
  }

  /// Get cached result for a query (returns null if miss or expired)
  Future<SearchResult?> getCachedResult(SearchQuery query) async {
    await initialize();
    final db = _database!;

    final now = DateTime.now();
    final cacheKey = query.cacheKey;

    // Query with TTL check
    final List<Map<String, dynamic>> results = await db.query(
      _tableName,
      where: 'cache_key = ? AND expires_at > ?',
      whereArgs: [cacheKey, now.toIso8601String()],
      limit: 1,
    );

    if (results.isEmpty) {
      return null; // Cache miss or expired
    }

    final row = results.first;

    // Update access metadata (LRU tracking)
    await db.update(
      _tableName,
      {
        'last_accessed_at': now.toIso8601String(),
        'access_count': (row['access_count'] as int) + 1,
      },
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
    );

    // Deserialize result
    final resultJson = jsonDecode(row['result_data'] as String);
    return SearchResult.fromJson(resultJson).copyWith(
      cachedAt: DateTime.parse(row['cached_at'] as String),
      source: SearchResultSource.cache,
    );
  }

  /// Store search result in cache
  Future<void> cacheResult(
    SearchQuery query,
    SearchResult result, {
    Duration? ttl,
  }) async {
    await initialize();
    final db = _database!;

    final now = DateTime.now();
    final expiresAt = now.add(ttl ?? defaultTTL);
    final cacheKey = query.cacheKey;

    // Serialize result
    final resultJson = jsonEncode(result.toJson());

    // Upsert (insert or replace)
    await db.insert(
      _tableName,
      {
        'cache_key': cacheKey,
        'query_text': query.query,
        'result_data': resultJson,
        'cached_at': now.toIso8601String(),
        'last_accessed_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'access_count': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Evict old entries if cache size exceeded (LRU policy)
    await _evictIfNeeded(maxSize: defaultMaxCacheSize);
  }

  /// Evict least recently used entries if cache size exceeds limit
  Future<void> _evictIfNeeded({required int maxSize}) async {
    final db = _database!;

    // Count total cache entries
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    );

    if (count == null || count <= maxSize) {
      return; // Cache size OK
    }

    // Calculate how many to delete
    final toDelete = count - maxSize;

    // Delete least recently accessed entries
    await db.delete(
      _tableName,
      where: 'cache_key IN (SELECT cache_key FROM $_tableName ORDER BY last_accessed_at ASC LIMIT ?)',
      whereArgs: [toDelete],
    );
  }

  /// Delete expired cache entries (TTL cleanup)
  Future<int> deleteExpiredEntries() async {
    await initialize();
    final db = _database!;

    final now = DateTime.now();
    return await db.delete(
      _tableName,
      where: 'expires_at <= ?',
      whereArgs: [now.toIso8601String()],
    );
  }

  /// Clear all cache entries
  Future<void> clearCache() async {
    await initialize();
    final db = _database!;
    await db.delete(_tableName);
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getStatistics() async {
    await initialize();
    final db = _database!;

    final now = DateTime.now();

    // Total entries
    final total = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    );

    // Valid (non-expired) entries
    final valid = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $_tableName WHERE expires_at > ?',
        [now.toIso8601String()],
      ),
    );

    // Expired entries
    final expired = (total ?? 0) - (valid ?? 0);

    // Total access count
    final totalAccesses = Sqflite.firstIntValue(
      await db.rawQuery('SELECT SUM(access_count) FROM $_tableName'),
    );

    // Average access count
    final avgAccesses = valid != null && valid > 0
        ? (totalAccesses ?? 0) / valid
        : 0.0;

    return {
      'total_entries': total ?? 0,
      'valid_entries': valid ?? 0,
      'expired_entries': expired,
      'total_accesses': totalAccesses ?? 0,
      'avg_accesses_per_entry': avgAccesses,
    };
  }

  /// Get most accessed queries (for analytics)
  Future<List<Map<String, dynamic>>> getMostAccessedQueries({
    int limit = 10,
  }) async {
    await initialize();
    final db = _database!;

    final now = DateTime.now();

    return await db.query(
      _tableName,
      columns: ['query_text', 'access_count', 'last_accessed_at'],
      where: 'expires_at > ?',
      whereArgs: [now.toIso8601String()],
      orderBy: 'access_count DESC',
      limit: limit,
    );
  }

  /// Delete specific cache entry
  Future<void> deleteCacheEntry(String cacheKey) async {
    await initialize();
    final db = _database!;
    await db.delete(
      _tableName,
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
    );
  }

  /// Close database connection
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
