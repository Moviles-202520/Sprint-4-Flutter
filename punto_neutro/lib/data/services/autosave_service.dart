import 'dart:async';
import '../../domain/models/news_draft.dart';
import 'news_draft_local_storage.dart';

/// Service that automatically saves drafts periodically.
/// 
/// This service:
/// - Autosaves every X seconds (default 10s)
/// - Only saves if draft has changed since last save
/// - Can be paused/resumed
/// - Notifies listeners on save success/failure
/// 
/// Usage:
/// ```dart
/// final autosave = AutosaveService();
/// autosave.start(draftNotifier); // Saves every 10s
/// // ... user edits draft ...
/// autosave.stop(); // Stop autosaving
/// ```
class AutosaveService {
  final NewsDraftLocalStorage _localStorage;
  final Duration autosaveInterval;

  Timer? _autosaveTimer;
  NewsDraft? _currentDraft;
  DateTime? _lastSaveTime;
  bool _isRunning = false;

  // Callbacks
  Function()? onSaveSuccess;
  Function(String error)? onSaveError;

  AutosaveService({
    NewsDraftLocalStorage? localStorage,
    this.autosaveInterval = const Duration(seconds: 10),
    this.onSaveSuccess,
    this.onSaveError,
  }) : _localStorage = localStorage ?? NewsDraftLocalStorage();

  /// Start autosaving for a draft
  /// This will save every [autosaveInterval] seconds
  void start(NewsDraft draft) {
    if (_isRunning) {
      stop(); // Stop previous autosave if running
    }

    _currentDraft = draft;
    _isRunning = true;

    // Start periodic autosave timer
    _autosaveTimer = Timer.periodic(autosaveInterval, (_) {
      _performAutosave();
    });

    print('AutosaveService: Started for draft ${draft.draftId}');
  }

  /// Stop autosaving (call when user leaves editor)
  void stop() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _isRunning = false;
    _currentDraft = null;

    print('AutosaveService: Stopped');
  }

  /// Manually trigger a save (useful for immediate saves)
  Future<void> saveNow(NewsDraft draft) async {
    _currentDraft = draft;
    await _performAutosave();
  }

  /// Perform the autosave operation
  Future<void> _performAutosave() async {
    if (_currentDraft == null) return;

    try {
      // Skip if draft hasn't changed since last save
      if (_lastSaveTime != null &&
          _currentDraft!.updatedAt.isBefore(_lastSaveTime!)) {
        print('AutosaveService: No changes detected, skipping save');
        return;
      }

      // Skip if draft is empty (no need to save empty drafts)
      if (_currentDraft!.isEmpty) {
        print('AutosaveService: Draft is empty, skipping save');
        return;
      }

      print('AutosaveService: Saving draft...');

      // Update draft status to saved
      final draftToSave = _currentDraft!.copyWith(
        status: DraftStatus.saved,
        updatedAt: DateTime.now(),
      );

      // Save to local storage
      final draftId = await _localStorage.saveDraft(draftToSave);

      // Update current draft with ID if it was a new draft
      if (_currentDraft!.draftId == null) {
        _currentDraft = draftToSave.copyWith(draftId: draftId);
      }

      _lastSaveTime = DateTime.now();

      print('AutosaveService: Draft saved successfully (ID: $draftId)');
      onSaveSuccess?.call();
    } catch (e) {
      print('AutosaveService: Save failed: $e');
      onSaveError?.call(e.toString());
    }
  }

  /// Update the current draft (call this when user makes changes)
  void updateDraft(NewsDraft draft) {
    _currentDraft = draft;
  }

  /// Check if autosave is currently running
  bool get isRunning => _isRunning;

  /// Get time since last save
  Duration? get timeSinceLastSave {
    if (_lastSaveTime == null) return null;
    return DateTime.now().difference(_lastSaveTime!);
  }

  /// Dispose and clean up resources
  void dispose() {
    stop();
  }
}

/// Controller for managing autosave in a UI context
/// This is a convenience wrapper around AutosaveService
class DraftAutosaveController {
  final AutosaveService _autosaveService;
  NewsDraft _draft;

  // Status indicators for UI
  bool isSaving = false;
  DateTime? lastSavedAt;
  String? lastError;

  DraftAutosaveController({
    required NewsDraft initialDraft,
    AutosaveService? autosaveService,
  })  : _draft = initialDraft,
        _autosaveService = autosaveService ??
            AutosaveService(
              onSaveSuccess: null, // Will be set below
              onSaveError: null, // Will be set below
            ) {
    // Set callbacks
    _autosaveService.onSaveSuccess = _onSaveSuccess;
    _autosaveService.onSaveError = _onSaveError;
  }

  /// Start autosaving
  void start() {
    _autosaveService.start(_draft);
  }

  /// Stop autosaving
  void stop() {
    _autosaveService.stop();
  }

  /// Update draft content (call when user makes changes)
  void updateDraft(NewsDraft draft) {
    _draft = draft;
    _autosaveService.updateDraft(draft);
  }

  /// Manually save now
  Future<void> saveNow() async {
    isSaving = true;
    await _autosaveService.saveNow(_draft);
    isSaving = false;
  }

  /// Get current draft
  NewsDraft get draft => _draft;

  /// Get save status for UI
  String get saveStatusText {
    if (isSaving) return 'Saving...';
    if (lastError != null) return 'Save failed';
    if (lastSavedAt != null) {
      final duration = DateTime.now().difference(lastSavedAt!);
      if (duration.inSeconds < 60) {
        return 'Saved ${duration.inSeconds}s ago';
      } else if (duration.inMinutes < 60) {
        return 'Saved ${duration.inMinutes}m ago';
      } else {
        return 'Saved ${duration.inHours}h ago';
      }
    }
    return 'Not saved';
  }

  void _onSaveSuccess() {
    isSaving = false;
    lastSavedAt = DateTime.now();
    lastError = null;
  }

  void _onSaveError(String error) {
    isSaving = false;
    lastError = error;
  }

  /// Dispose controller
  void dispose() {
    _autosaveService.dispose();
  }
}
