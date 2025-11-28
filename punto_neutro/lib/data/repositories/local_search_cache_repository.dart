import '../../domain/repositories/search_repository.dart';
import '../../domain/models/search_query.dart';
import '../../domain/models/search_result.dart';
import '../services/search_cache_local_storage.dart';

/// Local Search Cache Repository
///
/// Implementation of SearchCacheRepository using SQLite persistence.
/// Provides instant search results from cache (offline-capable).
///
/// Features:
/// - LRU eviction policy (configurable max size)
/// - TTL expiration (default 1 hour)
/// - Always available (offline-first)
/// - Statistics tracking

class LocalSearchCacheRepository implements SearchCacheRepository {
  final SearchCacheLocalStorage _storage;

  LocalSearchCacheRepository({SearchCacheLocalStorage? storage})
      : _storage = storage ?? SearchCacheLocalStorage();

  @override
  Future<SearchResult> search(SearchQuery query) async {
    final cached = await getCachedResult(query);
    if (cached != null) {
      return cached;
    }
    throw Exception('Cache miss - no cached result for query: ${query.query}');
  }

  @override
  Future<bool> isAvailable() async {
    return true; // Cache is always available (local-only)
  }

  @override
  Future<SearchResult?> getCachedResult(SearchQuery query) async {
    return await _storage.getCachedResult(query);
  }

  @override
  Future<void> cacheResult(
    SearchQuery query,
    SearchResult result, {
    Duration? ttl,
  }) async {
    await _storage.cacheResult(query, result, ttl: ttl);
  }

  @override
  Future<int> deleteExpiredEntries() async {
    return await _storage.deleteExpiredEntries();
  }

  @override
  Future<void> clearCache() async {
    await _storage.clearCache();
  }

  @override
  Future<Map<String, dynamic>> getStatistics() async {
    return await _storage.getStatistics();
  }
}
