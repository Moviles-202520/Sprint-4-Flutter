// =====================================================
// Supabase Implementation: Notifications Repository
// Purpose: Fetch and manage notifications from Supabase
// Features: JOINs for actor/news data, pagination support
// =====================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/notification.dart';
import '../../domain/repositories/notifications_repository.dart';

class SupabaseNotificationsRepository implements NotificationsRepository {
  final SupabaseClient _client;

  SupabaseNotificationsRepository(this._client);

  @override
  Future<List<AppNotification>> getNotifications(int userProfileId) async {
    try {
      // Query with JOINs to get actor and news item details
      final response = await _client
          .from('notifications')
          .select('''
            *,
            actor:user_profiles!actor_user_profile_id(user_auth_email),
            news_items(title)
          ''')
          .eq('user_profile_id', userProfileId)
          .order('created_at', ascending: false)
          .limit(100); // Limit for performance

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => AppNotification.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching notifications: $e');
      rethrow;
    }
  }

  @override
  Future<int> getUnreadCount(int userProfileId) async {
    try {
      final response = await _client
          .from('notifications')
          .select('notification_id')
          .eq('user_profile_id', userProfileId)
          .eq('is_read', false);

      final List<dynamic> data = response as List<dynamic>;
      return data.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0; // Safe fallback
    }
  }

  @override
  Future<void> markAsRead(int notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('notification_id', notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
      rethrow;
    }
  }

  @override
  Future<void> markAllAsRead(int userProfileId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_profile_id', userProfileId)
          .eq('is_read', false);
    } catch (e) {
      print('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteNotification(int notificationId) async {
    try {
      await _client
          .from('notifications')
          .delete()
          .eq('notification_id', notificationId);
    } catch (e) {
      print('Error deleting notification: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteAllNotifications(int userProfileId) async {
    try {
      await _client
          .from('notifications')
          .delete()
          .eq('user_profile_id', userProfileId);
    } catch (e) {
      print('Error deleting all notifications: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      await _client.from('notifications').select('notification_id').limit(1);
      return true;
    } catch (e) {
      print('Notifications repository not available: $e');
      return false;
    }
  }
}
