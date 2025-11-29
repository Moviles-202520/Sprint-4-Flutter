import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/notification.dart';
import '../../domain/repositories/notification_repository.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  final SupabaseClient _supabase;

  SupabaseNotificationRepository(this._supabase);

  @override
  Future<List<AppNotification>> getNotifications({
    int limit = 20,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    try {
      var query = _supabase
          .from('notifications')
          .select();

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      
      return response
          .map<AppNotification>((json) => AppNotification.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch notifications: $e');
    }
  }

  @override
  Future<AppNotification> markAsRead(int notificationId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .update({
            'is_read': true,
          })
          .eq('notification_id', notificationId)
          .select()
          .single();

      return AppNotification.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  @override
  Future<int> markAllAsRead() async {
    try {
      // RLS ensures this only affects current user's notifications
      final response = await _supabase
          .from('notifications')
          .update({
            'is_read': true,
          })
          .eq('is_read', false)
          .select();

      return response.length;
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('is_read', false);

      return response.length;
    } catch (e) {
      throw Exception('Failed to get unread count: $e');
    }
  }
}
