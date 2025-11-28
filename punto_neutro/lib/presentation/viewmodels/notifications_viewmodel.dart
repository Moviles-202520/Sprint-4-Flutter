// =====================================================
// ViewModel: Notifications
// Purpose: Manage notification state and operations
// Features: Fetch, mark as read, delete, unread badge
// =====================================================

import 'package:flutter/foundation.dart';
import '../../domain/models/notification.dart';
import '../../domain/repositories/notifications_repository.dart';

class NotificationsViewModel extends ChangeNotifier {
  final NotificationsRepository _repository;
  final int _userProfileId;

  NotificationsViewModel({
    required NotificationsRepository repository,
    required int userProfileId,
  })  : _repository = repository,
        _userProfileId = userProfileId;

  // State
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;
  bool _isMarkingRead = false;
  bool _isDeleting = false;

  // Getters
  List<AppNotification> get notifications => _notifications;
  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();
  List<AppNotification> get readNotifications =>
      _notifications.where((n) => n.isRead).toList();
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasNotifications => _notifications.isNotEmpty;
  bool get hasUnreadNotifications => _unreadCount > 0;

  /// Load notifications from repository
  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _notifications = await _repository.getNotifications(_userProfileId);
      _unreadCount = await _repository.getUnreadCount(_userProfileId);
      _error = null;
    } catch (e) {
      _error = 'Error al cargar notificaciones: $e';
      print('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh notifications (pull-to-refresh)
  Future<void> refreshNotifications() async {
    // Don't set loading state for refresh
    try {
      _notifications = await _repository.getNotifications(_userProfileId);
      _unreadCount = await _repository.getUnreadCount(_userProfileId);
      _error = null;
      notifyListeners();
    } catch (e) {
      // Silent fail on refresh
      print('Error refreshing notifications: $e');
    }
  }

  /// Mark a single notification as read
  Future<void> markAsRead(int notificationId) async {
    if (_isMarkingRead) return;

    _isMarkingRead = true;
    notifyListeners();

    try {
      // Optimistic update
      final index = _notifications.indexWhere((n) => n.notificationId == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
        notifyListeners();
      }

      await _repository.markAsRead(notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
      // Revert optimistic update
      await loadNotifications();
    } finally {
      _isMarkingRead = false;
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (_isMarkingRead || _unreadCount == 0) return;

    _isMarkingRead = true;
    notifyListeners();

    try {
      // Optimistic update
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
      notifyListeners();

      await _repository.markAllAsRead(_userProfileId);
    } catch (e) {
      print('Error marking all notifications as read: $e');
      _error = 'Error al marcar todas como leídas';
      // Revert optimistic update
      await loadNotifications();
    } finally {
      _isMarkingRead = false;
      notifyListeners();
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(int notificationId) async {
    if (_isDeleting) return;

    _isDeleting = true;
    notifyListeners();

    try {
      // Optimistic update
      final notification = _notifications.firstWhere((n) => n.notificationId == notificationId);
      _notifications.removeWhere((n) => n.notificationId == notificationId);
      if (!notification.isRead) {
        _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
      }
      notifyListeners();

      await _repository.deleteNotification(notificationId);
    } catch (e) {
      print('Error deleting notification: $e');
      _error = 'Error al eliminar notificación';
      // Revert optimistic update
      await loadNotifications();
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    if (_isDeleting || _notifications.isEmpty) return;

    _isDeleting = true;
    notifyListeners();

    try {
      // Optimistic update
      _notifications.clear();
      _unreadCount = 0;
      notifyListeners();

      await _repository.deleteAllNotifications(_userProfileId);
    } catch (e) {
      print('Error deleting all notifications: $e');
      _error = 'Error al eliminar todas las notificaciones';
      // Revert optimistic update
      await loadNotifications();
    } finally {
      _isDeleting = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get notification by ID
  AppNotification? getNotificationById(int notificationId) {
    try {
      return _notifications.firstWhere((n) => n.notificationId == notificationId);
    } catch (e) {
      return null;
    }
  }

  /// Filter notifications by type
  List<AppNotification> filterByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }
}
