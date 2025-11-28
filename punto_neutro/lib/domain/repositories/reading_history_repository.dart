import '../models/reading_history.dart';

/// Abstract repository for reading history operations.
/// 
/// By default, reading history is 100% local (privacy-first).
/// The default implementation uses [ReadingHistoryLocalStorage] only.
/// 
/// Optional server sync can be enabled by using [HybridReadingHistoryRepository]
/// which coordinates local storage + optional batch upload to server.
abstract class ReadingHistoryRepository {
  /// Start a new reading session (called when user opens article)
  Future<int> startReadingSession({
    required int newsItemId,
    int? categoryId,
    int? userProfileId,
  });

  /// End a reading session (called when user closes article)
  Future<void> endReadingSession(int readId, DateTime endedAt);

  /// Get all reading history (most recent first)
  Future<List<ReadingHistory>> getAllHistory({
    int? limit,
    int? offset,
  });

  /// Get reading history for a specific news item
  Future<List<ReadingHistory>> getHistoryForNewsItem(int newsItemId);

  /// Get reading history within a date range
  Future<List<ReadingHistory>> getHistoryInRange({
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Get total reading time in seconds
  Future<int> getTotalReadingTime({DateTime? since});

  /// Count total unique articles read
  Future<int> getArticlesReadCount({DateTime? since});

  /// Delete a specific history entry
  Future<void> deleteHistoryEntry(int readId);

  /// Clear all reading history
  Future<void> clearAllHistory();

  /// Delete history older than specified days
  Future<int> deleteOldHistory(int daysOld);

  /// Get statistics about reading history
  Future<Map<String, dynamic>> getStatistics();

  // Optional sync methods (only used if server sync is enabled)

  /// Sync unsynced history to server (batch upload)
  /// Returns number of entries successfully synced
  Future<int> syncToServer();

  /// Get count of entries not yet synced to server
  Future<int> getUnsyncedCount();
}
