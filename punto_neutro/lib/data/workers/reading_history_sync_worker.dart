import 'package:workmanager/workmanager.dart';
import '../repositories/hybrid_reading_history_repository.dart';
import '../services/reading_history_local_storage.dart';
import '../repositories/supabase_reading_history_repository.dart';

/// Optional background worker for syncing reading history to server.
/// 
/// IMPORTANT: This worker is DISABLED by default.
/// Sync only happens if explicitly enabled in settings.
/// 
/// When enabled, this worker:
/// - Runs periodically (e.g., daily) to batch upload history
/// - Reduces server load by batching uploads
/// - Respects privacy settings (no sync if disabled)
/// - Cleans up old local history entries (optional)
/// 
/// Privacy-first approach:
/// - Default: local-only, no server sync
/// - Opt-in: user must explicitly enable sync in settings
/// - Transparent: user sees sync status and can disable anytime
class ReadingHistorySyncWorker {
  static const String _taskName = 'reading_history_sync';
  static const String _uniqueName = 'reading_history_sync_worker';

  /// Initialize the worker (must be called once at app startup)
  static Future<void> initialize() async {
    await Workmanager().initialize(
      readingHistoryCallbackDispatcher,
      isInDebugMode: false,
    );
  }

  /// Register periodic sync task (only if sync is enabled)
  static Future<void> registerPeriodicSync({
    bool syncEnabled = false,
  }) async {
    if (!syncEnabled) {
      // Cancel any existing sync tasks
      await Workmanager().cancelByUniqueName(_uniqueName);
      return;
    }

    // Run daily at most (batch upload)
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      _taskName,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  /// Manual sync trigger (for testing or user-initiated sync)
  static Future<void> syncNow() async {
    await Workmanager().registerOneOffTask(
      '${_uniqueName}_manual',
      _taskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  /// Cancel all sync tasks (when user disables sync)
  static Future<void> cancelSync() async {
    await Workmanager().cancelByUniqueName(_uniqueName);
  }
}

/// Top-level callback dispatcher (runs in background isolate)
@pragma('vm:entry-point')
void readingHistoryCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      print('ReadingHistorySyncWorker: Starting sync task...');

      // Create repository instances
      final localStorage = ReadingHistoryLocalStorage();
      final remoteRepository = SupabaseReadingHistoryRepository();
      final hybridRepository = HybridReadingHistoryRepository(
        localStorage: localStorage,
        remoteRepository: remoteRepository,
        syncEnabled: true, // Sync is enabled in this worker
      );

      // Sync unsynced history to server
      final syncedCount = await hybridRepository.syncToServer();
      print('ReadingHistorySyncWorker: Synced $syncedCount entries');

      // Optional: Clean up old local history (>90 days)
      final deletedCount = await localStorage.deleteOldHistory(90);
      print('ReadingHistorySyncWorker: Cleaned up $deletedCount old entries');

      return Future.value(true);
    } catch (e) {
      print('ReadingHistorySyncWorker: Error during sync: $e');
      return Future.value(false);
    }
  });
}
