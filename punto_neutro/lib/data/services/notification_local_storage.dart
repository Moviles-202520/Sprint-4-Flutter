import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/models/notification.dart';

/// ✅ STORAGE LOCAL PARA NOTIFICACIONES (Eventual Connectivity)
/// Almacena notificaciones localmente con cola de sincronización para operaciones offline
class NotificationLocalStorage {
  static final NotificationLocalStorage _instance = NotificationLocalStorage._internal();
  factory NotificationLocalStorage() => _instance;
  NotificationLocalStorage._internal();

  Database? _database;

  /// ✅ INICIALIZACIÓN DE BD LOCAL
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  /// ✅ CREACIÓN DE ESQUEMA LOCAL
  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'notifications_local.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        print('🗄️ Creando base de datos local de notificaciones v$version');
        
        // Tabla de notificaciones locales
        await db.execute('''
          CREATE TABLE local_notifications(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            notification_id TEXT UNIQUE NOT NULL,
            user_profile_id TEXT NOT NULL,
            notification_type TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            metadata TEXT,
            is_read INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            read_at TEXT,
            sync_status TEXT NOT NULL DEFAULT 'synced',
            pending_action TEXT,
            last_sync_attempt TEXT,
            sync_error TEXT
          )
        ''');

        // Índices para optimización
        await db.execute('CREATE INDEX idx_notifications_user ON local_notifications(user_profile_id)');
        await db.execute('CREATE INDEX idx_notifications_sync ON local_notifications(sync_status)');
        await db.execute('CREATE INDEX idx_notifications_read ON local_notifications(is_read)');
        
