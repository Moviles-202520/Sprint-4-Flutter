import '../models/notification.dart';

/// Abstract repository for managing user notifications
/// Provides paginated listing and mark-as-read functionality
abstract class NotificationRepository {
  /// Fetch paginated notifications for the current user
  /// Returns list of notifications ordered by created_at DESC
  /// [limit] - max notifications to return (default 20)
  /// [offset] - number of notifications to skip (for pagination)
  /// [unreadOnly] - if true, only return unread notifications
  Future<List<AppNotification>> getNotifications({
    int limit = 20,
    int offset = 0,
    bool unreadOnly = false,
  });

  /// Mark a single notification as read
  /// [notificationId] - the notification to mark as read
  /// Returns the updated notification
  Future<AppNotification> markAsRead(int notificationId);

  /// Mark all notifications as read for the current user
  /// Returns the number of notifications updated
  Future<int> markAllAsRead();

  /// Get count of unread notifications for badge display
  Future<int> getUnreadCount();
}
