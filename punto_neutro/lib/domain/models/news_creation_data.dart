// =====================================================
// Domain Model: News Creation/Draft
// Purpose: Model for creating and editing news items
// Status: draft, published
// =====================================================

class NewsCreationData {
  final String? newsItemId; // null for new news, set for editing
  final String title;
  final String shortDescription;
  final String longDescription;
  final String categoryId;
  final String? imageUrl;
  final String? originalSourceUrl;
  final String authorType; // 'citizen', 'journalist', 'institution'
  final String authorInstitution;
  final bool isDraft; // true = draft, false = published
  final DateTime? publicationDate; // null for drafts, set on publish

  const NewsCreationData({
    this.newsItemId,
    required this.title,
    required this.shortDescription,
    required this.longDescription,
    required this.categoryId,
    this.imageUrl,
    this.originalSourceUrl,
    this.authorType = 'citizen',
    this.authorInstitution = '',
    this.isDraft = true,
    this.publicationDate,
  });

  /// Validation
  bool get isValid {
    return title.trim().isNotEmpty &&
        shortDescription.trim().isNotEmpty &&
        longDescription.trim().isNotEmpty &&
        categoryId.isNotEmpty;
  }

  String? get validationError {
    if (title.trim().isEmpty) return 'El título es requerido';
    if (title.length < 10) return 'El título debe tener al menos 10 caracteres';
    if (shortDescription.trim().isEmpty) return 'La descripción corta es requerida';
    if (shortDescription.length < 20) return 'La descripción corta debe tener al menos 20 caracteres';
    if (longDescription.trim().isEmpty) return 'El contenido completo es requerido';
    if (longDescription.length < 100) return 'El contenido debe tener al menos 100 caracteres';
    if (categoryId.isEmpty) return 'Debes seleccionar una categoría';
    return null;
  }

  /// Copy with method
  NewsCreationData copyWith({
    String? newsItemId,
    String? title,
    String? shortDescription,
    String? longDescription,
    String? categoryId,
    String? imageUrl,
    String? originalSourceUrl,
    String? authorType,
    String? authorInstitution,
    bool? isDraft,
    DateTime? publicationDate,
  }) {
    return NewsCreationData(
      newsItemId: newsItemId ?? this.newsItemId,
      title: title ?? this.title,
      shortDescription: shortDescription ?? this.shortDescription,
      longDescription: longDescription ?? this.longDescription,
      categoryId: categoryId ?? this.categoryId,
      imageUrl: imageUrl ?? this.imageUrl,
      originalSourceUrl: originalSourceUrl ?? this.originalSourceUrl,
      authorType: authorType ?? this.authorType,
      authorInstitution: authorInstitution ?? this.authorInstitution,
      isDraft: isDraft ?? this.isDraft,
      publicationDate: publicationDate ?? this.publicationDate,
    );
  }

  /// To JSON for Supabase insert/update
  Map<String, dynamic> toJson(String userProfileId) {
    final json = <String, dynamic>{
      'user_profile_id': userProfileId,
      'title': title.trim(),
      'short_description': shortDescription.trim(),
      'long_description': longDescription.trim(),
      'category_id': categoryId,
      'author_type': authorType,
      'author_institution': authorInstitution,
      'is_fake': false, // Default values for new news
      'is_verified_source': false,
      'is_verified_data': false,
      'is_recognized_author': false,
      'is_manipulated': false,
    };

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      json['image_url'] = imageUrl;
    }

    if (originalSourceUrl != null && originalSourceUrl!.isNotEmpty) {
      json['original_source_url'] = originalSourceUrl;
    }

    // Set publication date when publishing
    if (!isDraft && publicationDate != null) {
      json['publication_date'] = publicationDate!.toIso8601String();
    }

    // For updates, include the ID
    if (newsItemId != null) {
      json['news_item_id'] = newsItemId;
    }

    return json;
  }

  /// Create empty draft
  factory NewsCreationData.empty() {
    return const NewsCreationData(
      title: '',
      shortDescription: '',
      longDescription: '',
      categoryId: '',
      isDraft: true,
    );
  }

  @override
  String toString() {
    return 'NewsCreationData(title: "$title", category: $categoryId, isDraft: $isDraft)';
  }
}
