// =====================================================
// Supabase-Only Reading History Repository (Web)
// Purpose: Full implementation using ONLY Supabase
// Note: No SQLite, works perfectly in web browsers
// =====================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/reading_history_repository.dart';
import '../../domain/models/reading_history.dart';

class WebReadingHistoryRepository implements ReadingHistoryRepository {
  final SupabaseClient _supabase;

  WebReadingHistoryRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<int> startReadingSession({
    required int newsItemId,
    int? categoryId,
    int? userProfileId,
  }) async {
    try {
      final now = DateTime.now();
      
      final response = await _supabase
          .from('news_read_history')
          .insert({
            'news_item_id': newsItemId,
            'category_id': categoryId,
            'user_profile_id': userProfileId,
            'started_at': now.toIso8601String(),
            'created_at': now.toIso8601String(),
          })
          .select('read_id')
          .single();

      return response['read_id'] as int;
    } catch (e) {
      print('❌ Error starting reading session: $e');
      return 0; // Return dummy ID on error
    }
  }

  @override
  Future<void> endReadingSession(int readId, DateTime endedAt) async {
    if (readId == 0) return; // Skip if dummy ID
    
    try {
      await _supabase
          .from('news_read_history')
          .update({
            'ended_at': endedAt.toIso8601String(),
          })
          .eq('read_id', readId);
    } catch (e) {
      print('❌ Error ending reading session: $e');
    }
  }

  @override
  Future<List<ReadingHistory>> getAllHistory({
    int? limit,
    int? offset,
  }) async {
    try {
      // ⚠️ JOIN con news_items para traer el título
      var query = _supabase
          .from('news_read_history')
          .select('*, news_items!inner(title, image_url)');

      final response = await query
          .order('started_at', ascending: false)
          .limit(limit ?? 50)
          .range(offset ?? 0, (offset ?? 0) + (limit ?? 50) - 1);

      return (response as List).map((json) {
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
          isSynced: true,
          newsTitle: json['news_items']?['title'] as String?, // ⚠️ NUEVO: Título desde JOIN
          newsImageUrl: json['news_items']?['image_url'] as String?, // ⚠️ NUEVO: Imagen
        );
      }).toList();
    } catch (e) {
      print('❌ Error loading history: $e');
      return [];
    }
  }

  @override
  Future<List<ReadingHistory>> getHistoryForNewsItem(int newsItemId) async {
    try {
      final response = await _supabase
          .from('news_read_history')
          .select('*, news_items!inner(title, image_url)')
          .eq('news_item_id', newsItemId)
          .order('started_at', ascending: false);

      return (response as List).map((json) {
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
          isSynced: true,
          newsTitle: json['news_items']?['title'] as String?,
          newsImageUrl: json['news_items']?['image_url'] as String?,
        );
      }).toList();
    } catch (e) {
      print('❌ Error loading history for news: $e');
      return [];
    }
  }

  @override
  Future<List<ReadingHistory>> getHistoryInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _supabase
          .from('news_read_history')
          .select('*, news_items!inner(title, image_url)')
          .gte('started_at', startDate.toIso8601String())
          .lte('started_at', endDate.toIso8601String())
          .order('started_at', ascending: false);

      return (response as List).map((json) {
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
          isSynced: true,
          newsTitle: json['news_items']?['title'] as String?,
          newsImageUrl: json['news_items']?['image_url'] as String?,
        );
      }).toList();
    } catch (e) {
      print('❌ Error loading history in range: $e');
      return [];
    }
  }

  @override
  Future<int> getTotalReadingTime({DateTime? since}) async {
    try {
      var query = _supabase
          .from('news_read_history')
          .select('duration_seconds');

      if (since != null) {
        query = query.gte('started_at', since.toIso8601String());
      }

      final response = await query;
      
      int total = 0;
      for (var row in response) {
        total += (row['duration_seconds'] as int?) ?? 0;
      }
      
      return total;
    } catch (e) {
      print('❌ Error calculating reading time: $e');
      return 0;
    }
  }

  @override
  Future<int> getArticlesReadCount({DateTime? since}) async {
    try {
      var query = _supabase
          .from('news_read_history')
          .select('news_item_id');

      if (since != null) {
        query = query.gte('started_at', since.toIso8601String());
      }

      final response = await query;
      return response.length; // ⚠️ FIX: Contar elementos de la lista
    } catch (e) {
      print('❌ Error counting articles: $e');
      return 0;
    }
  }

  @override
  Future<void> deleteHistoryEntry(int readId) async {
    try {
      await _supabase
          .from('news_read_history')
          .delete()
          .eq('read_id', readId);
    } catch (e) {
      print('❌ Error deleting history entry: $e');
    }
  }

  @override
  Future<void> clearAllHistory() async {
    try {
      // Delete only current user's history
      await _supabase
          .from('news_read_history')
          .delete()
          .neq('read_id', 0); // Delete all
    } catch (e) {
      print('❌ Error clearing history: $e');
    }
  }

  @override
  Future<int> deleteOldHistory(int daysOld) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      
      final response = await _supabase
          .from('news_read_history')
          .delete()
          .lt('started_at', cutoffDate.toIso8601String())
          .select('read_id');

      return (response as List).length; // ⚠️ FIX: Contar elementos eliminados
    } catch (e) {
      print('❌ Error deleting old history: $e');
      return 0;
    }
  }

  @override
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final totalTime = await getTotalReadingTime();
      final articlesCount = await getArticlesReadCount();
      
      return {
        'total_reads': articlesCount,
        'total_time_seconds': totalTime,
        'unique_articles': articlesCount,
        'avg_reading_time': articlesCount > 0 ? totalTime ~/ articlesCount : 0,
      };
    } catch (e) {
      print('❌ Error getting statistics: $e');
      return {
        'total_reads': 0,
        'total_time_seconds': 0,
        'unique_articles': 0,
        'avg_reading_time': 0,
      };
    }
  }

  @override
  Future<int> syncToServer() async {
    // Already using Supabase, so nothing to sync
    return 0;
  }

  @override
  Future<int> getUnsyncedCount() async {
    // Already using Supabase, so nothing pending
    return 0;
  }
}
