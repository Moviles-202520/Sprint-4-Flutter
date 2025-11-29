import '../../domain/models/search_query.dart';
import '../../domain/models/search_result.dart';
import 'local_search_cache_repository.dart';
import 'supabase_search_repository.dart';

/// Hybrid Search Service
///
/// Orchestrates search across cache and server with intelligent fallback:
/// 1. Check local cache first (instant response)
/// 2. If cache miss, query server
/// 3. Cache server results for future queries
/// 4. If offline, return cache-only or error
///
/// Features:
/// - Cache-first strategy (instant response on hit)
/// - Automatic cache population (server results cached)
/// - Offline fallback (graceful degradation)
/// - Configurable TTL per query
/// - Statistics tracking (hit rate, miss rate)
///
/// Usage:
///   final service = HybridSearchService();
///   
///   // Search (automatic cache check + server fallback)
///   final result = await service.search(query);
///   
///   // Force server query (refresh cache)
///   final fresh = await service.searchServer(query, updateCache: true);

class HybridSearchService {
  final LocalSearchCacheRepository _cacheRepo;
  final SupabaseSearchRepository _serverRepo;

  // Statistics
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _serverQueries = 0;
  int _serverErrors = 0;

  HybridSearchService({
    LocalSearchCacheRepository? cacheRepository,
    SupabaseSearchRepository? serverRepository,
  })  : _cacheRepo = cacheRepository ?? LocalSearchCacheRepository(),
        _serverRepo = serverRepository ?? SupabaseSearchRepository();

  /// Search with cache-first strategy
  /// 
  /// Flow:
  /// 1. Check cache → if hit, return immediately
  /// 2. Query server → if success, cache and return
  /// 3. If offline → throw exception with cache suggestion
  Future<SearchResult> search(
    SearchQuery query, {
    Duration? cacheTTL,
    bool forceRefresh = false,
  }) async {
    // Step 1: Check cache (unless force refresh)
    if (!forceRefresh) {
      final cached = await _cacheRepo.getCachedResult(query);
      if (cached != null) {
        _cacheHits++;
        return cached;
      }
      _cacheMisses++;
    }

    // Step 2: Query server
    try {
      final serverResult = await _serverRepo.search(query);
      _serverQueries++;

      // Step 3: Cache server result
      await _cacheRepo.cacheResult(query, serverResult, ttl: cacheTTL);

      return serverResult;
    } catch (e) {
      _serverErrors++;

      // Step 4: Offline fallback - check if we have stale cache
      final cached = await _cacheRepo.getCachedResult(query);
      if (cached != null) {
        // Return stale cache with warning
        return cached.copyWith(source: SearchResultSource.cache);
      }

      throw Exception('Search failed: $e. No cached results available.');
    }
  }

  /// Force server query (bypass cache check)
  Future<SearchResult> searchServer(
    SearchQuery query, {
    bool updateCache = true,
    Duration? cacheTTL,
  }) async {
    try {
      final result = await _serverRepo.search(query);
      _serverQueries++;

      if (updateCache) {
        await _cacheRepo.cacheResult(query, result, ttl: cacheTTL);
      }

      return result;
    } catch (e) {
      _serverErrors++;
      throw Exception('Server search failed: $e');
    }
  }

  /// Search cache only (offline-capable)
  Future<SearchResult?> searchCacheOnly(SearchQuery query) async {
    final cached = await _cacheRepo.getCachedResult(query);
    if (cached != null) {
      _cacheHits++;
    } else {
      _cacheMisses++;
    }
    return cached;
  }

  /// Check if server search is available
  Future<bool> isServerAvailable() async {
    return await _serverRepo.isAvailable();
  }

  /// Clear all cached search results
  Future<void> clearCache() async {
    await _cacheRepo.clearCache();
  }

  /// Delete expired cache entries (maintenance)
  Future<int> cleanupExpiredCache() async {
    return await _cacheRepo.deleteExpiredEntries();
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStatistics() async {
    final storageStats = await _cacheRepo.getStatistics();
    
    final totalQueries = _cacheHits + _cacheMisses;
    final hitRate = totalQueries > 0 ? (_cacheHits / totalQueries) * 100 : 0.0;

    return {
      ...storageStats,
      'cache_hits': _cacheHits,
      'cache_misses': _cacheMisses,
      'cache_hit_rate': hitRate,
      'server_queries': _serverQueries,
      'server_errors': _serverErrors,
      'total_queries': totalQueries,
    };
  }

  /// Reset statistics counters
  void resetStatistics() {
    _cacheHits = 0;
    _cacheMisses = 0;
    _serverQueries = 0;
    _serverErrors = 0;
  }
}

/// Example usage in UI layer:
/// 
/// ```dart
/// class SearchScreen extends StatefulWidget {
///   @override
///   State<SearchScreen> createState() => _SearchScreenState();
/// }
/// 
/// class _SearchScreenState extends State<SearchScreen> {
///   final _searchService = HybridSearchService();
///   SearchResult? _result;
///   bool _isLoading = false;
///   String? _error;
/// 
///   Future<void> _performSearch(String queryText) async {
///     setState(() {
///       _isLoading = true;
///       _error = null;
///     });
/// 
///     try {
///       final query = SearchQuery(query: queryText);
///       final result = await _searchService.search(query);
///       
///       setState(() {
///         _result = result;
///         _isLoading = false;
///       });
/// 
///       // Show cache indicator
///       if (result.isCached) {
///         ScaffoldMessenger.of(context).showSnackBar(
///           SnackBar(content: Text('Showing cached results')),
///         );
///       }
///     } catch (e) {
///       setState(() {
///         _error = e.toString();
///         _isLoading = false;
///       });
///     }
///   }
/// 
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(title: Text('Search')),
///       body: Column(
///         children: [
///           TextField(
///             onSubmitted: _performSearch,
///             decoration: InputDecoration(hintText: 'Search news...'),
///           ),
///           if (_isLoading) CircularProgressIndicator(),
///           if (_error != null) Text('Error: $_error'),
///           if (_result != null) Expanded(
///             child: ListView.builder(
///               itemCount: _result!.newsItemIds.length,
///               itemBuilder: (context, index) {
///                 final newsId = _result!.newsItemIds[index];
///                 final highlight = _result!.highlights?[newsId];
///                 return ListTile(
///                   title: Text(newsId),
///                   subtitle: highlight != null ? Text(highlight) : null,
///                 );
///               },
///             ),
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// ```
