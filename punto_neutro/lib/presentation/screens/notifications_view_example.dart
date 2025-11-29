import 'package:flutter/material.dart';
import '../../data/repositories/hybrid_notification_repository.dart';
import '../../data/services/notification_sync_service.dart';
import '../../domain/models/notification.dart';

/// ✅ EJEMPLO DE VISTA DE NOTIFICACIONES CON SINCRONIZACIÓN
/// Este archivo es solo referencia - NO reemplaza ninguna vista existente
/// Para integrar: copiar las partes relevantes a tu NotificationsScreen actual

class NotificationsViewExample extends StatefulWidget {
  const NotificationsViewExample({Key? key}) : super(key: key);

  @override
  State<NotificationsViewExample> createState() => _NotificationsViewExampleState();
}

class _NotificationsViewExampleState extends State<NotificationsViewExample> {
  final _repository = HybridNotificationRepository();
  final _syncService = NotificationSyncService();
  
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _loadUnreadCount();
    
    // Iniciar monitoreo de conectividad (sincroniza automáticamente)
    _syncService.startConnectivityMonitoring();
  }

  @override
  void dispose() {
    _syncService.stopConnectivityMonitoring();
    super.dispose();
  }

  /// ✅ CARGAR NOTIFICACIONES (lee local primero, sync en background)
  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    
    try {
      final notifications = await _repository.getNotifications(
        limit: 20,
        offset: 0,
        unreadOnly: false,
      );
      
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando notificaciones: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando notificaciones: $e')),
        );
      }
    }
  }

  /// ✅ CARGAR CONTADOR DE NO LEÍDAS
  Future<void> _loadUnreadCount() async {
    try {
      final count = await _repository.getUnreadCount();
      setState(() => _unreadCount = count);
    } catch (e) {
      print('Error cargando contador: $e');
    }
  }

  /// ✅ MARCAR COMO LEÍDA (offline-first)
  Future<void> _markAsRead(int notificationId) async {
    try {
      await _repository.markAsRead(notificationId);
      
      // Actualizar UI localmente (optimistic update)
      setState(() {
        final index = _notifications.indexWhere((n) => n.notificationId == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(
            isRead: true,
          );
        }
        _unreadCount = (_unreadCount - 1).clamp(0, 9999);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notificación marcada como leída'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error marcando como leída: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// ✅ MARCAR TODAS COMO LEÍDAS
  Future<void> _markAllAsRead() async {
    try {
      final count = await _repository.markAllAsRead();
      
      setState(() {
        for (int i = 0; i < _notifications.length; i++) {
          _notifications[i] = _notifications[i].copyWith(
            isRead: true,
          );
        }
        _unreadCount = 0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count notificaciones marcadas como leídas')),
        );
      }
    } catch (e) {
      print('Error marcando todas como leídas: $e');
    }
  }

  /// ✅ PULL-TO-REFRESH (fuerza sincronización)
  Future<void> _handleRefresh() async {
    try {
      // Forzar sincronización con servidor
      await _syncService.forceSyncNow();
      
      // Recargar notificaciones después de sincronizar
      await _loadNotifications();
      await _loadUnreadCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sincronización completada'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error en refresh: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('No hay conexión')
                  ? '📴 Sin conexión a internet'
                  : 'Error en sincronización',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notificaciones'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Botón "Marcar todas como leídas"
          if (_unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Marcar todas como leídas',
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No hay notificaciones',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      
                      return Dismissible(
                        key: Key('notification_${notification.notificationId}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.green,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.check, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          _markAsRead(notification.notificationId);
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: notification.isRead
                                ? Colors.grey
                                : Colors.blue,
                            child: Icon(
                              _getNotificationIcon(notification.type.toValue()),
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            notification.getMessage(),
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notification.getPreview() ?? ''),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(notification.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          tileColor: notification.isRead
                              ? null
                              : Colors.blue.withOpacity(0.05),
                          trailing: notification.isRead
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : null,
                          onTap: () {
                            if (!notification.isRead) {
                              _markAsRead(notification.notificationId);
                            }
                            // Navegar a detalle si es necesario
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  /// ✅ HELPER: Ícono según tipo de notificación
  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'comment_reply':
        return Icons.comment;
      case 'rating_milestone':
        return Icons.star;
      case 'news_published':
        return Icons.article;
      default:
        return Icons.notifications;
    }
  }

  /// ✅ HELPER: Formatear timestamp relativo
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Ahora';
    } else if (diff.inHours < 1) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inDays < 1) {
      return 'Hace ${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
