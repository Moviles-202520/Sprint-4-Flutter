import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/bookmark.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../services/bookmark_local_storage.dart';
import 'supabase_bookmark_repository.dart';

/// ✅ HYBRID BOOKMARK REPOSITORY (C.3 - Sync Queue + LWW)
/// Coordina entre local storage y Supabase con resolución de conflictos LWW
class HybridBookmarkRepository implements BookmarkRepository {
  final BookmarkLocalStorage _localStorage;
  final SupabaseBookmarkRepository _remoteRepository;
  final Connectivity _connectivity = Connectivity();
  final SupabaseClient _supabase;

  HybridBookmarkRepository({
    BookmarkLocalStorage? localStorage,
    SupabaseBookmarkRepository? remoteRepository,
    SupabaseClient? supabase,
  })  : _localStorage = localStorage ?? BookmarkLocalStorage(),
        _supabase = supabase ?? Supabase.instance.client,
        _remoteRepository = remoteRepository ?? SupabaseBookmarkRepository(supabase ?? Supabase.instance.client);

  /// ✅ OBTENER USER PROFILE ID ACTUAL
  int? _getCurrentUserProfileId() {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    
    // Asumir que user_profile_id está en metadata o derivar de auth ID
    // Ajustar según tu implementación real
    return user.userMetadata?['user_profile_id'] as int?;
  }

  /// ✅ VERIFICAR CONEXIÓN
  Future<bool> get _isConnected async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// ✅ OBTENER BOOKMARKS (local-first con sync en background)
  @override
  Future<List<Bookmark>> getBookmarks({bool includeDeleted = false}) async {
    final userProfileId = _getCurrentUserProfileId();
    if (userProfileId == null) return [];

    try {
      // 1. SIEMPRE retornar datos locales primero
      final localBookmarks = await _localStorage.getBookmarks(
        userProfileId,
        includeDeleted: includeDeleted,
      );

      print('📱 ${localBookmarks.length} bookmarks desde local storage');

      // 2. Si hay conexión, sincronizar en background
      if (await _isConnected) {
        _syncFromServerInBackground();
      }

      return localBookmarks;
    } catch (e) {
      print('❌ Error obteniendo bookmarks: $e');
      return [];
    }
  }

  /// ✅ SINCRONIZAR DEL SERVIDOR EN BACKGROUND (no bloqueante)
  Future<void> _syncFromServerInBackground() async {
    try {
      print('🌐 Sincronizando bookmarks desde servidor...');
      
      final serverBookmarks = await _remoteRepository.getBookmarks(
        includeDeleted: true, // Traer todos para detectar eliminaciones
      );

      final userProfileId = _getCurrentUserProfileId();
      if (userProfileId == null) return;

      // Obtener bookmarks locales para comparar
      final localBookmarks = await _localStorage.getBookmarks(
        userProfileId,
        includeDeleted: true,
      );

      // Crear mapa local por news_item_id para búsqueda rápida
      final localMap = {
        for (var b in localBookmarks) b.newsItemId: b
      };

      // Fusionar con LWW
      for (final serverBookmark in serverBookmarks) {
        final localBookmark = localMap[serverBookmark.newsItemId];

        if (localBookmark == null) {
          // No existe localmente → guardar del servidor
          await _localStorage.saveBookmark(serverBookmark, syncStatus: 'synced');
        } else {
          // Existe localmente → LWW (el más reciente gana)
          final winner = localBookmark.mergeWith(serverBookmark);
          
          if (winner.bookmarkId != localBookmark.bookmarkId) {
            // El servidor ganó → actualizar local
            await _localStorage.saveBookmark(winner, syncStatus: 'synced');
            print('🔄 LWW: Servidor ganó para news_id ${winner.newsItemId}');
          } else if (localBookmark.updatedAt.isAfter(serverBookmark.updatedAt)) {
            // Local ganó → marcar pendiente de sync (si no está ya)
            print('🔄 LWW: Local ganó para news_id ${localBookmark.newsItemId}, quedará pendiente');
          }
        }
      }

      print('✅ Sincronización desde servidor completada');
    } catch (e) {
      print('⚠️ Error sincronizando desde servidor: $e');
    }
  }

  /// ✅ VERIFICAR SI ESTÁ MARCADO (local-first)
  @override
  Future<bool> isBookmarked(int newsItemId) async {
    final userProfileId = _getCurrentUserProfileId();
    if (userProfileId == null) return false;

    return await _localStorage.isBookmarked(userProfileId, newsItemId);
  }

  /// ✅ AGREGAR BOOKMARK (offline-first con cola de sync)
  @override
  Future<Bookmark> addBookmark(int newsItemId) async {
    final userProfileId = _getCurrentUserProfileId();
    if (userProfileId == null) {
      throw Exception('Usuario no autenticado');
    }

    try {
      // 1. SIEMPRE guardar localmente primero (instantáneo)
      final bookmark = await _localStorage.addBookmark(userProfileId, newsItemId);

      print('📌 Bookmark agregado localmente: $newsItemId');

      // 2. Si hay conexión, intentar sincronizar inmediatamente
      if (await _isConnected) {
        try {
          final serverBookmark = await _remoteRepository.addBookmark(newsItemId);
          
          // Actualizar local con datos del servidor
          await _localStorage.saveBookmark(serverBookmark, syncStatus: 'synced');
          
          print('✅ Bookmark sincronizado con servidor: $newsItemId');
          return serverBookmark;
        } catch (e) {
          print('⚠️ Error sincronizando con servidor (quedará pendiente): $e');
          // Queda en cola (sync_status = 'pending')
        }
      } else {
        print('📴 Sin conexión - bookmark pendiente de sincronización');
      }

      return bookmark;
    } catch (e) {
      print('❌ Error agregando bookmark: $e');
      rethrow;
    }
  }

