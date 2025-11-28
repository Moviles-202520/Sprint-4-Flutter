import 'dart:async';
import 'package:workmanager/workmanager.dart';
import '../repositories/hybrid_bookmark_repository.dart';
import '../services/bookmark_local_storage.dart';
import '../repositories/supabase_bookmark_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ✅ BOOKMARK SYNC WORKER (C.3 - Eventual Connectivity)
/// Background worker que sincroniza bookmarks pendientes con LWW reconciliation

// ✅ NOMBRE DE LA TAREA
const String bookmarkSyncTaskName = "bookmark_sync_task";

/// ✅ CALLBACK DISPATCHER (ejecutado en background isolate)
@pragma('vm:entry-point')
void bookmarkCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔄 [Bookmark Sync] Iniciando tarea: $task');
    
    try {
      final supabase = Supabase.instance.client;
      
      if (supabase.auth.currentUser == null) {
        print('⚠️ [Bookmark Sync] Usuario no autenticado - cancelando');
        return Future.value(true);
      }

      // Crear instancias del repositorio
      final localStorage = BookmarkLocalStorage();
      final remoteRepository = SupabaseBookmarkRepository(supabase);
      final hybridRepository = HybridBookmarkRepository(
        localStorage: localStorage,
        remoteRepository: remoteRepository,
        supabase: supabase,
      );

      // Sincronizar bookmarks pendientes con LWW
      await hybridRepository.syncPendingBookmarks();

      // Limpiar bookmarks eliminados antiguos (mantenimiento)
      await hybridRepository.cleanOldDeletedBookmarks(daysToKeep: 30);

      print('✅ [Bookmark Sync] Sincronización completada');
      return Future.value(true);
    } catch (e, stackTrace) {
      print('❌ [Bookmark Sync] Error fatal: $e');
      print(stackTrace);
      return Future.value(false);
    }
  });
}

/// ✅ CLASE PARA GESTIONAR EL WORKER
class BookmarkSyncWorker {
  /// ✅ INICIALIZAR WORKER
  static Future<void> initialize() async {
    print('🔧 [Bookmark Sync] Inicializando WorkManager...');
    
    await Workmanager().initialize(
      bookmarkCallbackDispatcher,
      isInDebugMode: true,
    );

    print('✅ [Bookmark Sync] WorkManager inicializado');
  }

  /// ✅ REGISTRAR TAREA PERIÓDICA (cada 15 minutos)
  static Future<void> registerPeriodicSync() async {
    print('📅 [Bookmark Sync] Registrando tarea periódica...');
    
    await Workmanager().registerPeriodicTask(
      "bookmark_sync_periodic",
      bookmarkSyncTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 2),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );

    print('✅ [Bookmark Sync] Tarea periódica registrada (cada 15 min)');
  }

  /// ✅ EJECUTAR SINCRONIZACIÓN INMEDIATA
  static Future<void> syncNow() async {
    print('🚀 [Bookmark Sync] Ejecutando sincronización inmediata...');
    
    await Workmanager().registerOneOffTask(
      "bookmark_sync_oneoff_${DateTime.now().millisecondsSinceEpoch}",
      bookmarkSyncTaskName,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 2),
    );

    print('✅ [Bookmark Sync] Tarea one-off registrada');
  }

  /// ✅ CANCELAR TODAS LAS TAREAS
  static Future<void> cancelAll() async {
    print('🛑 [Bookmark Sync] Cancelando todas las tareas...');
    await Workmanager().cancelByUniqueName("bookmark_sync_periodic");
    print('✅ [Bookmark Sync] Tareas canceladas');
  }
}
