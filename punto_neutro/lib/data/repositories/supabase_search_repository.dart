import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/search_repository.dart';
import '../../domain/models/search_query.dart';
import '../../domain/models/search_result.dart';

/// Supabase Search Repository
///
/// Implementation of SearchRepository using Supabase RPC function for
/// Full-Text Search (FTS) with PostgreSQL tsvector.
///
/// Features:
/// - Full-text search using ts_query (supports operators: &, |, !)
/// - Category filtering
/// - Pagination support
/// - Highlights/snippets (ts_headline)
/// - Relevance ranking (ts_rank)
///
/// Backend Requirements:
/// - Table news_items must have search_vector column (tsvector)
/// - GIN index on search_vector for performance
/// - RPC function: search_news(query_text, category_id, limit_count, offset_count)

class SupabaseSearchRepository implements SearchRepository {
  final SupabaseClient _client;

  SupabaseSearchRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<SearchResult> search(SearchQuery query) async {
    if (!query.isValid) {
      throw ArgumentError('Invalid search query: query text is empty');
    }

    try {
      // Call Supabase RPC function for FTS
      final response = await _client.rpc(
        'search_news',
        params: {
          'query_text': query.normalizedQuery,
          'category_id': query.categoryId,
          'limit_count': query.limit,
          'offset_count': query.offset,
        },
      );

      // Parse response
      if (response is List) {
        return _parseSearchResponse(response, query);
      } else {
        throw Exception('Unexpected response format from search_news RPC');
      }
    } catch (e) {
      throw Exception('Search failed: $e');
    }
  }

  /// Parse Supabase RPC response into SearchResult
  SearchResult _parseSearchResponse(
    List<dynamic> response,
    SearchQuery query,
  ) {
    final newsItemIds = <String>[];
    final highlights = <String, String>{};

    for (final item in response) {
      if (item is Map<String, dynamic>) {
        final newsItemId = item['news_item_id'] as String?;
        if (newsItemId != null) {
          newsItemIds.add(newsItemId);

          // Extract highlight/snippet if present
          final highlight = item['snippet'] as String?;
          if (highlight != null && highlight.isNotEmpty) {
            highlights[newsItemId] = highlight;
          }
        }
      }
    }

    return SearchResult(
      newsItemIds: newsItemIds,
      highlights: highlights.isNotEmpty ? highlights : null,
      totalCount: newsItemIds.length, // Note: RPC should return total if needed
      source: SearchResultSource.server,
      query: query.query,
    );
  }

  @override
  Future<bool> isAvailable() async {
    try {
      // Simple health check: try to call a lightweight query
      await _client.rpc('search_news', params: {
        'query_text': 'test',
        'limit_count': 1,
        'offset_count': 0,
      });
      return true;
    } catch (e) {
      return false; // Network error or RPC not available
    }
  }
}

/// Example SQL for the backend RPC function:
/// 
/// CREATE OR REPLACE FUNCTION public.search_news(
///   query_text TEXT,
///   category_id UUID DEFAULT NULL,
///   limit_count INT DEFAULT 20,
///   offset_count INT DEFAULT 0
/// )
/// RETURNS TABLE (
///   news_item_id UUID,
///   title TEXT,
///   snippet TEXT,
///   rank REAL
/// )
/// LANGUAGE plpgsql
/// SECURITY DEFINER
/// AS $$
/// DECLARE
///   ts_query tsquery;
/// BEGIN
///   -- Convert user query to tsquery (handle errors)
///   BEGIN
///     ts_query := plainto_tsquery('spanish', query_text);
///   EXCEPTION WHEN OTHERS THEN
///     RAISE EXCEPTION 'Invalid search query: %', query_text;
///   END;
/// 
///   -- Execute search with optional category filter
///   RETURN QUERY
///   SELECT
///     ni.news_item_id,
///     ni.title,
///     ts_headline(
///       'spanish',
///       ni.content,
///       ts_query,
///       'StartSel=<mark>, StopSel=</mark>, MaxWords=50, MinWords=20'
///     ) AS snippet,
///     ts_rank(ni.search_vector, ts_query) AS rank
///   FROM public.news_items ni
///   WHERE ni.search_vector @@ ts_query
///     AND (category_id IS NULL OR ni.category_id = category_id)
///   ORDER BY rank DESC, ni.published_at DESC
///   LIMIT limit_count
///   OFFSET offset_count;
/// END;
/// $$;
/// 
/// -- Grant execute permission to authenticated users
/// GRANT EXECUTE ON FUNCTION public.search_news TO authenticated;
