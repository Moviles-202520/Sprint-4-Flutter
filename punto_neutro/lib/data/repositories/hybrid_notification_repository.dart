import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../services/notification_local_storage.dart';
import 'supabase_notification_repository.dart';

/// ✅ REPOSITORIO HÍBRIDO PARA NOTIFICACIONES (Eventual Connectivity)
/// Coordina entre almacenamiento local (offline-first) y Supabase (sync)
class HybridNotificationRepository implements NotificationRepository {
  final NotificationLocalStorage _localStorage;
  final SupabaseNotificationRepository _remoteRepository;
  final Connectivity _connectivity = Connectivity();

  HybridNotificationRepository({
    NotificationLocalStorage? localStorage,
    SupabaseNotificationRepository? remoteRepository,
  })  : _localStorage = localStorage ?? NotificationLocalStorage(),
        _remoteRepository = remoteRepository ?? SupabaseNotificationRepository(Supabase.instance.client);

  /// ✅ VERIFICAR CONEXIÓN
  Future<bool> get _isConnected async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// ✅ OBTENER NOTIFICACIONES (Local-first con sync en background)
  /// Lee desde local storage primero, luego sincroniza del servidor si hay conexión
  @override
  Future<List<AppNotification>> getNotifications({
    int limit = 20,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    try {
      // 1. SIEMPRE retornar datos locales primero (offline-first)
      final localNotifications = await _localStorage.getNotifications(
        limit: limit,
        offset: offset,
        unreadOnly: unreadOnly,
      );

      print('📱 ${localNotifications.length} notificaciones desde local storage');

      // 2. Si hay conexión, sincronizar del servidor en background (no bloquear UI)
      if (await _isConnected) {
        _syncFromServerInBackground(limit: limit, offset: offset, unreadOnly: unreadOnly);
      } else {
        print('📴 Sin conexión - usando solo datos locales');
      }

      return localNotifications;
    } catch (e) {
      print('❌ Error obteniendo notificaciones: $e');
      return [];
    }
  }

  /// ✅ SINCRONIZAR DEL SERVIDOR EN BACKGROUND
  /// No bloqueante - actualiza local storage con nuevas notificaciones del servidor
  Future<void> _syncFromServerInBackground({
    int limit = 20,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    try {
      print('🌐 Sincronizando notificaciones desde servidor...');
      
      final serverNotifications = await _remoteRepository.getNotifications(
        limit: limit,
        offset: offset,
        unreadOnly: unreadOnly,
      );

      // Guardar en local storage (replace si ya existen)
      for (final notification in serverNotifications) {
        await _localStorage.saveNotification(
          notification,
          syncStatus: 'synced', // Ya vienen del servidor, están sincronizadas
        );
      }

      print('✅ ${serverNotifications.length} notificaciones sincronizadas desde servidor');
    } catch (e) {
      print('⚠️ Error sincronizando desde servidor (continuando con local): $e');
    }
  }

  /// ✅ MARCAR COMO LEÍDA (Offline-first con cola de sincronización)
  /// Escribe localmente inmediato, sincroniza al servidor cuando hay conexión
  @override
  Future<AppNotification> markAsRead(String notificationId) async {
    try {
      // 1. SIEMPRE marcar localmente primero (offline-first)
      await _localStorage.markAsReadLocal(notificationId);

      print('📝 Notificación marcada como leída localmente: $notificationId');

      // 2. Si hay conexión, sincronizar al servidor inmediatamente
      if (await _isConnected) {
        try {
          final updatedNotification = await _remoteRepository.markAsRead(notificationId);
          
          // Actualizar local storage con datos del servidor (confirmar sync exitoso)
          await _localStorage.saveNotification(
            updatedNotification,
            syncStatus: 'synced',
          );

          print('✅ Notificación sincronizada con servidor: $notificationId');
          return updatedNotification;
        } catch (e) {
          print('⚠️ Error sincronizando con servidor (quedará pendiente): $e');
          // La notificación queda en cola (sync_status = 'pending')
          // El sync worker la procesará después
        }
      } else {
        print('📴 Sin conexión - marcado pendiente de sincronización');
      }

      // 3. Retornar la notificación actualizada desde local storage
      final localNotifications = await _localStorage.getNotifications(limit: 100);
      final updatedNotification = localNotifications.firstWhere(
        (n) => n.notificationId == notificationId,
        orElse: () => throw Exception('Notification not found after update'),
      );

      return updatedNotification;
    } catch (e) {
      print('❌ Error marcando notificación como leída: $e');
      rethrow;
    }
  }

  /// ✅ MARCAR TODAS COMO LEÍDAS (Offline-first con cola de sincronización)
  @override
  Future<int> markAllAsRead() async {
    try {
      // 1. SIEMPRE marcar localmente primero (offline-first)
      final count = await _localStorage.markAllAsReadLocal();

      print('📝 $count notificaciones marcadas como leídas localmente');

      // 2. Si hay conexión, sincronizar al servidor
      if (await _isConnected) {
        try {
          final serverCount = await _remoteRepository.markAllAsRead();
          print('✅ $serverCount notificaciones sincronizadas con servidor');
        } catch (e) {
          print('⚠️ Error sincronizando con servidor (quedarán pendientes): $e');
          // Las notificaciones quedan en cola (sync_status = 'pending')
        }
      } else {
        print('📴 Sin conexión - marcado pendiente de sincronización');
      }

      return count;
    } catch (e) {
      print('❌ Error marcando todas como leídas: $e');
      return 0;
    }
  }

  /// ✅ OBTENER CONTEO DE NO LEÍDAS (Local-first)
  @override
  Future<int> getUnreadCount() async {
    try {
      // Leer siempre desde local storage (más rápido, funciona offline)
      final count = await _localStorage.getUnreadCount();
      
      // Opcional: sincronizar en background si hay conexión
      if (await _isConnected) {
        _syncUnreadCountInBackground();
      }

      return count;
    } catch (e) {
      print('❌ Error obteniendo conteo de no leídas: $e');
      return 0;
    }
  }

  /// ✅ SINCRONIZAR CONTEO EN BACKGROUND
  Future<void> _syncUnreadCountInBackground() async {
    try {
      final serverCount = await _remoteRepository.getUnreadCount();
      final localCount = await _localStorage.getUnreadCount();

      if (serverCount != localCount) {
        print('⚠️ Desincronización detectada - servidor: $serverCount, local: $localCount');
        // Trigger full sync (el sync worker manejará esto)
      }
    } catch (e) {
      print('⚠️ Error verificando conteo en servidor: $e');
    }
  }

  /// ✅ SINCRONIZAR DATOS PENDIENTES AL SERVIDOR
  /// Llamado por sync worker o cuando se detecta conexión
  Future<void> syncPendingToServer() async {
    try {
      if (!await _isConnected) {
        print('📴 Sin conexión - no se puede sincronizar');
        return;
      }

      final pendingNotifications = await _localStorage.getPendingSyncNotifications();

      if (pendingNotifications.isEmpty) {
        print('✅ No hay notificaciones pendientes de sincronización');
        return;
      }

      print('🔄 Sincronizando ${pendingNotifications.length} notificaciones pendientes...');

      for (final row in pendingNotifications) {
        final notificationId = row['notification_id'] as String;
        final pendingAction = row['pending_action'] as String?;

        try {
          if (pendingAction == 'mark_as_read') {
            // Sincronizar marcado como leída
            await _remoteRepository.markAsRead(notificationId);
            await _localStorage.markAsSynced(notificationId);
            print('✅ Sincronizado: $notificationId');
          }
        } catch (e) {
          print('❌ Error sincronizando $notificationId: $e');
          await _localStorage.recordSyncError(notificationId, e.toString());
        }
      }

      print('✅ Sincronización completada');
    } catch (e) {
      print('❌ Error en sincronización masiva: $e');
    }
  }

  /// ✅ LIMPIAR NOTIFICACIONES ANTIGUAS (Mantenimiento)
  Future<int> cleanOldNotifications({int daysToKeep = 30}) async {
    return await _localStorage.cleanOldNotifications(daysToKeep: daysToKeep);
  }
}
