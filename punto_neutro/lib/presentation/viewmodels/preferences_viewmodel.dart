// =====================================================
// ViewModel: PreferencesViewModel
// Purpose: Manage user preferences state and actions
// Pattern: ChangeNotifier for reactive UI updates
// =====================================================

import 'package:flutter/foundation.dart';
import '../../domain/repositories/user_preferences_repository.dart';
import '../../domain/models/user_preferences.dart';
import '../../domain/models/favorite_category.dart';
import 'theme_viewmodel.dart';

class PreferencesViewModel extends ChangeNotifier {
  final UserPreferencesRepository _repository;
  final int _userProfileId;
  final ThemeViewModel? _themeViewModel;

  PreferencesViewModel({
    required UserPreferencesRepository repository,
    required int userProfileId,
    ThemeViewModel? themeViewModel,
  })  : _repository = repository,
        _userProfileId = userProfileId,
        _themeViewModel = themeViewModel;

  // State
  UserPreferences? _preferences;
  List<FavoriteCategory> _favoriteCategories = [];
  bool _isLoading = false;
  String? _error;
  bool _isSaving = false;

  // Getters
  UserPreferences? get preferences => _preferences;
  List<FavoriteCategory> get favoriteCategories => _favoriteCategories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSaving => _isSaving;

  // Convenience getters
  bool get darkMode => _preferences?.darkMode ?? false;
  bool get notificationsEnabled => _preferences?.notificationsEnabled ?? true;
  String get language => _preferences?.language ?? 'es';
  Set<int> get favoriteCategoryIds =>
      _favoriteCategories.map((fc) => fc.categoryId).toSet();

  /// Load preferences and favorite categories from server
  Future<void> loadPreferences() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load preferences
      _preferences = await _repository.getPreferences(_userProfileId);

      // If no preferences exist, create defaults
      if (_preferences == null) {
        _preferences = UserPreferences.defaultPreferences(_userProfileId);
        await _repository.upsertPreferences(_preferences!);
      }

      // Sync theme with global ThemeViewModel
      if (_themeViewModel != null) {
        await _themeViewModel.syncWithServerPreferences(_preferences!.darkMode);
      }

      // Load favorite categories
      _favoriteCategories =
          await _repository.getFavoriteCategories(_userProfileId);

      _error = null;
    } catch (e) {
      _error = 'Error loading preferences: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle dark mode
  Future<void> toggleDarkMode() async {
    if (_preferences == null) return;

    _isSaving = true;
    notifyListeners();

    try {
      final newDarkMode = !_preferences!.darkMode;
      
      final updated = _preferences!.copyWith(
        darkMode: newDarkMode,
        updatedAt: DateTime.now(),
      );

      await _repository.upsertPreferences(updated);
      _preferences = updated;
      
      // Update global theme
      if (_themeViewModel != null) {
        await _themeViewModel.setDarkMode(newDarkMode);
      }
      
      _error = null;
    } catch (e) {
      _error = 'Error updating dark mode: $e';
      print(_error);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Toggle notifications enabled
  Future<void> toggleNotifications() async {
    if (_preferences == null) return;

    _isSaving = true;
    notifyListeners();

    try {
      final updated = _preferences!.copyWith(
        notificationsEnabled: !_preferences!.notificationsEnabled,
        updatedAt: DateTime.now(),
      );

      await _repository.upsertPreferences(updated);
      _preferences = updated;
      _error = null;
    } catch (e) {
      _error = 'Error updating notifications: $e';
      print(_error);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Change language
  Future<void> changeLanguage(String newLanguage) async {
    if (_preferences == null || newLanguage == _preferences!.language) return;

    _isSaving = true;
    notifyListeners();

    try {
      final updated = _preferences!.copyWith(
        language: newLanguage,
        updatedAt: DateTime.now(),
      );

      await _repository.upsertPreferences(updated);
      _preferences = updated;
      _error = null;
    } catch (e) {
      _error = 'Error changing language: $e';
      print(_error);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Toggle favorite category
  Future<void> toggleFavoriteCategory(int categoryId, String categoryName) async {
    _isSaving = true;
    notifyListeners();

    try {
      final isFavorite = favoriteCategoryIds.contains(categoryId);

      if (isFavorite) {
        // Remove from favorites
        await _repository.removeFavoriteCategory(_userProfileId, categoryId);
        _favoriteCategories.removeWhere((fc) => fc.categoryId == categoryId);
      } else {
        // Add to favorites
        await _repository.addFavoriteCategory(_userProfileId, categoryId);
        _favoriteCategories.add(FavoriteCategory(
          userProfileId: _userProfileId,
          categoryId: categoryId,
          categoryName: categoryName,
          createdAt: DateTime.now(),
        ));
      }

      _error = null;
    } catch (e) {
      _error = 'Error toggling favorite category: $e';
      print(_error);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Check if category is favorite
  bool isFavorite(int categoryId) {
    return favoriteCategoryIds.contains(categoryId);
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
