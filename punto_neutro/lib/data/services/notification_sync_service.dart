import 'package:connectivity_plus/connectivity_plus.dart';
import '../workers/notification_sync_worker.dart';

/// ✅ SERVICIO PARA GESTIONAR SINCRONIZACIÓN DE NOTIFICACIONES DESDE LA UI
/// Detecta cambios de conectividad y dispara sincronización cuando es necesario
class NotificationSyncService {
  static final NotificationSyncService _instance = NotificationSyncService._internal();
  factory NotificationSyncService() => _instance;
  NotificationSyncService._internal();

  final Connectivity _connectivity = Connectivity();
  bool _isListening = false;

  /// ✅ INICIAR MONITOREO DE CONECTIVIDAD
  /// Llama automáticamente a syncNow() cuando se detecta conexión
  void startConnectivityMonitoring() {
    if (_isListening) {
      print('⚠️ [Sync Service] Ya está monitoreando conectividad');
      return;
    }

    print('📶 [Sync Service] Iniciando monitoreo de conectividad...');
    _isListening = true;

    _connectivity.onConnectivityChanged.listen((result) async {
      final isConnected = result != ConnectivityResult.none;

      if (isConnected) {
        print('✅ [Sync Service] Conexión detectada - sincronizando...');
        await NotificationSyncWorker.syncNow();
      } else {
        print('📴 [Sync Service] Sin conexión');
      }
    });
  }

  /// ✅ DETENER MONITOREO
  void stopConnectivityMonitoring() {
    print('🛑 [Sync Service] Deteniendo monitoreo de conectividad');
    _isListening = false;
    // La suscripción se cancela automáticamente cuando el stream se cierra
  }

  /// ✅ FORZAR SINCRONIZACIÓN MANUAL (botón pull-to-refresh)
  Future<void> forceSyncNow() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    final isConnected = connectivityResult != ConnectivityResult.none;

    if (!isConnected) {
      print('📴 [Sync Service] Sin conexión - no se puede sincronizar');
      throw Exception('No hay conexión a internet');
    }

    print('🔄 [Sync Service] Forzando sincronización manual...');
    await NotificationSyncWorker.syncNow();
  }

  /// ✅ VERIFICAR ESTADO DE CONEXIÓN
  Future<bool> isConnected() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
}
