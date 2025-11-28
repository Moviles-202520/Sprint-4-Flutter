// =====================================================
// Screen: Notifications
// Purpose: Display and manage user notifications
// Features: Mark as read, delete, filter by unread/read
// =====================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/notifications_viewmodel.dart';
import '../../domain/models/notification.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    // Load notifications on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsViewModel>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          // Mark all as read button
          Consumer<NotificationsViewModel>(
            builder: (context, viewModel, _) {
              if (!viewModel.hasUnreadNotifications) return const SizedBox.shrink();
              
              return IconButton(
                icon: const Icon(Icons.done_all),
                tooltip: 'Marcar todas como leídas',
                onPressed: () => _showMarkAllAsReadDialog(context, viewModel),
              );
            },
          ),
          // Delete all button
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete_all') {
                _showDeleteAllDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Eliminar todas'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<NotificationsViewModel>(
        builder: (context, viewModel, _) {
          // Loading state
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (viewModel.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(viewModel.error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => viewModel.loadNotifications(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          // Empty state
          if (!viewModel.hasNotifications) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, 
                    size: 64, 
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes notificaciones',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Get notifications to display (filtered or all)
          final notifications = _showUnreadOnly
              ? viewModel.unreadNotifications
              : viewModel.notifications;

          return Column(
            children: [
              // Filter toggle
              if (viewModel.hasUnreadNotifications)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      const Text('Mostrar solo no leídas'),
                      const Spacer(),
                      Switch(
                        value: _showUnreadOnly,
                        onChanged: (value) {
                          setState(() => _showUnreadOnly = value);
                        },
                      ),
                    ],
                  ),
                ),

              // Notifications list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => viewModel.refreshNotifications(),
                  child: notifications.isEmpty
                      ? _buildEmptyFilteredState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: notifications.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return _buildNotificationTile(context, viewModel, notification);
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyFilteredState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay notificaciones sin leer',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() => _showUnreadOnly = false);
            },
            child: const Text('Ver todas'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    NotificationsViewModel viewModel,
    AppNotification notification,
  ) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    return Dismissible(
      key: Key('notification_${notification.notificationId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _showDeleteConfirmDialog(context),
      onDismissed: (_) {
        viewModel.deleteNotification(notification.notificationId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificación eliminada')),
        );
      },
      child: ListTile(
        leading: _buildNotificationIcon(notification.type, isUnread),
        title: Text(
          notification.getMessage(),
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.getPreview() != null) ...[
              const SizedBox(height: 4),
              Text(
                notification.getPreview()!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              notification.getTimeAgo(),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: isUnread
            ? Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        tileColor: isUnread ? theme.colorScheme.primaryContainer.withOpacity(0.1) : null,
        onTap: () {
          // Mark as read when tapped
          if (isUnread) {
            viewModel.markAsRead(notification.notificationId);
          }
          // TODO: Navigate to related content (news item, comment, etc.)
          _handleNotificationTap(context, notification);
        },
      ),
    );
  }

  Widget _buildNotificationIcon(NotificationType type, bool isUnread) {
    IconData iconData;
    Color color;

    switch (type) {
      case NotificationType.ratingReceived:
        iconData = Icons.star;
        color = Colors.amber;
        break;
      case NotificationType.commentReceived:
        iconData = Icons.comment;
        color = Colors.blue;
        break;
      case NotificationType.articlePublished:
        iconData = Icons.check_circle;
        color = Colors.green;
        break;
      case NotificationType.system:
        iconData = Icons.info;
        color = Colors.grey;
        break;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: color,
        size: 24,
      ),
    );
  }

  void _handleNotificationTap(BuildContext context, AppNotification notification) {
    // TODO: Implement navigation based on notification type
    // - ratingReceived: Navigate to news item with ratings
    // - commentReceived: Navigate to news item with comments
    // - articlePublished: Navigate to published news item
    // - system: Show message or navigate to settings
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notificación: ${notification.type.toValue()}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar notificación'),
        content: const Text('¿Estás seguro de que quieres eliminar esta notificación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMarkAllAsReadDialog(
    BuildContext context,
    NotificationsViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar todas como leídas'),
        content: Text(
          '¿Marcar ${viewModel.unreadCount} notificación(es) como leídas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Marcar todas'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await viewModel.markAllAsRead();
    }
  }

  Future<void> _showDeleteAllDialog(BuildContext context) async {
    final viewModel = context.read<NotificationsViewModel>();
    
    if (!viewModel.hasNotifications) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar todas'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar todas las notificaciones? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar todas'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await viewModel.deleteAllNotifications();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todas las notificaciones eliminadas')),
        );
      }
    }
  }
}
