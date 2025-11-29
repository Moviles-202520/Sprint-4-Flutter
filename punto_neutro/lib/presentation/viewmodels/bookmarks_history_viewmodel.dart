// =====================================================
// ViewModel: Bookmarks & Reading History
// Purpose: Manage bookmarks and reading history state
// Features: Fetch, delete, clear, with tabs support
// =====================================================

import 'package:flutter/foundation.dart';
import '../../domain/models/bookmark.dart';
import '../../domain/models/reading_history.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../../domain/repositories/reading_history_repository.dart';

class BookmarksHistoryViewModel extends ChangeNotifier {
  final BookmarkRepository _bookmarkRepository;
  final ReadingHistoryRepository _historyRepository;

  BookmarksHistoryViewModel({
    required BookmarkRepository bookmarkRepository,
    required ReadingHistoryRepository historyRepository,
  })  : _bookmarkRepository = bookmarkRepository,
        _historyRepository = historyRepository;

  // State - Bookmarks
  List<Bookmark> _bookmarks = [];
  bool _isLoadingBookmarks = false;
  String? _bookmarksError;
  bool _bookmarksLoaded = false;

  // State - Reading History
  List<ReadingHistory> _history = [];
  bool _isLoadingHistory = false;
  String? _historyError;
  bool _historyLoaded = false;

  // State - Operations
  bool _isDeleting = false;

  // Getters - Bookmarks
  List<Bookmark> get bookmarks => _bookmarks;
  bool get isLoadingBookmarks => _isLoadingBookmarks;
  String? get bookmarksError => _bookmarksError;
  bool get hasBookmarks => _bookmarks.isNotEmpty;
  int get bookmarksCount => _bookmarks.length;

  // Getters - History
  List<ReadingHistory> get history => _history;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get historyError => _historyError;
  bool get hasHistory => _history.isNotEmpty;
  int get historyCount => _history.length;

  // Getters - Operations
  bool get isDeleting => _isDeleting;

  /// Load bookmarks from repository
  Future<void> loadBookmarks({bool forceRefresh = false}) async {
    // Si ya cargamos una vez y no es un refresh explícito, no volvemos a pegarle al repo
    if (_bookmarksLoaded && !forceRefresh) {
      return;
    }

    _isLoadingBookmarks = true;
    _bookmarksError = null;
    notifyListeners();

    try {
      _bookmarks = await _bookmarkRepository.getBookmarks(includeDeleted: false);
      _bookmarksError = null;
      _bookmarksLoaded = true; // 👈 marcamos como cargado
    } catch (e) {
      _bookmarksError = 'Error al cargar marcadores: $e';
      print('Error loading bookmarks: $e');
    } finally {
      _isLoadingBookmarks = false;
      notifyListeners();
    }
  }

  /// Load reading history from repository
  Future<void> loadHistory({int? limit, bool forceRefresh = false}) async {
    // Evitar lecturas repetidas si ya está cargado y no es refresh
    if (_historyLoaded && !forceRefresh) {
      return;
    }

    _isLoadingHistory = true;
    _historyError = null;
    notifyListeners();

    try {
      final results =
      await _historyRepository.getAllHistory(limit: limit ?? 100);

      // Limitar explícitamente la cantidad de elementos en memoria / UI
      const maxEntries = 100;
      if (results.length > maxEntries) {
        _history = results.sublist(results.length - maxEntries);
      } else {
        _history = results;
      }

      _historyError = null;
      _historyLoaded = true;
    } catch (e) {
      _historyError = 'Error al cargar historial: $e';
      print('Error loading history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Refresh bookmarks (pull-to-refresh)
  Future<void> refreshBookmarks() async {
    _bookmarksLoaded = false; // invalidamos caché
    await loadBookmarks(forceRefresh: true);
  }

  /// Refresh history (pull-to-refresh)
  Future<void> refreshHistory() async {
    _historyLoaded = false;
    await loadHistory(limit: 100, forceRefresh: true);
  }

  /// Remove a bookmark by newsItemId
  Future<void> removeBookmark(int newsItemId) async {
    if (_isDeleting) return;

    _isDeleting = true;
    notifyListeners();

    try {
      // Optimistic update
      _bookmarks.removeWhere((b) => b.newsItemId == newsItemId);
      notifyListeners();

      await _bookmarkRepository.removeBookmark(newsItemId);
    } catch (e) {
      print('Error removing bookmark: $e');
      _bookmarksError = 'Error al eliminar marcador';
      // Revert optimistic update
      await loadBookmarks();
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }

  /// Delete a reading history entry
  Future<void> deleteHistoryEntry(int readId) async {
    if (_isDeleting) return;

    _isDeleting = true;
    notifyListeners();

    try {
      // Optimistic update
      _history.removeWhere((h) => h.readId == readId);
      notifyListeners();

      await _historyRepository.deleteHistoryEntry(readId);
    } catch (e) {
      print('Error deleting history entry: $e');
      _historyError = 'Error al eliminar entrada del historial';
      // Revert optimistic update
      await loadHistory(forceRefresh: true);
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }

  /// Clear all reading history
  Future<void> clearAllHistory() async {
    if (_isDeleting || _history.isEmpty) return;

    _isDeleting = true;
    notifyListeners();

    try {
      // Optimistic update
      _history.clear();
      notifyListeners();

      await _historyRepository.clearAllHistory();
    } catch (e) {
      print('Error clearing all history: $e');
      _historyError = 'Error al limpiar historial';
      // Revert optimistic update
      await loadHistory(forceRefresh: true);
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }

  /// Delete old history (older than specified days)
  Future<void> deleteOldHistory(int daysOld) async {
    if (_isDeleting) return;

    _isDeleting = true;
    notifyListeners();

    try {
      final deletedCount = await _historyRepository.deleteOldHistory(daysOld);
      
      // Reload to reflect changes
      await loadHistory(forceRefresh: true);
      
      print('Deleted $deletedCount old history entries');
    } catch (e) {
      print('Error deleting old history: $e');
      _historyError = 'Error al eliminar historial antiguo';
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }

  /// Get total reading time in seconds
  Future<int> getTotalReadingTime() async {
    try {
      return await _historyRepository.getTotalReadingTime();
    } catch (e) {
      print('Error getting total reading time: $e');
      return 0;
    }
  }

  /// Get total articles read count
  Future<int> getArticlesReadCount() async {
    try {
      return await _historyRepository.getArticlesReadCount();
    } catch (e) {
      print('Error getting articles read count: $e');
      return 0;
    }
  }

  /// Check if a news item is bookmarked
  Future<bool> isBookmarked(int newsItemId) async {
    try {
      return await _bookmarkRepository.isBookmarked(newsItemId);
    } catch (e) {
      print('Error checking if bookmarked: $e');
      return false;
    }
  }

  /// Clear errors
  void clearBookmarksError() {
    _bookmarksError = null;
    notifyListeners();
  }

  void clearHistoryError() {
    _historyError = null;
    notifyListeners();
  }

  /// Format duration as human-readable string
  String formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) return 'Menos de 1 min';
    
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    
    if (minutes == 0) {
      return '$remainingSeconds seg';
    } else if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours h';
      }
      return '$hours h $remainingMinutes min';
    }
  }

  /// Format date as relative time
  String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 7) {
      final weeks = difference.inDays ~/ 7;
      return 'Hace $weeks semana${weeks > 1 ? 's' : ''}';
    } else if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Ahora mismo';
    }
  }
}
