import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/bookmark.dart';
import '../../domain/repositories/bookmark_repository.dart';

/// ✅ SUPABASE BOOKMARK REPOSITORY (C.4 - Backend API)
/// Implementa endpoints idempotentes con upsert y soft delete
class SupabaseBookmarkRepository implements BookmarkRepository {
  final SupabaseClient _supabase;
  int? _cachedUserProfileId;

  SupabaseBookmarkRepository(this._supabase);

  /// Get current user's profile ID (cached)
  Future<int> _getUserProfileId() async {
    if (_cachedUserProfileId != null) return _cachedUserProfileId!;
    
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');
    
    final response = await _supabase
        .from('user_profiles')
        .select('user_profile_id')
        .eq('user_auth_id', userId)
        .single();
    
    _cachedUserProfileId = response['user_profile_id'] as int;
    return _cachedUserProfileId!;
  }

  /// ✅ OBTENER BOOKMARKS DEL USUARIO
  @override
  Future<List<Bookmark>> getBookmarks({bool includeDeleted = false}) async {
    try {
      // ⚠️ JOIN con news_items para traer el título
      var query = _supabase
          .from('bookmarks')
          .select('*, news_items!inner(title)'); // ⚠️ JOIN con news_items

      if (!includeDeleted) {
        query = query.eq('is_deleted', false);
      }

      final response = await query
          .order('updated_at', ascending: false);

      return response.map<Bookmark>((json) {
        // ⚠️ Extraer título del JOIN
        final newsTitle = json['news_items'] != null 
            ? json['news_items']['title'] as String?
            : null;
        
        final bookmarkData = Map<String, dynamic>.from(json);
        bookmarkData['news_title'] = newsTitle; // ⚠️ Agregar título al JSON
        
        return Bookmark.fromJson(bookmarkData);
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
      final userProfileId = await _getUserProfileId();
      final now = DateTime.now();
      
      // Usar upsert para idempotencia
      // Si existe, actualiza updated_at y marca is_deleted=false
      final response = await _supabase
          .from('bookmarks')
          .upsert({
            'user_profile_id': userProfileId,
            'news_item_id': newsItemId,
            'updated_at': now.toIso8601String(),
            'is_deleted': false,
          },
          onConflict: 'user_profile_id,news_item_id',
        )
          .select()
          .single();

      print('✅ Bookmark agregado/actualizado en Supabase: $newsItemId (user: $userProfileId)');
      
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
      final userProfileId = await _getUserProfileId();
      final now = DateTime.now();
      
      final response = await _supabase
          .from('bookmarks')
          .update({
            'is_deleted': true,
            'updated_at': now.toIso8601String(),
          })
          .eq('user_profile_id', userProfileId)
          .eq('news_item_id', newsItemId)
          .select()
          .single();

      print('✅ Bookmark eliminado (soft delete) en Supabase: $newsItemId (user: $userProfileId)');
      
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
      final userProfileId = await _getUserProfileId();
      
      final data = bookmarks.map((b) => {
        'user_profile_id': userProfileId,
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

      print('✅ ${bookmarks.length} bookmarks sincronizados en batch (user: $userProfileId)');
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
