// =====================================================
// Repository Interface: Notifications
// Purpose: Abstract interface for notification operations
// Operations: Fetch, mark as read, delete
// =====================================================

import '../models/notification.dart';

abstract class NotificationsRepository {
  /// Get all notifications for a user (newest first)
  Future<List<AppNotification>> getNotifications(int userProfileId);

  /// Get unread notifications count
  Future<int> getUnreadCount(int userProfileId);

  /// Mark a single notification as read
  Future<void> markAsRead(int notificationId);

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(int userProfileId);

  /// Delete a notification
  Future<void> deleteNotification(int notificationId);

  /// Delete all notifications for a user
  Future<void> deleteAllNotifications(int userProfileId);

  /// Check if repository is available
  Future<bool> isAvailable();
}