        print('✅ Base de datos local de notificaciones creada exitosamente');
      },
    );
  }

  /// ✅ GUARDAR NOTIFICACIÓN LOCALMENTE
  /// Usado cuando se recibe notificación del servidor o se crea offline
  Future<void> saveNotification(
    AppNotification notification, {
    String syncStatus = 'synced',
    String? pendingAction,
  }) async {
    final db = await database;
    
    try {
      await db.insert(
        'local_notifications',
        {
          'notification_id': notification.notificationId.toString(),
          'user_profile_id': notification.userProfileId.toString(),
          'notification_type': notification.type.toValue(),
          'title': notification.getMessage(),
          'body': notification.getPreview() ?? '',
          'metadata': notification.payload != null ? jsonEncode(notification.payload) : null,
          'is_read': notification.isRead ? 1 : 0,
          'created_at': notification.createdAt.toIso8601String(),
          'read_at': null, // El nuevo modelo no tiene readAt
          'sync_status': syncStatus,
          'pending_action': pendingAction,
          'last_sync_attempt': null,
          'sync_error': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('📥 Notificación guardada localmente: ${notification.notificationId}');
    } catch (e) {
      print('❌ Error guardando notificación local: $e');
      rethrow;
    }
  }

  /// ✅ OBTENER NOTIFICACIONES LOCALES
  /// Retorna notificaciones paginadas, opcionalmente solo no leídas
  Future<List<AppNotification>> getNotifications({
    int limit = 20,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    final db = await database;
    
    try {
      String whereClause = '';
      if (unreadOnly) {
        whereClause = 'WHERE is_read = 0';
      }
      
      final results = await db.rawQuery('''
        SELECT * FROM local_notifications
        $whereClause
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
      ''', [limit, offset]);

      return results.map((row) {
        // Deserializar payload de JSON string a Map
        Map<String, dynamic>? payload;
        if (row['metadata'] != null) {
          try {
            payload = jsonDecode(row['metadata'] as String) as Map<String, dynamic>;
          } catch (e) {
            print('⚠️ Error deserializando payload: $e');
            payload = null;
          }
        }

        return AppNotification(
          notificationId: int.parse(row['notification_id'] as String),
          userProfileId: int.parse(row['user_profile_id'] as String),
          type: NotificationType.fromString(row['notification_type'] as String),
          payload: payload,
          isRead: (row['is_read'] as int) == 1,
          createdAt: DateTime.parse(row['created_at'] as String),
          actorUserProfileId: null,
          newsItemId: null,
        );
      }).toList();
    } catch (e) {
      print('❌ Error obteniendo notificaciones locales: $e');
      return [];
    }
  }

  /// ✅ MARCAR COMO LEÍDA (OFFLINE-FIRST)
  /// Marca localmente y encola para sincronización
  Future<void> markAsReadLocal(int notificationId) async {
    final db = await database;
    
    try {
      final now = DateTime.now().toIso8601String();
      
      await db.update(
        'local_notifications',
        {
          'is_read': 1,
          'read_at': now,
          'sync_status': 'pending',
          'pending_action': 'mark_as_read',
        },
        where: 'notification_id = ?',
        whereArgs: [notificationId.toString()],
      );
      
      print('📝 Notificación marcada como leída localmente (pending sync): $notificationId');
    } catch (e) {
      print('❌ Error marcando notificación como leída: $e');
      rethrow;
    }
  }

  /// ✅ MARCAR TODAS COMO LEÍDAS (OFFLINE-FIRST)
  Future<int> markAllAsReadLocal() async {
    final db = await database;
    
    try {
      final now = DateTime.now().toIso8601String();
      
      final count = await db.update(
        'local_notifications',
        {
          'is_read': 1,
          'read_at': now,
          'sync_status': 'pending',
          'pending_action': 'mark_as_read',
        },
        where: 'is_read = 0',
      );
      
      print('📝 $count notificaciones marcadas como leídas localmente (pending sync)');
      return count;
    } catch (e) {
      print('❌ Error marcando todas como leídas: $e');
      return 0;
    }
  }

  /// ✅ CONTAR NO LEÍDAS
  Future<int> getUnreadCount() async {
    final db = await database;
    
    try {
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM local_notifications WHERE is_read = 0
      ''');
      
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('❌ Error contando notificaciones no leídas: $e');
      return 0;
    }
  }

  /// ✅ OBTENER NOTIFICACIONES PENDIENTES DE SINCRONIZACIÓN
  /// Usado por el sync worker para saber qué enviar al servidor
  Future<List<Map<String, dynamic>>> getPendingSyncNotifications() async {
    final db = await database;
    
    try {
      return await db.query(
        'local_notifications',
        where: 'sync_status = ?',
        whereArgs: ['pending'],
        orderBy: 'last_sync_attempt ASC',
      );
    } catch (e) {
      print('❌ Error obteniendo notificaciones pendientes de sync: $e');
      return [];
    }
  }

  /// ✅ MARCAR COMO SINCRONIZADA
  /// Llamado por sync worker después de sincronizar exitosamente
  Future<void> markAsSynced(int notificationId) async {
    final db = await database;
    
    try {
      await db.update(
        'local_notifications',
        {
          'sync_status': 'synced',
          'pending_action': null,
          'sync_error': null,
        },
        where: 'notification_id = ?',
        whereArgs: [notificationId.toString()],
      );
      
      print('✅ Notificación sincronizada: $notificationId');
    } catch (e) {
      print('❌ Error marcando como sincronizada: $e');
    }
  }

  /// ✅ REGISTRAR ERROR DE SINCRONIZACIÓN
  /// Usado cuando el sync worker falla (para exponential backoff)
  Future<void> recordSyncError(int notificationId, String error) async {
    final db = await database;
    
    try {
      await db.update(
        'local_notifications',
        {
          'sync_status': 'error',
          'sync_error': error,
          'last_sync_attempt': DateTime.now().toIso8601String(),
        },
        where: 'notification_id = ?',
        whereArgs: [notificationId.toString()],
      );
      
      print('⚠️ Error de sincronización registrado para $notificationId: $error');
    } catch (e) {
      print('❌ Error registrando error de sincronización: $e');
    }
  }

  /// ✅ LIMPIAR NOTIFICACIONES ANTIGUAS
  /// Mantener solo últimos 30 días para no sobrecargar storage
  Future<int> cleanOldNotifications({int daysToKeep = 30}) async {
    final db = await database;
    
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      
      final count = await db.delete(
        'local_notifications',
        where: 'created_at < ? AND sync_status = ?',
        whereArgs: [cutoffDate.toIso8601String(), 'synced'],
      );
      
      print('🧹 $count notificaciones antiguas eliminadas');
      return count;
    } catch (e) {
      print('❌ Error limpiando notificaciones antiguas: $e');
      return 0;
    }
  }

  /// ✅ CERRAR BASE DE DATOS
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      print('🔒 Base de datos local de notificaciones cerrada');
    }
  }
}
