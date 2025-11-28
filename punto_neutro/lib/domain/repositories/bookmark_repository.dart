import '../models/bookmark.dart';

/// ✅ REPOSITORIO ABSTRACTO DE BOOKMARKS
/// Define contrato para operaciones CRUD con eventual connectivity
abstract class BookmarkRepository {
  /// Obtener todos los bookmarks del usuario (no eliminados)
  Future<List<Bookmark>> getBookmarks({bool includeDeleted = false});

  /// Verificar si una noticia está marcada como bookmark
  Future<bool> isBookmarked(int newsItemId);

  /// Agregar bookmark (upsert)
  /// Si ya existe, actualiza updated_at
  Future<Bookmark> addBookmark(int newsItemId);

  /// Eliminar bookmark (soft delete)
  /// Marca is_deleted = true y actualiza updated_at
  Future<Bookmark> removeBookmark(int newsItemId);

  /// Sincronizar bookmarks pendientes con el servidor
  /// Resuelve conflictos usando LWW (Last-Write-Wins)
  Future<void> syncPendingBookmarks();

  /// Obtener IDs de noticias marcadas como bookmark (para filtrado rápido)
  Future<List<int>> getBookmarkedNewsIds();
}
