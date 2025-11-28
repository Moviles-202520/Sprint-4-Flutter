import '../../domain/models/reading_history.dart';
import '../../domain/repositories/reading_history_repository.dart';
import '../services/reading_history_local_storage.dart';

/// Local-only implementation of reading history repository.
/// 
/// This is the DEFAULT implementation - 100% local, privacy-first.
/// No data is sent to server unless you explicitly use the hybrid repository
/// with sync enabled.
/// 
/// Use this implementation for:
/// - Privacy-conscious users
/// - Offline-only apps
/// - Testing without server dependency
class LocalReadingHistoryRepository implements ReadingHistoryRepository {
  final ReadingHistoryLocalStorage _localStorage;

  LocalReadingHistoryRepository({
    ReadingHistoryLocalStorage? localStorage,
  }) : _localStorage = localStorage ?? ReadingHistoryLocalStorage();

  @override
  Future<int> startReadingSession({
    required int newsItemId,
    int? categoryId,
    int? userProfileId,
  }) async {
    return await _localStorage.startReadingSession(
      newsItemId: newsItemId,
      categoryId: categoryId,
      userProfileId: userProfileId,
    );
  }

  @override
  Future<void> endReadingSession(int readId, DateTime endedAt) async {
    return await _localStorage.endReadingSession(readId, endedAt);
  }

  @override
  Future<List<ReadingHistory>> getAllHistory({
    int? limit,
    int? offset,
  }) async {
    return await _localStorage.getAllHistory(
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<ReadingHistory>> getHistoryForNewsItem(int newsItemId) async {
    return await _localStorage.getHistoryForNewsItem(newsItemId);
  }

  @override
  Future<List<ReadingHistory>> getHistoryInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return await _localStorage.getHistoryInRange(
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<int> getTotalReadingTime({DateTime? since}) async {
    return await _localStorage.getTotalReadingTime(since: since);
  }

  @override
  Future<int> getArticlesReadCount({DateTime? since}) async {
    return await _localStorage.getArticlesReadCount(since: since);
  }

  @override
  Future<void> deleteHistoryEntry(int readId) async {
    return await _localStorage.deleteHistoryEntry(readId);
  }

  @override
  Future<void> clearAllHistory() async {
    return await _localStorage.clearAllHistory();
  }

  @override
  Future<int> deleteOldHistory(int daysOld) async {
    return await _localStorage.deleteOldHistory(daysOld);
  }

  @override
  Future<Map<String, dynamic>> getStatistics() async {
    return await _localStorage.getStatistics();
  }

  // Sync methods are no-ops for local-only repository
  @override
  Future<int> syncToServer() async {
    // Local-only: no sync happens
    return 0;
  }

  @override
  Future<int> getUnsyncedCount() async {
    // Local-only: no concept of "unsynced"
    return 0;
  }
}
