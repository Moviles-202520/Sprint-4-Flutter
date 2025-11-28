import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/models/reading_history.dart';
import '../../domain/repositories/reading_history_repository.dart';
import '../services/reading_history_local_storage.dart';
import 'supabase_reading_history_repository.dart';

/// Hybrid repository that coordinates local storage + optional server sync.
/// 
/// By default: 100% local-only (privacy-first)
/// With sync enabled: batch uploads to server for analytics
/// 
/// Architecture:
/// - All operations are local-first (instant writes)
/// - Sync is opt-in and happens in background
/// - Local storage is the source of truth
/// - Server is used only for analytics/backup (if enabled)
class HybridReadingHistoryRepository implements ReadingHistoryRepository {
  final ReadingHistoryLocalStorage _localStorage;
  final SupabaseReadingHistoryRepository? _remoteRepository;
  final Connectivity _connectivity;
  final bool syncEnabled;

  HybridReadingHistoryRepository({
    ReadingHistoryLocalStorage? localStorage,
    SupabaseReadingHistoryRepository? remoteRepository,
    Connectivity? connectivity,
    this.syncEnabled = false, // Default: local-only, no sync
  })  : _localStorage = localStorage ?? ReadingHistoryLocalStorage(),
        _remoteRepository = remoteRepository,
        _connectivity = connectivity ?? Connectivity();

  // ============================================================================
  // Local-first operations (always instant, always work offline)
  // ============================================================================

  @override
  Future<int> startReadingSession({
    required int newsItemId,
    int? categoryId,
    int? userProfileId,
  }) async {
    // Always write locally first
    return await _localStorage.startReadingSession(
      newsItemId: newsItemId,
      categoryId: categoryId,
      userProfileId: userProfileId,
    );
  }

  @override
  Future<void> endReadingSession(int readId, DateTime endedAt) async {
    // Always write locally first
    await _localStorage.endReadingSession(readId, endedAt);

    // Optional: trigger background sync if enabled
    // (actual sync happens in background worker, not here)
  }

  @override
  Future<List<ReadingHistory>> getAllHistory({
    int? limit,
    int? offset,
  }) async {
    // Always read from local (instant, offline-capable)
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
    await _localStorage.deleteHistoryEntry(readId);

    // Note: if synced to server, should also delete from server
    // This is a privacy/GDPR requirement
    if (syncEnabled && _remoteRepository != null) {
      try {
        await _remoteRepository!.deleteServerHistory(readIds: [readId]);
      } catch (e) {
        print('Failed to delete from server: $e');
        // Local delete still succeeded, that's what matters for privacy
      }
    }
  }

  @override
  Future<void> clearAllHistory() async {
    await _localStorage.clearAllHistory();

    // Also clear from server if sync was enabled
    if (syncEnabled && _remoteRepository != null) {
      try {
        // Delete all user's history from server
        await _remoteRepository!.deleteServerHistory(
          olderThan: DateTime.now(), // Delete everything older than now = all
        );
      } catch (e) {
        print('Failed to clear server history: $e');
      }
    }
  }

  @override
  Future<int> deleteOldHistory(int daysOld) async {
    final deleted = await _localStorage.deleteOldHistory(daysOld);

    // Also delete old entries from server if sync was enabled
    if (syncEnabled && _remoteRepository != null) {
      try {
        final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
        await _remoteRepository!.deleteServerHistory(olderThan: cutoffDate);
      } catch (e) {
        print('Failed to delete old server history: $e');
      }
    }

    return deleted;
  }

  @override
  Future<Map<String, dynamic>> getStatistics() async {
    // Always use local stats (instant, offline-capable)
    return await _localStorage.getStatistics();
  }

  // ============================================================================
  // Optional sync methods (only used if syncEnabled = true)
  // ============================================================================

  @override
  Future<int> syncToServer() async {
    if (!syncEnabled || _remoteRepository == null) {
      return 0; // Sync disabled
    }

    // Check connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print('No connectivity, skipping sync');
      return 0;
    }

    try {
      // Get unsynced entries (batch size: 100)
      final unsyncedHistory = await _localStorage.getUnsyncedHistory(limit: 100);

      if (unsyncedHistory.isEmpty) {
        return 0; // Nothing to sync
      }

      print('Syncing ${unsyncedHistory.length} reading history entries to server...');

      // Batch upload to server
      final serverIds = await _remoteRepository!.batchUploadHistory(unsyncedHistory);

      // Mark as synced in local storage
      final localIds = unsyncedHistory.map((h) => h.readId!).toList();
      await _localStorage.markAsSynced(localIds);

      print('Successfully synced ${serverIds.length} entries');
      return serverIds.length;
    } catch (e) {
      print('Error syncing to server: $e');

      // Record failed attempt
      final unsyncedHistory = await _localStorage.getUnsyncedHistory(limit: 100);
      final localIds = unsyncedHistory.map((h) => h.readId!).toList();
      await _localStorage.recordSyncAttempt(localIds);

      return 0;
    }
  }

  @override
  Future<int> getUnsyncedCount() async {
    if (!syncEnabled) {
      return 0; // Sync disabled, no concept of "unsynced"
    }

    return await _localStorage.getUnsyncedCount();
  }

  /// Optional: Fetch server history and merge with local (for cross-device sync)
  /// This is a future feature, not required for MVP
  Future<void> syncFromServer() async {
    if (!syncEnabled || _remoteRepository == null) {
      return; // Sync disabled
    }

    try {
      // Get last sync timestamp (not implemented yet)
      // For now, just fetch recent history
      final serverHistory = await _remoteRepository!.fetchServerHistory(
        limit: 100,
        since: DateTime.now().subtract(const Duration(days: 7)),
      );

      // TODO: Merge with local history (avoid duplicates)
      // This requires more complex logic and is not needed for MVP
      print('Fetched ${serverHistory.length} entries from server');
    } catch (e) {
      print('Error fetching from server: $e');
    }
  }
}
