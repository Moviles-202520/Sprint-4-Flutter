import 'package:workmanager/workmanager.dart';
import '../services/upload_queue_local_storage.dart';
import '../services/news_draft_local_storage.dart';
import '../repositories/news_upload_repository.dart';
import '../../domain/models/upload_queue_entry.dart';
import '../../domain/models/news_draft.dart';

/// News Upload Worker
///
/// Background worker that processes the upload queue using WorkManager.
/// Handles pending uploads and retries with exponential backoff.
///
/// Features:
/// - Periodic execution (every 15 minutes by default)
/// - Processes pending + retryable uploads
/// - Exponential backoff (2s, 4s, 8s, 16s, 32s max)
/// - Max 5 retry attempts before giving up
/// - Updates queue status based on upload result
/// - Network constraint (only runs when online)
/// - Battery constraint (respects low battery mode)
/// - Cleanup of old completed entries
///
/// WorkManager Configuration:
/// - Task name: "news_upload_worker"
/// - Frequency: 15 minutes (PeriodicTask)
/// - Constraints: NetworkType.connected, requiresCharging: false
/// - BackoffPolicy: exponential (handled by UploadQueueEntry)
///
/// Queue Processing:
/// 1. Fetch pending entries (status = pending)
/// 2. Fetch retryable entries (status = failed, nextRetryAt <= now)
/// 3. For each entry:
///    - Load draft from local storage
///    - Call NewsUploadRepository.uploadNews()
///    - Update queue status (completed/failed)
///    - Delete draft if upload successful
/// 4. Cleanup old completed entries (>7 days)

class NewsUploadWorker {
  static const String taskName = 'news_upload_worker';
  static const Duration defaultFrequency = Duration(minutes: 15);

  final UploadQueueLocalStorage _queueStorage;
  final NewsDraftLocalStorage _draftStorage;
  final NewsUploadRepository _uploadRepository;

  NewsUploadWorker({
    UploadQueueLocalStorage? queueStorage,
    NewsDraftLocalStorage? draftStorage,
    NewsUploadRepository? uploadRepository,
  })  : _queueStorage = queueStorage ?? UploadQueueLocalStorage(),
        _draftStorage = draftStorage ?? NewsDraftLocalStorage(),
        _uploadRepository = uploadRepository ?? NewsUploadRepository();

  /// Register periodic upload worker
  ///
  /// Call this in main() after Workmanager.initialize()
  static Future<void> register({
    Duration frequency = defaultFrequency,
  }) async {
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: frequency,
      constraints: Constraints(
        networkType: NetworkType.connected, // Only run when online
        requiresCharging: false, // Can run on battery
        requiresBatteryNotLow: true, // Skip if battery low
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: Duration(seconds: 2), // Initial backoff
    );

    print('✅ NewsUploadWorker registered (every ${frequency.inMinutes} min)');
  }

  /// Unregister worker (for testing or user preference)
  static Future<void> unregister() async {
    await Workmanager().cancelByUniqueName(taskName);
    print('🛑 NewsUploadWorker unregistered');
  }

  /// Process upload queue (called by WorkManager)
  ///
  /// This is the main entry point for background execution.
  Future<bool> processQueue() async {
    print('📤 NewsUploadWorker: Starting upload queue processing...');

    try {
      // Initialize storage (no-op if already initialized)
      await _queueStorage.database;
      await _draftStorage.database;

      // Step 1: Fetch pending uploads
      final pendingEntries = await _queueStorage.getPendingEntries();
      print('📋 Found ${pendingEntries.length} pending uploads');

      // Step 2: Fetch retryable uploads (failed + retry time reached)
      final retryableEntries = await _queueStorage.getRetryableEntries();
      print('🔄 Found ${retryableEntries.length} retryable uploads');

      // Combine and deduplicate
      final allEntries = <int, UploadQueueEntry>{};
      for (final entry in [...pendingEntries, ...retryableEntries]) {
        if (entry.queueId != null) {
          allEntries[entry.queueId!] = entry;
        }
      }

      print('📊 Total entries to process: ${allEntries.length}');

      // Step 3: Process each entry
      int successCount = 0;
      int failureCount = 0;

      for (final entry in allEntries.values) {
        try {
          final success = await _processEntry(entry);
          if (success) {
            successCount++;
          } else {
            failureCount++;
          }
        } catch (e) {
          print('❌ Error processing entry ${entry.queueId}: $e');
          failureCount++;
        }
      }

      print('✅ Upload processing complete: $successCount succeeded, $failureCount failed');

      // Step 4: Cleanup old completed entries (>7 days)
      await _queueStorage.deleteCompleted(olderThanDays: 7);

      return true; // WorkManager expects bool return
    } catch (e) {
      print('❌ NewsUploadWorker error: $e');
      return false;
    }
  }

