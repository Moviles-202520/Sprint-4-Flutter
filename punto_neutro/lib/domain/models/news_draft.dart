/// Domain model for news article drafts.
/// 
/// This model represents a news article being created by the user.
/// Drafts are automatically saved to local storage periodically and can be
/// resumed after app restart.
/// 
/// Features:
/// - Autosave every X seconds (default 10s)
/// - Multiple image attachments with processing status
/// - Resume after app restart
/// - Upload queue integration (pending uploads tracked)
class NewsDraft {
  final int? draftId; // Local ID (autoincrement)
  final String? title;
  final String? content;
  final int? categoryId;
  final String? sourceUrl; // Optional: if user is sharing found content
  final List<DraftImage> images;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DraftStatus status;
  final String? uploadError; // Error message if upload failed

  const NewsDraft({
    this.draftId,
    this.title,
    this.content,
    this.categoryId,
    this.sourceUrl,
    this.images = const [],
    required this.createdAt,
    required this.updatedAt,
    this.status = DraftStatus.editing,
    this.uploadError,
  });

  /// Create a new empty draft
  factory NewsDraft.empty() {
    final now = DateTime.now();
    return NewsDraft(
      createdAt: now,
      updatedAt: now,
      status: DraftStatus.editing,
    );
  }

  /// Check if draft is empty (no meaningful content)
  bool get isEmpty {
    return (title == null || title!.trim().isEmpty) &&
        (content == null || content!.trim().isEmpty) &&
        images.isEmpty;
  }

  /// Check if draft is valid for publishing
  bool get isValid {
    return title != null &&
        title!.trim().isNotEmpty &&
        content != null &&
        content!.trim().isNotEmpty &&
        categoryId != null;
  }

  /// Check if all images are processed and ready
  bool get areImagesReady {
    return images.every((img) => img.isProcessed);
  }

  /// Check if draft is ready to upload
  bool get isReadyToUpload {
    return isValid && areImagesReady && status != DraftStatus.uploading;
  }

  /// Create from JSON (local database)
  factory NewsDraft.fromJson(Map<String, dynamic> json) {
    return NewsDraft(
      draftId: json['draft_id'] as int?,
      title: json['title'] as String?,
      content: json['content'] as String?,
      categoryId: json['category_id'] as int?,
      sourceUrl: json['source_url'] as String?,
      images: json['images'] != null
          ? (json['images'] as List)
              .map((img) => DraftImage.fromJson(img as Map<String, dynamic>))
              .toList()
          : [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      status: DraftStatus.values.byName(json['status'] as String),
      uploadError: json['upload_error'] as String?,
    );
  }

  /// Convert to JSON (for local database)
  Map<String, dynamic> toJson() {
    return {
      if (draftId != null) 'draft_id': draftId,
      'title': title,
      'content': content,
      'category_id': categoryId,
      'source_url': sourceUrl,
      'images': images.map((img) => img.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'status': status.name,
      'upload_error': uploadError,
    };
  }

  NewsDraft copyWith({
    int? draftId,
    String? title,
    String? content,
    int? categoryId,
    String? sourceUrl,
    List<DraftImage>? images,
    DateTime? createdAt,
    DateTime? updatedAt,
    DraftStatus? status,
    String? uploadError,
  }) {
    return NewsDraft(
      draftId: draftId ?? this.draftId,
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: categoryId ?? this.categoryId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      uploadError: uploadError ?? this.uploadError,
    );
  }

  @override
  String toString() {
    return 'NewsDraft(id: $draftId, title: $title, status: $status, images: ${images.length})';
  }
}

/// Status of a draft
enum DraftStatus {
  editing, // User is actively editing
  saved, // Auto-saved successfully
  uploading, // Currently uploading to server
  uploaded, // Successfully uploaded to server
  failed, // Upload failed (can retry)
}

/// Represents an image attachment in a draft
class DraftImage {
  final String localPath; // Path to original image on device
  final String? compressedPath; // Path to compressed version
  final String? thumbnailPath; // Path to thumbnail
  final ImageProcessingStatus processingStatus;
  final int? originalSizeBytes;
  final int? compressedSizeBytes;
  final String? processingError;

  const DraftImage({
    required this.localPath,
    this.compressedPath,
    this.thumbnailPath,
    this.processingStatus = ImageProcessingStatus.pending,
    this.originalSizeBytes,
    this.compressedSizeBytes,
    this.processingError,
  });

  /// Check if image is fully processed and ready to upload
  bool get isProcessed {
    return processingStatus == ImageProcessingStatus.completed &&
        compressedPath != null;
  }

  /// Calculate compression ratio (0-100%)
  int? get compressionRatio {
    if (originalSizeBytes == null || compressedSizeBytes == null) return null;
    return ((1 - (compressedSizeBytes! / originalSizeBytes!)) * 100).round();
  }

  factory DraftImage.fromJson(Map<String, dynamic> json) {
    return DraftImage(
      localPath: json['local_path'] as String,
      compressedPath: json['compressed_path'] as String?,
      thumbnailPath: json['thumbnail_path'] as String?,
      processingStatus: ImageProcessingStatus.values
          .byName(json['processing_status'] as String),
      originalSizeBytes: json['original_size_bytes'] as int?,
      compressedSizeBytes: json['compressed_size_bytes'] as int?,
      processingError: json['processing_error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'local_path': localPath,
      'compressed_path': compressedPath,
      'thumbnail_path': thumbnailPath,
      'processing_status': processingStatus.name,
      'original_size_bytes': originalSizeBytes,
      'compressed_size_bytes': compressedSizeBytes,
      'processing_error': processingError,
    };
  }

  DraftImage copyWith({
    String? localPath,
    String? compressedPath,
    String? thumbnailPath,
    ImageProcessingStatus? processingStatus,
    int? originalSizeBytes,
    int? compressedSizeBytes,
    String? processingError,
  }) {
    return DraftImage(
      localPath: localPath ?? this.localPath,
      compressedPath: compressedPath ?? this.compressedPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      processingStatus: processingStatus ?? this.processingStatus,
      originalSizeBytes: originalSizeBytes ?? this.originalSizeBytes,
      compressedSizeBytes: compressedSizeBytes ?? this.compressedSizeBytes,
      processingError: processingError ?? this.processingError,
    );
  }
}

/// Status of image processing
enum ImageProcessingStatus {
  pending, // Not yet processed
  processing, // Currently being compressed/thumbnailed
  completed, // Successfully processed
  failed, // Processing failed
}
