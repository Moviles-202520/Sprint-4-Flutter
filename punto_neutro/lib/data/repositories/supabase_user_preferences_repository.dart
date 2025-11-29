// =====================================================
// Supabase Implementation: UserPreferencesRepository
// Purpose: Interact with user_preferences and user_favorite_categories tables
// Dependencies: supabase_flutter
// =====================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/user_preferences_repository.dart';
import '../../domain/models/user_preferences.dart';
import '../../domain/models/favorite_category.dart';

class SupabaseUserPreferencesRepository implements UserPreferencesRepository {
  final SupabaseClient _supabase;

  SupabaseUserPreferencesRepository(this._supabase);

  @override
  Future<UserPreferences?> getPreferences(int userProfileId) async {
    try {
      final response = await _supabase
          .from('user_preferences')
          .select()
          .eq('user_profile_id', userProfileId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return UserPreferences.fromJson(response);
    } catch (e) {
      print('Error getting preferences: $e');
      return null;
    }
  }

  @override
  Future<void> upsertPreferences(UserPreferences preferences) async {
    try {
      await _supabase.from('user_preferences').upsert(
        preferences.toJson(),
        onConflict: 'user_profile_id',
      );
    } catch (e) {
      print('Error upserting preferences: $e');
      rethrow;
    }
  }

  @override
  Future<List<FavoriteCategory>> getFavoriteCategories(
      int userProfileId) async {
    try {
      final response = await _supabase
          .from('user_favorite_categories')
          .select('*, categories(name)')
          .eq('user_profile_id', userProfileId)
          .order('created_at', ascending: false);

      return (response as List).map((json) {
        // Flatten the JOIN result
        final categoryName = json['categories']?['name'] as String?;
        return FavoriteCategory.fromJson({
          ...json,
          'category_name': categoryName ?? 'Unknown',
        });
      }).toList();
    } catch (e) {
      print('Error getting favorite categories: $e');
      return [];
    }
  }

  @override
  Future<void> addFavoriteCategory(int userProfileId, int categoryId) async {
    try {
      await _supabase.from('user_favorite_categories').insert({
        'user_profile_id': userProfileId,
        'category_id': categoryId,
      });
    } catch (e) {
      print('Error adding favorite category: $e');
      rethrow;
    }
  }

  @override
  Future<void> removeFavoriteCategory(int userProfileId, int categoryId) async {
    try {
      await _supabase
          .from('user_favorite_categories')
          .delete()
          .eq('user_profile_id', userProfileId)
          .eq('category_id', categoryId);
    } catch (e) {
      print('Error removing favorite category: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      // Simple health check: try to query user_preferences
      await _supabase.from('user_preferences').select('user_profile_id').limit(1);
      return true;
    } catch (e) {
      print('Supabase preferences repo unavailable: $e');
      return false;
    }
  }
}
