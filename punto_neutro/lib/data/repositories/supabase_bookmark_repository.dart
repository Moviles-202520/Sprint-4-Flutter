import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/bookmark.dart';
import '../../domain/repositories/bookmark_repository.dart';

/// ✅ SUPABASE BOOKMARK REPOSITORY (C.4 - Backend API)
/// Implementa endpoints idempotentes con upsert y soft delete
class SupabaseBookmarkRepository implements BookmarkRepository {
  final SupabaseClient _supabase;

  SupabaseBookmarkRepository(this._supabase);

  /// ✅ OBTENER BOOKMARKS DEL USUARIO
  @override
  Future<List<Bookmark>> getBookmarks({bool includeDeleted = false}) async {
    try {
      var query = _supabase
          .from('bookmarks')
          .select();

      if (!includeDeleted) {
        query = query.eq('is_deleted', false);
      }

      final response = await query
          .order('updated_at', ascending: false);

      return response.map<Bookmark>((json) {
        return Bookmark.fromJson(Map<String, dynamic>.from(json));
      }).toList();
    } catch (e) {
      print('❌ Error obteniendo bookmarks desde Supabase: $e');
      rethrow;
    }
  }

  /// ✅ VERIFICAR SI ESTÁ MARCADO COMO BOOKMARK
  @override
  Future<bool> isBookmarked(int newsItemId) async {
    try {
      final response = await _supabase
          .from('bookmarks')
          .select('bookmark_id')
          .eq('news_item_id', newsItemId)
          .eq('is_deleted', false);

      return response.isNotEmpty;
    } catch (e) {
      print('❌ Error verificando bookmark en Supabase: $e');
      return false;
    }
  }

  /// ✅ AGREGAR BOOKMARK (UPSERT IDEMPOTENTE)
  /// Si ya existe, actualiza updated_at (no crea duplicado)
  @override
  Future<Bookmark> addBookmark(int newsItemId) async {
    try {
      final now = DateTime.now();
      
      // Usar upsert para idempotencia
      // Si existe, actualiza updated_at y marca is_deleted=false
      final response = await _supabase
          .from('bookmarks')
          .upsert({
            'news_item_id': newsItemId,
            'updated_at': now.toIso8601String(),
            'is_deleted': false,
          },
          onConflict: 'user_profile_id,news_item_id',
        )
          .select()
          .single();

      print('✅ Bookmark agregado/actualizado en Supabase: $newsItemId');
      
      return Bookmark.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('❌ Error agregando bookmark en Supabase: $e');
      rethrow;
    }
  }

  /// ✅ ELIMINAR BOOKMARK (SOFT DELETE IDEMPOTENTE)
  /// Marca is_deleted=true y actualiza updated_at
  @override
  Future<Bookmark> removeBookmark(int newsItemId) async {
    try {
      final now = DateTime.now();
      
      final response = await _supabase
          .from('bookmarks')
          .update({
            'is_deleted': true,
            'updated_at': now.toIso8601String(),
          })
          .eq('news_item_id', newsItemId)
          .select()
          .single();

      print('✅ Bookmark eliminado (soft delete) en Supabase: $newsItemId');
      
      return Bookmark.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      print('❌ Error eliminando bookmark en Supabase: $e');
      rethrow;
    }
  }

  /// ✅ UPSERT BATCH (para sincronización masiva)
  /// Acepta lista de bookmarks y los inserta/actualiza usando LWW
  Future<void> upsertBookmarks(List<Bookmark> bookmarks) async {
    if (bookmarks.isEmpty) return;

    try {
      final data = bookmarks.map((b) => {
        'news_item_id': b.newsItemId,
        'updated_at': b.updatedAt.toIso8601String(),
        'is_deleted': b.isDeleted,
      }).toList();

      await _supabase
          .from('bookmarks')
          .upsert(
            data,
            onConflict: 'user_profile_id,news_item_id',
          );

      print('✅ ${bookmarks.length} bookmarks sincronizados en batch');
    } catch (e) {
      print('❌ Error en upsert batch: $e');
      rethrow;
    }
  }

  /// ✅ FETCH BOOKMARKS ACTUALIZADOS DESDE TIMESTAMP
  /// Usado para sincronización incremental (solo traer cambios nuevos)
  Future<List<Bookmark>> fetchBookmarksSince(DateTime since) async {
    try {
      final response = await _supabase
          .from('bookmarks')
          .select()
          .gte('updated_at', since.toIso8601String())
          .order('updated_at', ascending: false);

      return response.map<Bookmark>((json) {
        return Bookmark.fromJson(Map<String, dynamic>.from(json));
      }).toList();
    } catch (e) {
      print('❌ Error obteniendo bookmarks desde timestamp: $e');
      return [];
    }
  }

  /// ✅ OBTENER IDS DE NOTICIAS MARCADAS
  @override
  Future<List<int>> getBookmarkedNewsIds() async {
    try {
      final response = await _supabase
          .from('bookmarks')
          .select('news_item_id')
          .eq('is_deleted', false);

      return response.map<int>((row) => row['news_item_id'] as int).toList();
    } catch (e) {
      print('❌ Error obteniendo IDs de bookmarks: $e');
      return [];
    }
  }

  /// ✅ SINCRONIZAR (implementación delegada a repositorio híbrido)
  @override
  Future<void> syncPendingBookmarks() async {
    throw UnimplementedError('Use HybridBookmarkRepository.syncPendingBookmarks()');
  }
}
