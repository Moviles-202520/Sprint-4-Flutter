import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/reading_history.dart';

/// Optional Supabase repository for reading history batch uploads.
/// 
/// This is ONLY used when server sync is explicitly enabled.
/// The default app behavior is 100% local (no server sync).
/// 
/// Use cases:
/// - Analytics dashboard (aggregate reading patterns)
/// - Cross-device sync (optional future feature)
/// - Backup/restore functionality
class SupabaseReadingHistoryRepository {
  final SupabaseClient _supabase;

  SupabaseReadingHistoryRepository({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  /// Batch upload reading history entries to server
  /// This is used for analytics purposes only
  Future<List<int>> batchUploadHistory(
      List<ReadingHistory> historyList) async {
    if (historyList.isEmpty) return [];

    try {
      // Convert to server JSON format
      final data = historyList.map((h) => h.toServerJson()).toList();

      // Batch insert to news_read_history table
      final response = await _supabase
          .from('news_read_history')
          .insert(data)
          .select('read_id');

      // Return the server-assigned IDs
      return (response as List)
          .map((item) => item['read_id'] as int)
          .toList();
    } catch (e) {
      print('Error batch uploading history: $e');
      rethrow;
    }
  }

  /// Upload a single reading history entry
  Future<int?> uploadHistoryEntry(ReadingHistory history) async {
    try {
      final response = await _supabase
          .from('news_read_history')
          .insert(history.toServerJson())
          .select('read_id')
          .single();

      return response['read_id'] as int?;
    } catch (e) {
      print('Error uploading history entry: $e');
      rethrow;
    }
  }

  /// Get reading history from server (for cross-device sync - future feature)
  Future<List<ReadingHistory>> fetchServerHistory({
    int? limit,
    DateTime? since,
  }) async {
    try {
      var query = _supabase.from('news_read_history').select();

      if (since != null) {
        query = query.gte('created_at', since.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit ?? 100);

      return (response as List).map((json) {
        // Convert server JSON to local format
        return ReadingHistory(
          readId: json['read_id'] as int?,
          userProfileId: json['user_profile_id'] as int?,
          newsItemId: json['news_item_id'] as int,
          categoryId: json['category_id'] as int?,
          startedAt: DateTime.parse(json['started_at'] as String),
          endedAt: json['ended_at'] != null
              ? DateTime.parse(json['ended_at'] as String)
              : null,
          durationSeconds: json['duration_seconds'] as int?,
          createdAt: DateTime.parse(json['created_at'] as String),
          isSynced: true, // Server data is always "synced"
        );
      }).toList();
    } catch (e) {
      print('Error fetching server history: $e');
      rethrow;
    }
  }

  /// Delete reading history from server (for privacy/GDPR compliance)
  Future<void> deleteServerHistory({
    List<int>? readIds,
    DateTime? olderThan,
  }) async {
    try {
      if (readIds != null && readIds.isNotEmpty) {
        await _supabase
            .from('news_read_history')
            .delete()
            .inFilter('read_id', readIds);
      } else if (olderThan != null) {
        await _supabase
            .from('news_read_history')
            .delete()
            .lt('created_at', olderThan.toIso8601String());
      }
    } catch (e) {
      print('Error deleting server history: $e');
      rethrow;
    }
  }

  /// Get server-side reading statistics (for analytics dashboard)
  Future<Map<String, dynamic>> getServerStatistics() async {
    try {
      // Total reading time
      final timeResult = await _supabase.rpc('get_total_reading_time');

      // Total articles read
      final articlesResult = await _supabase.rpc('get_articles_read_count');

      return {
        'total_reading_time_seconds': timeResult ?? 0,
        'unique_articles_read': articlesResult ?? 0,
      };
    } catch (e) {
      print('Error getting server statistics: $e');
      // Return empty stats if RPC functions don't exist yet
      return {
        'total_reading_time_seconds': 0,
        'unique_articles_read': 0,
      };
    }
  }
}
