import 'dart:async';
import 'package:workmanager/workmanager.dart';
import '../services/notification_local_storage.dart';
import '../repositories/supabase_notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ✅ NOTIFICATION SYNC WORKER (B.4 - Eventual Connectivity)
/// Background worker que sincroniza notificaciones pendientes con exponential backoff
/// 
/// Estrategia:
/// - Se ejecuta cada 15 minutos cuando hay conexión
/// - Lee notificaciones pendientes del local storage
/// - Intenta sincronizar con el servidor
/// - Exponential backoff: 2s, 4s, 8s, 16s (max 5 intentos)
/// - Marca como synced cuando exitoso o error después de 5 intentos

// ✅ NOMBRE DE LA TAREA
const String notificationSyncTaskName = "notification_sync_task";

/// ✅ CALLBACK DISPATCHER (ejecutado en background isolate)
/// IMPORTANTE: Esta función debe ser top-level (no dentro de clase)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔄 [Sync Worker] Iniciando tarea: $task');
    
    try {
      // Inicializar Supabase en el isolate de background
      // NOTA: Debe estar inicializado en main.dart primero
      final supabase = Supabase.instance.client;
      
      if (supabase.auth.currentUser == null) {
        print('⚠️ [Sync Worker] Usuario no autenticado - cancelando sync');
        return Future.value(true);
      }

      // Crear instancias del repositorio
      final localStorage = NotificationLocalStorage();
      final remoteRepository = SupabaseNotificationRepository(supabase);

      // Obtener notificaciones pendientes de sincronización
      final pendingNotifications = await localStorage.getPendingSyncNotifications();
      
      if (pendingNotifications.isEmpty) {
        print('✅ [Sync Worker] No hay notificaciones pendientes');
        return Future.value(true);
      }

      print('📤 [Sync Worker] ${pendingNotifications.length} notificaciones pendientes');

      // Sincronizar cada notificación con exponential backoff
      int successCount = 0;
      int errorCount = 0;

      for (final row in pendingNotifications) {
        final notificationId = row['notification_id'] as String;
        final pendingAction = row['pending_action'] as String?;
        final lastSyncAttempt = row['last_sync_attempt'] as String?;
        
        // Calcular número de intentos previos (para exponential backoff)
        int attemptCount = 0;
        if (lastSyncAttempt != null) {
          // Estimar intentos basado en el tiempo transcurrido
          final lastAttempt = DateTime.parse(lastSyncAttempt);
          final elapsed = DateTime.now().difference(lastAttempt);
          
          // Si han pasado más de 30 segundos, resetear intentos
          if (elapsed.inSeconds > 30) {
            attemptCount = 0;
          } else {
            // Incrementar intentos (máximo 5)
            attemptCount = (elapsed.inSeconds / 2).floor().clamp(0, 5);
          }
        }

        // Límite de reintentos alcanzado
        if (attemptCount >= 5) {
          print('❌ [Sync Worker] Límite de reintentos alcanzado para $notificationId');
          await localStorage.recordSyncError(
            notificationId,
            'Max retry attempts reached (5)',
          );
          errorCount++;
          continue;
        }

        // Intentar sincronizar con exponential backoff delay
        final delaySeconds = _calculateBackoffDelay(attemptCount);
        print('⏳ [Sync Worker] Esperando ${delaySeconds}s antes de sincronizar $notificationId (intento ${attemptCount + 1}/5)');
        
        await Future.delayed(Duration(seconds: delaySeconds));

        try {
          if (pendingAction == 'mark_as_read') {
            // Sincronizar marcado como leída
            await remoteRepository.markAsRead(notificationId);
            await localStorage.markAsSynced(notificationId);
            
            print('✅ [Sync Worker] Sincronizado: $notificationId');
            successCount++;
          }
        } catch (e) {
          print('❌ [Sync Worker] Error sincronizando $notificationId: $e');
          await localStorage.recordSyncError(notificationId, e.toString());
          errorCount++;
        }
      }

      print('📊 [Sync Worker] Resultados: $successCount exitosos, $errorCount errores');
      
      // Limpiar notificaciones antiguas (mantenimiento)
      await localStorage.cleanOldNotifications(daysToKeep: 30);

      return Future.value(true);
    } catch (e, stackTrace) {
      print('❌ [Sync Worker] Error fatal: $e');
      print(stackTrace);
      return Future.value(false);
    }
  });
}

/// ✅ CALCULAR DELAY DE EXPONENTIAL BACKOFF
/// Intento 0: 2s
/// Intento 1: 4s
/// Intento 2: 8s
/// Intento 3: 16s
/// Intento 4: 16s (cap)
int _calculateBackoffDelay(int attemptCount) {
  if (attemptCount == 0) return 2;
  if (attemptCount == 1) return 4;
  if (attemptCount == 2) return 8;
  return 16; // Cap a 16 segundos
}

/// ✅ CLASE PARA INICIALIZAR Y GESTIONAR EL WORKER
class NotificationSyncWorker {
  /// ✅ INICIALIZAR WORKER (llamar en main.dart)
  static Future<void> initialize() async {
    print('🔧 [Sync Worker] Inicializando WorkManager...');
    
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Cambiar a false en producción
    );

    print('✅ [Sync Worker] WorkManager inicializado');
  }

  /// ✅ REGISTRAR TAREA PERIÓDICA (cada 15 minutos)
  static Future<void> registerPeriodicSync() async {
    print('📅 [Sync Worker] Registrando tarea periódica...');
    
    await Workmanager().registerPeriodicTask(
      "notification_sync_periodic",
      notificationSyncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected, // Solo con conexión
        requiresBatteryNotLow: true,        // No ejecutar con batería baja
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 2),
      existingWorkPolicy: ExistingWorkPolicy.keep, // No duplicar
    );

    print('✅ [Sync Worker] Tarea periódica registrada (cada 15 min)');
  }

  /// ✅ EJECUTAR SINCRONIZACIÓN INMEDIATA (one-shot)
  /// Usado cuando el usuario fuerza sync manualmente o detecta conexión
  static Future<void> syncNow() async {
    print('🚀 [Sync Worker] Ejecutando sincronización inmediata...');
    
    await Workmanager().registerOneOffTask(
      "notification_sync_oneoff_${DateTime.now().millisecondsSinceEpoch}",
      notificationSyncTaskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 2),
    );

    print('✅ [Sync Worker] Tarea one-off registrada');
  }

  /// ✅ CANCELAR TODAS LAS TAREAS (útil para logout)
  static Future<void> cancelAll() async {
    print('🛑 [Sync Worker] Cancelando todas las tareas...');
    await Workmanager().cancelAll();
    print('✅ [Sync Worker] Todas las tareas canceladas');
  }

  /// ✅ CANCELAR TAREA PERIÓDICA ESPECÍFICA
  static Future<void> cancelPeriodicSync() async {
    print('🛑 [Sync Worker] Cancelando tarea periódica...');
    await Workmanager().cancelByUniqueName("notification_sync_periodic");
    print('✅ [Sync Worker] Tarea periódica cancelada');
  }
}
