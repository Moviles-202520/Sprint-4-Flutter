/// ✅ MODELO DE BOOKMARK CON LWW (Last-Write-Wins)
/// Soporta eventual connectivity y resolución de conflictos basada en timestamp
class Bookmark {
  final int bookmarkId;
  final int userProfileId;
  final int newsItemId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String? newsTitle; // ⚠️ NUEVO: Título de la noticia (opcional, viene del JOIN)

  Bookmark({
    required this.bookmarkId,
    required this.userProfileId,
    required this.newsItemId,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.newsTitle, // ⚠️ NUEVO
  });

  /// ✅ FACTORY: Desde JSON (Supabase response)
  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      bookmarkId: json['bookmark_id'] as int,
      userProfileId: json['user_profile_id'] as int,
      newsItemId: json['news_item_id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: json['is_deleted'] as bool? ?? false,
      newsTitle: json['news_title'] as String?, // ⚠️ NUEVO: Desde JOIN
    );
  }

  /// ✅ TO JSON: Para enviar a Supabase
  Map<String, dynamic> toJson() {
    return {
      'bookmark_id': bookmarkId,
      'user_profile_id': userProfileId,
      'news_item_id': newsItemId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  /// ✅ COPY WITH: Para crear versiones modificadas
  Bookmark copyWith({
    int? bookmarkId,
    int? userProfileId,
    int? newsItemId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? newsTitle, // ⚠️ NUEVO
  }) {
    return Bookmark(
      bookmarkId: bookmarkId ?? this.bookmarkId,
      userProfileId: userProfileId ?? this.userProfileId,
      newsItemId: newsItemId ?? this.newsItemId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      newsTitle: newsTitle ?? this.newsTitle, // ⚠️ NUEVO
    );
  }

  /// ✅ LWW COMPARISON: Compara timestamps para resolver conflictos
  /// Retorna true si este bookmark es más reciente que el otro
  bool isNewerThan(Bookmark other) {
    return updatedAt.isAfter(other.updatedAt);
  }

  /// ✅ MERGE WITH LWW: Fusiona con otro bookmark usando Last-Write-Wins
  /// Retorna el bookmark más reciente (el que gana el conflicto)
  Bookmark mergeWith(Bookmark other) {
    if (newsItemId != other.newsItemId || userProfileId != other.userProfileId) {
      throw ArgumentError('Cannot merge bookmarks with different keys');
    }

    // Last-Write-Wins: el más reciente gana
    return isNewerThan(other) ? this : other;
  }

  @override
  String toString() {
    return 'Bookmark(id: $bookmarkId, newsId: $newsItemId, userId: $userProfileId, '
        'updated: $updatedAt, deleted: $isDeleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bookmark &&
        other.bookmarkId == bookmarkId &&
        other.userProfileId == userProfileId &&
        other.newsItemId == newsItemId;
  }

  @override
  int get hashCode {
    return Object.hash(bookmarkId, userProfileId, newsItemId);
  }
}
