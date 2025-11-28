// =====================================================
// Repository: UserPreferencesRepository
// Purpose: Abstract interface for user preferences operations
// =====================================================

import '../models/user_preferences.dart';
import '../models/favorite_category.dart';

abstract class UserPreferencesRepository {
  /// Get preferences for current user
  Future<UserPreferences?> getPreferences(int userProfileId);

  /// Update or insert preferences
  Future<void> upsertPreferences(UserPreferences preferences);

  /// Get favorite categories for user
  Future<List<FavoriteCategory>> getFavoriteCategories(int userProfileId);

  /// Add category to favorites
  Future<void> addFavoriteCategory(int userProfileId, int categoryId);

  /// Remove category from favorites
  Future<void> removeFavoriteCategory(int userProfileId, int categoryId);

  /// Check if repository is available (online check)
  Future<bool> isAvailable();
}
