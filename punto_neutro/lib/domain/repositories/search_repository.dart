import '../models/search_query.dart';
import '../models/search_result.dart';

/// Abstract repository for search operations
///
/// Defines the contract for search implementations (cache, server, hybrid).
/// Supports different search strategies depending on connectivity and requirements.

abstract class SearchRepository {
  /// Search for news items matching the query
  /// 
  /// Returns [SearchResult] with matching news item IDs and metadata.
  /// May throw exceptions for network/server errors.
  Future<SearchResult> search(SearchQuery query);

  /// Check if search is available (e.g., network connectivity for server search)
  Future<bool> isAvailable();
}

/// Repository for cached search results (local-only)
abstract class SearchCacheRepository extends SearchRepository {
  /// Get cached result for query (null if miss or expired)
  Future<SearchResult?> getCachedResult(SearchQuery query);

  /// Store search result in cache with optional TTL
  Future<void> cacheResult(
    SearchQuery query,
    SearchResult result, {
    Duration? ttl,
  });

  /// Delete expired cache entries
  Future<int> deleteExpiredEntries();

  /// Clear all cache
  Future<void> clearCache();

  /// Get cache statistics
  Future<Map<String, dynamic>> getStatistics();
}