  /// Process single upload queue entry
  ///
  /// Returns true if upload successful, false if failed (will retry).
  Future<bool> _processEntry(UploadQueueEntry entry) async {
    print('📤 Processing upload: ${entry.draftId}');

    NewsDraft? draft;

    try {
      // Step 1: Load draft from local storage
      draft = await _draftStorage.getDraft(entry.draftId);
      if (draft == null) {
        print('⚠️ Draft not found: ${entry.draftId}, marking as failed');
        await _markAsFailed(entry, 'Draft not found in local storage', isFinal: true);
        return false;
      }

      // Step 2: Validate draft is ready to upload
      if (!draft.isReadyToUpload) {
        print('⚠️ Draft not ready: ${entry.draftId}, reason: ${draft.uploadError}');
        await _markAsFailed(entry, draft.uploadError ?? 'Draft not ready', isFinal: true);
        return false;
      }

      // Step 3: Mark as uploading
      final updatedEntry = entry.markAsUploading();
      await _queueStorage.updateEntry(updatedEntry);

      // Step 4: Upload to backend
      print('☁️ Uploading draft ${draft.draftId} with idempotency key ${entry.idempotencyKey}');
      final newsItemId = await _uploadRepository.uploadNews(
        draft,
        idempotencyKey: entry.idempotencyKey,
      );

      print('✅ Upload successful: ${draft.draftId} → $newsItemId');

      // Step 5: Mark as completed
      final completedEntry = updatedEntry.markAsCompleted();
      await _queueStorage.updateEntry(completedEntry);

      // Step 6: Update draft status
      if (draft.draftId != null) {
        await _draftStorage.updateDraftStatus(
          draft.draftId!,
          DraftStatus.uploaded,
        );
      }

      // Step 7: Optional - Delete draft after successful upload
      // await _draftStorage.deleteDraft(draft.draftId!);

      return true;
    } catch (e) {
      print('❌ Upload failed for ${entry.draftId}: $e');

      // Check if max retries exceeded
      if (entry.maxRetriesExceeded) {
        print('🛑 Max retries exceeded for ${entry.draftId}, giving up');
        await _markAsFailed(entry, 'Max retries exceeded: $e', isFinal: true);

        // Update draft status to failed
        if (draft?.draftId != null) {
          await _draftStorage.updateDraftStatus(
            draft!.draftId!,
            DraftStatus.failed,
            uploadError: 'Max retries exceeded: $e',
          );
        }
        return false;
      }

      // Mark as failed for retry
      await _markAsFailed(entry, e.toString());
      return false;
    }
  }

  /// Mark entry as failed with retry scheduling
  Future<void> _markAsFailed(
    UploadQueueEntry entry,
    String error, {
    bool isFinal = false,
  }) async {
    final failedEntry = entry.markAsFailed(error);

    await _queueStorage.updateEntry(failedEntry);

    if (isFinal) {
      print('🛑 Permanently failed: ${entry.draftId}');
    } else {
      final nextRetry = failedEntry.nextRetryAt;
      if (nextRetry != null) {
        final delay = nextRetry.difference(DateTime.now());
        print('🔄 Will retry ${entry.draftId} in ${delay.inSeconds}s');
      }
    }
  }

  /// One-time manual upload trigger (for testing or user action)
  static Future<void> triggerNow() async {
    await Workmanager().registerOneOffTask(
      '${taskName}_manual',
      taskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    print('🚀 Manual upload triggered');
  }
}

/// WorkManager callback dispatcher
///
/// This is the top-level function that WorkManager calls.
/// Must be annotated with @pragma and be a top-level function.
@pragma('vm:entry-point')
void newsUploadWorkerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔧 WorkManager task: $task');

    if (task == NewsUploadWorker.taskName ||
        task == '${NewsUploadWorker.taskName}_manual') {
      final worker = NewsUploadWorker();
      return await worker.processQueue();
    }

    return false; // Unknown task
  });
}

/// Example registration in main.dart:
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   // Initialize Workmanager
///   await Workmanager().initialize(
///     newsUploadWorkerCallbackDispatcher,
///     isInDebugMode: kDebugMode,
///   );
///   
///   // Register upload worker (every 15 minutes)
///   await NewsUploadWorker.register();
///   
///   runApp(MyApp());
/// }
/// ```
///
/// Example manual trigger:
///
/// ```dart
/// // In UI after user taps "Upload Now"
/// await NewsUploadWorker.triggerNow();
/// ScaffoldMessenger.of(context).showSnackBar(
///   SnackBar(content: Text('Upload started in background')),
/// );
/// ```
