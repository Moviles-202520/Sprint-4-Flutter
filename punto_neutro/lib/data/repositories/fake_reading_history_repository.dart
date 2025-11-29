// =====================================================
// Fake Reading History Repository (Web Fallback)
// Purpose: Provide empty history for web platform
// Note: SQLite doesn't work in web, so we return empty data
// =====================================================

import '../../domain/repositories/reading_history_repository.dart';
import '../../domain/models/reading_history.dart';

class FakeReadingHistoryRepository implements ReadingHistoryRepository {
  @override
  Future<int> startReadingSession({
    required int newsItemId,
    int? categoryId,
    int? userProfileId,
  }) async {
    // Retorna ID falso
    return 0;
  }

  @override
  Future<void> endReadingSession(int readId, DateTime endedAt) async {
    // No-op
  }

  @override
  Future<List<ReadingHistory>> getAllHistory({
    int? limit,
    int? offset,
  }) async {
    // Retorna lista vacía
    return [];
  }

  @override
  Future<List<ReadingHistory>> getHistoryForNewsItem(int newsItemId) async {
    return [];
  }

  @override
  Future<List<ReadingHistory>> getHistoryInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return [];
  }

  @override
  Future<int> getTotalReadingTime({DateTime? since}) async {
    // Retorna 0 segundos
    return 0;
  }

  @override
  Future<int> getArticlesReadCount({DateTime? since}) async {
    // Retorna 0 artículos
    return 0;
  }

  @override
  Future<void> deleteHistoryEntry(int readId) async {
    // No-op
  }

  @override
  Future<void> clearAllHistory() async {
    // No-op
  }

  @override
  Future<int> deleteOldHistory(int daysOld) async {
    return 0;
  }

  @override
  Future<Map<String, dynamic>> getStatistics() async {
    return {
      'total_reads': 0,
      'total_time_seconds': 0,
      'unique_articles': 0,
      'avg_reading_time': 0,
    };
  }

  @override
  Future<int> syncToServer() async {
    return 0;
  }

  @override
  Future<int> getUnsyncedCount() async {
    return 0;
  }
}
