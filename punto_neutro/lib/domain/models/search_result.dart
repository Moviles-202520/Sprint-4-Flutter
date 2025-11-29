/// Domain Model: SearchResult
/// 
/// Represents the result of a search query with news item IDs and metadata.
/// Designed for efficient caching (stores IDs only, not full articles).
///
/// Features:
/// - List of news item IDs (lightweight for cache storage)
/// - Optional highlights/snippets for each result
/// - Total count (for pagination)
/// - Cache metadata (cached_at, source)
/// - Serialization for SQLite persistence

class SearchResult {
  /// List of news item IDs matching the query
  final List<String> newsItemIds;

  /// Optional highlights/snippets for each item (key: newsItemId, value: snippet)
  /// Only populated when results come from server (not cached)
  final Map<String, String>? highlights;

  /// Total count of matching items (for pagination UI)
  final int totalCount;

  /// When this result was cached (null if fresh from server)
  final DateTime? cachedAt;

  /// Source of this result: 'cache' or 'server'
  final SearchResultSource source;

  /// Original query that generated this result (for cache lookup)
  final String query;

  SearchResult({
    required this.newsItemIds,
    this.highlights,
    required this.totalCount,
    this.cachedAt,
    required this.source,
    required this.query,
  });

  /// Check if result is empty
  bool get isEmpty => newsItemIds.isEmpty;

  /// Check if result has highlights
  bool get hasHighlights => highlights != null && highlights!.isNotEmpty;

  /// Check if result is from cache
  bool get isCached => source == SearchResultSource.cache;

  /// Get age of cached result (Duration since cached_at)
  Duration? get cacheAge {
    if (cachedAt == null) return null;
    return DateTime.now().difference(cachedAt!);
  }

  /// Copy with new parameters
  SearchResult copyWith({
    List<String>? newsItemIds,
    Map<String, String>? highlights,
    int? totalCount,
    DateTime? cachedAt,
    SearchResultSource? source,
    String? query,
  }) {
    return SearchResult(
      newsItemIds: newsItemIds ?? this.newsItemIds,
      highlights: highlights ?? this.highlights,
      totalCount: totalCount ?? this.totalCount,
      cachedAt: cachedAt ?? this.cachedAt,
      source: source ?? this.source,
      query: query ?? this.query,
    );
  }

  /// Convert to JSON for cache storage
  Map<String, dynamic> toJson() {
    return {
      'news_item_ids': newsItemIds,
      'highlights': highlights,
      'total_count': totalCount,
      'cached_at': cachedAt?.toIso8601String(),
      'source': source.name,
      'query': query,
    };
  }

  /// Create from JSON (cache retrieval)
  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      newsItemIds: (json['news_item_ids'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      highlights: json['highlights'] != null
          ? Map<String, String>.from(json['highlights'] as Map)
          : null,
      totalCount: json['total_count'] as int,
      cachedAt: json['cached_at'] != null
          ? DateTime.parse(json['cached_at'] as String)
          : null,
      source: SearchResultSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => SearchResultSource.server,
      ),
      query: json['query'] as String,
    );
  }

  /// Create from Supabase API response
  factory SearchResult.fromSupabaseResponse(
    Map<String, dynamic> response,
    String query,
  ) {
    final List<dynamic> items = response['data'] as List<dynamic>? ?? [];
    final newsItemIds = items
        .map((item) => item['news_item_id'] as String)
        .toList();

    // Extract highlights if present
    final Map<String, String>? highlights = items.isNotEmpty &&
            items.first.containsKey('highlight')
        ? Map<String, String>.fromEntries(
            items.map((item) => MapEntry(
                  item['news_item_id'] as String,
                  item['highlight'] as String? ?? '',
                )),
          )
        : null;

    return SearchResult(
      newsItemIds: newsItemIds,
      highlights: highlights,
      totalCount: response['count'] as int? ?? newsItemIds.length,
      source: SearchResultSource.server,
      query: query,
    );
  }

  @override
  String toString() {
    return 'SearchResult(count: ${newsItemIds.length}/$totalCount, source: ${source.name}, cached: ${cachedAt != null})';
  }
}

/// Source of search result
enum SearchResultSource {
  /// Result from local cache
  cache,

  /// Fresh result from server
  server,
}
