// =====================================================
// Domain Model: FavoriteCategory
// Purpose: User's favorite categories for feed personalization
// =====================================================

class FavoriteCategory {
  final int userProfileId;
  final int categoryId;
  final String categoryName; // Denormalized for UI
  final DateTime createdAt;

  const FavoriteCategory({
    required this.userProfileId,
    required this.categoryId,
    required this.categoryName,
    required this.createdAt,
  });

  // Factory from JSON (Supabase response with JOIN)
  factory FavoriteCategory.fromJson(Map<String, dynamic> json) {
    return FavoriteCategory(
      userProfileId: json['user_profile_id'] as int,
      categoryId: json['category_id'] as int,
      categoryName: json['category_name'] as String? ?? 'Unknown',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // To JSON (for Supabase insert)
  Map<String, dynamic> toJson() {
    return {
      'user_profile_id': userProfileId,
      'category_id': categoryId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'FavoriteCategory(userId: $userProfileId, category: $categoryName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FavoriteCategory &&
        other.userProfileId == userProfileId &&
        other.categoryId == categoryId;
  }

  @override
  int get hashCode => Object.hash(userProfileId, categoryId);
}
