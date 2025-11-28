import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/models/bookmark.dart';

/// ✅ BOOKMARK LOCAL STORAGE (C.2 - Local-First)
/// Almacena bookmarks localmente con cola de sincronización y soporte para LWW
class BookmarkLocalStorage {
  static final BookmarkLocalStorage _instance = BookmarkLocalStorage._internal();
  factory BookmarkLocalStorage() => _instance;
  BookmarkLocalStorage._internal();

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
    final path = join(dbPath, 'bookmarks_local.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        print('🗄️ Creando base de datos local de bookmarks v$version');
        
        // Tabla de bookmarks locales con campos LWW
        await db.execute('''
          CREATE TABLE local_bookmarks(
            bookmark_id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_profile_id INTEGER NOT NULL,
            news_item_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'synced',
            last_sync_attempt TEXT,
            sync_error TEXT,
            UNIQUE(user_profile_id, news_item_id)
          )
        ''');

        // Índices para optimización
        await db.execute('CREATE INDEX idx_bookmarks_user ON local_bookmarks(user_profile_id)');
        await db.execute('CREATE INDEX idx_bookmarks_sync ON local_bookmarks(sync_status)');
        await db.execute('CREATE INDEX idx_bookmarks_updated ON local_bookmarks(updated_at DESC)');
        
        print('✅ Base de datos local de bookmarks creada exitosamente');
      },
    );
  }

  /// ✅ GUARDAR BOOKMARK LOCALMENTE (write-through, instantáneo)
  Future<Bookmark> saveBookmark(
    Bookmark bookmark, {
    String syncStatus = 'synced',
  }) async {
    final db = await database;
    
    try {
      await db.insert(
        'local_bookmarks',
        {
          'bookmark_id': bookmark.bookmarkId,
          'user_profile_id': bookmark.userProfileId,
          'news_item_id': bookmark.newsItemId,
          'created_at': bookmark.createdAt.toIso8601String(),
          'updated_at': bookmark.updatedAt.toIso8601String(),
          'is_deleted': bookmark.isDeleted ? 1 : 0,
          'sync_status': syncStatus,
          'last_sync_attempt': null,
          'sync_error': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('📥 Bookmark guardado localmente: ${bookmark.newsItemId}');
      return bookmark;
    } catch (e) {
      print('❌ Error guardando bookmark local: $e');
      rethrow;
    }
  }

  /// ✅ AGREGAR BOOKMARK (offline-first, instantáneo)
  Future<Bookmark> addBookmark(int userProfileId, int newsItemId) async {
    final db = await database;
    final now = DateTime.now();
    
    try {
      // Verificar si ya existe
      final existing = await db.query(
        'local_bookmarks',
        where: 'user_profile_id = ? AND news_item_id = ?',
        whereArgs: [userProfileId, newsItemId],
      );

      if (existing.isNotEmpty) {
        // Ya existe - actualizar updated_at y marcar no eliminado
        await db.update(
          'local_bookmarks',
          {
            'updated_at': now.toIso8601String(),
            'is_deleted': 0,
            'sync_status': 'pending',
          },
          where: 'user_profile_id = ? AND news_item_id = ?',
          whereArgs: [userProfileId, newsItemId],
        );

        final row = existing.first;
        return Bookmark(
          bookmarkId: row['bookmark_id'] as int,
          userProfileId: userProfileId,
          newsItemId: newsItemId,
          createdAt: DateTime.parse(row['created_at'] as String),
          updatedAt: now,
          isDeleted: false,
        );
      } else {
        // Nuevo bookmark
        final id = await db.insert(
          'local_bookmarks',
          {
            'user_profile_id': userProfileId,
            'news_item_id': newsItemId,
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
            'is_deleted': 0,
            'sync_status': 'pending',
          },
        );

        print('📌 Bookmark agregado localmente: $newsItemId');

        return Bookmark(
          bookmarkId: id,
          userProfileId: userProfileId,
          newsItemId: newsItemId,
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        );
      }
    } catch (e) {
      print('❌ Error agregando bookmark: $e');
      rethrow;
    }
  }

  /// ✅ ELIMINAR BOOKMARK (soft delete, offline-first)
  Future<Bookmark> removeBookmark(int userProfileId, int newsItemId) async {
    final db = await database;
    final now = DateTime.now();
    
    try {
      final existing = await db.query(
        'local_bookmarks',
        where: 'user_profile_id = ? AND news_item_id = ?',
        whereArgs: [userProfileId, newsItemId],
      );

      if (existing.isEmpty) {
        throw Exception('Bookmark no encontrado');
      }

      final row = existing.first;

      await db.update(
        'local_bookmarks',
        {
          'updated_at': now.toIso8601String(),
          'is_deleted': 1,
          'sync_status': 'pending',
        },
        where: 'user_profile_id = ? AND news_item_id = ?',
        whereArgs: [userProfileId, newsItemId],
      );

      print('🗑️ Bookmark eliminado localmente (soft delete): $newsItemId');

      return Bookmark(
        bookmarkId: row['bookmark_id'] as int,
        userProfileId: userProfileId,
        newsItemId: newsItemId,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: now,
        isDeleted: true,
      );
    } catch (e) {
      print('❌ Error eliminando bookmark: $e');
      rethrow;
    }
  }

  /// ✅ OBTENER BOOKMARKS (no eliminados por defecto)
  Future<List<Bookmark>> getBookmarks(
    int userProfileId, {
    bool includeDeleted = false,
  }) async {
    final db = await database;
    
    try {
      String whereClause = 'user_profile_id = ?';
      List<dynamic> whereArgs = [userProfileId];

      if (!includeDeleted) {
        whereClause += ' AND is_deleted = 0';
      }

      final results = await db.query(
        'local_bookmarks',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'updated_at DESC',
      );

      return results.map((row) => _bookmarkFromRow(row)).toList();
    } catch (e) {
      print('❌ Error obteniendo bookmarks: $e');
      return [];
    }
  }

  /// ✅ VERIFICAR SI ESTÁ MARCADO COMO BOOKMARK
  Future<bool> isBookmarked(int userProfileId, int newsItemId) async {
    final db = await database;
    
    try {
      final results = await db.query(
        'local_bookmarks',
        where: 'user_profile_id = ? AND news_item_id = ? AND is_deleted = 0',
        whereArgs: [userProfileId, newsItemId],
      );

      return results.isNotEmpty;
    } catch (e) {
      print('❌ Error verificando bookmark: $e');
      return false;
    }
  }

  /// ✅ OBTENER IDS DE NOTICIAS MARCADAS (para filtrado rápido)
  Future<List<int>> getBookmarkedNewsIds(int userProfileId) async {
    final db = await database;
    
    try {
      final results = await db.query(
        'local_bookmarks',
        columns: ['news_item_id'],
        where: 'user_profile_id = ? AND is_deleted = 0',
        whereArgs: [userProfileId],
      );

      return results.map((row) => row['news_item_id'] as int).toList();
    } catch (e) {
      print('❌ Error obteniendo IDs de bookmarks: $e');
      return [];
    }
  }

  /// ✅ OBTENER BOOKMARKS PENDIENTES DE SINCRONIZACIÓN
  Future<List<Bookmark>> getPendingSyncBookmarks(int userProfileId) async {
    final db = await database;
    
    try {
      final results = await db.query(
        'local_bookmarks',
        where: 'user_profile_id = ? AND sync_status = ?',
        whereArgs: [userProfileId, 'pending'],
        orderBy: 'updated_at ASC',
      );

      return results.map((row) => _bookmarkFromRow(row)).toList();
    } catch (e) {
      print('❌ Error obteniendo bookmarks pendientes: $e');
      return [];
    }
  }

  /// ✅ MARCAR COMO SINCRONIZADO
  Future<void> markAsSynced(int bookmarkId) async {
    final db = await database;
    
    try {
      await db.update(
        'local_bookmarks',
        {
          'sync_status': 'synced',
          'sync_error': null,
        },
        where: 'bookmark_id = ?',
        whereArgs: [bookmarkId],
      );

      print('✅ Bookmark sincronizado: $bookmarkId');
    } catch (e) {
      print('❌ Error marcando como sincronizado: $e');
    }
  }

  /// ✅ REGISTRAR ERROR DE SINCRONIZACIÓN
  Future<void> recordSyncError(int bookmarkId, String error) async {
    final db = await database;
    
    try {
      await db.update(
        'local_bookmarks',
        {
          'sync_status': 'error',
          'sync_error': error,
          'last_sync_attempt': DateTime.now().toIso8601String(),
        },
        where: 'bookmark_id = ?',
        whereArgs: [bookmarkId],
      );

      print('⚠️ Error de sincronización registrado para bookmark $bookmarkId: $error');
    } catch (e) {
      print('❌ Error registrando error de sincronización: $e');
    }
  }

  /// ✅ LIMPIAR BOOKMARKS ELIMINADOS ANTIGUOS (hard delete)
  /// Elimina permanentemente bookmarks marcados como is_deleted hace más de X días
  Future<int> cleanDeletedBookmarks({int daysToKeep = 30}) async {
    final db = await database;
    
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      
      final count = await db.delete(
        'local_bookmarks',
        where: 'is_deleted = 1 AND updated_at < ? AND sync_status = ?',
        whereArgs: [cutoffDate.toIso8601String(), 'synced'],
      );

      print('🧹 $count bookmarks eliminados limpiados');
      return count;
    } catch (e) {
      print('❌ Error limpiando bookmarks eliminados: $e');
      return 0;
    }
  }

  /// ✅ HELPER: Crear Bookmark desde row de BD
  Bookmark _bookmarkFromRow(Map<String, dynamic> row) {
    return Bookmark(
      bookmarkId: row['bookmark_id'] as int,
      userProfileId: row['user_profile_id'] as int,
      newsItemId: row['news_item_id'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      isDeleted: (row['is_deleted'] as int) == 1,
    );
  }

  /// ✅ CERRAR BASE DE DATOS
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      print('🔒 Base de datos local de bookmarks cerrada');
    }
  }
}
