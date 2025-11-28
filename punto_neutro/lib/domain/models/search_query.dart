/// Domain Model: SearchQuery
/// 
/// Represents a search request with query text, filters, and pagination.
/// Used to encapsulate all search parameters for cache key generation.
///
/// Features:
/// - Query text normalization (trim, lowercase)
/// - Optional category filter
/// - Pagination support (limit, offset)
/// - Cache key generation (for deduplication)
/// - Validation

class SearchQuery {
  final String query;
  final String? categoryId;
  final int limit;
  final int offset;
  final DateTime createdAt;

  SearchQuery({
    required this.query,
    this.categoryId,
    this.limit = 20,
    this.offset = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Normalized query text (trimmed, lowercase) for cache key
  String get normalizedQuery => query.trim().toLowerCase();

  /// Check if query is valid (not empty after trimming)
  bool get isValid => normalizedQuery.isNotEmpty;

  /// Generate cache key for this query
  /// Format: "q:{normalized_query}|c:{category}|l:{limit}|o:{offset}"
  String get cacheKey {
    final parts = <String>[
      'q:$normalizedQuery',
      if (categoryId != null) 'c:$categoryId',
      'l:$limit',
      'o:$offset',
    ];
    return parts.join('|');
  }

  /// Check if this query matches another (for cache lookup)
  bool matches(SearchQuery other) {
    return normalizedQuery == other.normalizedQuery &&
        categoryId == other.categoryId &&
        limit == other.limit &&
        offset == other.offset;
  }

  /// Copy with new parameters
  SearchQuery copyWith({
    String? query,
    String? categoryId,
    int? limit,
    int? offset,
    DateTime? createdAt,
  }) {
    return SearchQuery(
      query: query ?? this.query,
      categoryId: categoryId ?? this.categoryId,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'category_id': categoryId,
      'limit': limit,
      'offset': offset,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory SearchQuery.fromJson(Map<String, dynamic> json) {
    return SearchQuery(
      query: json['query'] as String,
      categoryId: json['category_id'] as String?,
      limit: json['limit'] as int? ?? 20,
      offset: json['offset'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchQuery && matches(other);
  }

  @override
  int get hashCode => cacheKey.hashCode;

  @override
  String toString() {
    return 'SearchQuery(query: "$query", categoryId: $categoryId, limit: $limit, offset: $offset)';
  }
}