  /// ✅ ELIMINAR BOOKMARK (offline-first con soft delete)
  @override
  Future<Bookmark> removeBookmark(int newsItemId) async {
    final userProfileId = _getCurrentUserProfileId();
    if (userProfileId == null) {
      throw Exception('Usuario no autenticado');
    }

    try {
      // 1. SIEMPRE eliminar localmente primero (soft delete)
      final bookmark = await _localStorage.removeBookmark(userProfileId, newsItemId);

      print('🗑️ Bookmark eliminado localmente: $newsItemId');

      // 2. Si hay conexión, intentar sincronizar inmediatamente
      if (await _isConnected) {
        try {
          final serverBookmark = await _remoteRepository.removeBookmark(newsItemId);
          
          // Actualizar local con datos del servidor
          await _localStorage.saveBookmark(serverBookmark, syncStatus: 'synced');
          
          print('✅ Eliminación sincronizada con servidor: $newsItemId');
          return serverBookmark;
        } catch (e) {
          print('⚠️ Error sincronizando eliminación (quedará pendiente): $e');
        }
      } else {
        print('📴 Sin conexión - eliminación pendiente de sincronización');
      }

      return bookmark;
    } catch (e) {
      print('❌ Error eliminando bookmark: $e');
      rethrow;
    }
  }

  /// ✅ OBTENER IDS DE NOTICIAS MARCADAS (local-first)
  @override
  Future<List<int>> getBookmarkedNewsIds() async {
    final userProfileId = _getCurrentUserProfileId();
    if (userProfileId == null) return [];

    return await _localStorage.getBookmarkedNewsIds(userProfileId);
  }

  /// ✅ SINCRONIZAR BOOKMARKS PENDIENTES (LWW reconciliation)
  @override
  Future<void> syncPendingBookmarks() async {
    final userProfileId = _getCurrentUserProfileId();
    if (userProfileId == null) {
      print('⚠️ Usuario no autenticado - no se puede sincronizar');
      return;
    }

    if (!await _isConnected) {
      print('📴 Sin conexión - no se puede sincronizar');
      return;
    }

    try {
      // 1. Obtener bookmarks pendientes de sincronización
      final pendingBookmarks = await _localStorage.getPendingSyncBookmarks(userProfileId);

      if (pendingBookmarks.isEmpty) {
        print('✅ No hay bookmarks pendientes de sincronización');
        return;
      }

      print('🔄 Sincronizando ${pendingBookmarks.length} bookmarks pendientes...');

      // 2. Obtener bookmarks del servidor para comparar (LWW)
      final serverBookmarks = await _remoteRepository.getBookmarks(includeDeleted: true);
      
      final serverMap = {
        for (var b in serverBookmarks) b.newsItemId: b
      };

      // 3. Procesar cada bookmark pendiente con LWW
      for (final localBookmark in pendingBookmarks) {
        try {
          final serverBookmark = serverMap[localBookmark.newsItemId];

          if (serverBookmark == null) {
            // No existe en servidor → subir local
            if (localBookmark.isDeleted) {
              // Ya eliminado localmente, solo marcar como synced
              await _localStorage.markAsSynced(localBookmark.bookmarkId);
            } else {
              await _remoteRepository.addBookmark(localBookmark.newsItemId);
              await _localStorage.markAsSynced(localBookmark.bookmarkId);
            }
            print('✅ Sincronizado: ${localBookmark.newsItemId}');
          } else {
            // Existe en servidor → LWW
            final winner = localBookmark.mergeWith(serverBookmark);

            if (winner.bookmarkId == localBookmark.bookmarkId) {
              // Local ganó → subir al servidor
              if (localBookmark.isDeleted) {
                await _remoteRepository.removeBookmark(localBookmark.newsItemId);
              } else {
                await _remoteRepository.addBookmark(localBookmark.newsItemId);
              }
              await _localStorage.markAsSynced(localBookmark.bookmarkId);
              print('✅ LWW: Local ganó y se sincronizó ${localBookmark.newsItemId}');
            } else {
              // Servidor ganó → actualizar local
              await _localStorage.saveBookmark(winner, syncStatus: 'synced');
              print('🔄 LWW: Servidor ganó, local actualizado ${winner.newsItemId}');
            }
          }
        } catch (e) {
          print('❌ Error sincronizando bookmark ${localBookmark.newsItemId}: $e');
          await _localStorage.recordSyncError(localBookmark.bookmarkId, e.toString());
        }
      }

      print('✅ Sincronización de bookmarks completada');
    } catch (e) {
      print('❌ Error en sincronización masiva de bookmarks: $e');
    }
  }

  /// ✅ LIMPIAR BOOKMARKS ELIMINADOS ANTIGUOS
  Future<int> cleanOldDeletedBookmarks({int daysToKeep = 30}) async {
    return await _localStorage.cleanDeletedBookmarks(daysToKeep: daysToKeep);
  }
}
