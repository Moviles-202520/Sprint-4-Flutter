/// Domain model for news upload queue entries.
/// 
/// This model tracks news articles that are pending upload to the server.
/// It supports retry logic with exponential backoff.
class UploadQueueEntry {
  final int? queueId; // Local ID (autoincrement)
  final int draftId; // Reference to NewsDraft
  final String idempotencyKey; // UUID for server-side deduplication
  final UploadStatus status;
  final int retryCount;
  final DateTime? lastAttemptAt;
  final DateTime? nextRetryAt; // Calculated based on exponential backoff
  final String? uploadError;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UploadQueueEntry({
    this.queueId,
    required this.draftId,
    required this.idempotencyKey,
    this.status = UploadStatus.pending,
    this.retryCount = 0,
    this.lastAttemptAt,
    this.nextRetryAt,
    this.uploadError,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new upload queue entry for a draft
  factory UploadQueueEntry.forDraft(int draftId, String idempotencyKey) {
    final now = DateTime.now();
    return UploadQueueEntry(
      draftId: draftId,
      idempotencyKey: idempotencyKey,
      createdAt: now,
      updatedAt: now,
      status: UploadStatus.pending,
    );
  }

  /// Check if entry is ready to retry (based on nextRetryAt)
  bool get isReadyToRetry {
    if (status != UploadStatus.failed) return false;
    if (nextRetryAt == null) return true;
    return DateTime.now().isAfter(nextRetryAt!);
  }

  /// Check if max retries exceeded (e.g., 5 attempts)
  bool get maxRetriesExceeded {
    return retryCount >= 5;
  }

  /// Calculate next retry time using exponential backoff
  /// Backoff: 2s, 4s, 8s, 16s, 32s (capped at 32s)
  DateTime calculateNextRetryTime() {
    final baseDelay = 2; // 2 seconds
    final maxDelay = 32; // 32 seconds cap
    final delay = (baseDelay * (1 << retryCount)).clamp(baseDelay, maxDelay);
    return DateTime.now().add(Duration(seconds: delay));
  }

  /// Mark as failed with error and schedule retry
  UploadQueueEntry markAsFailed(String error) {
    return copyWith(
      status: UploadStatus.failed,
      uploadError: error,
      retryCount: retryCount + 1,
      lastAttemptAt: DateTime.now(),
      nextRetryAt: calculateNextRetryTime(),
      updatedAt: DateTime.now(),
    );
  }

  /// Mark as uploading
  UploadQueueEntry markAsUploading() {
    return copyWith(
      status: UploadStatus.uploading,
      lastAttemptAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Mark as completed
  UploadQueueEntry markAsCompleted() {
    return copyWith(
      status: UploadStatus.completed,
      uploadError: null,
      updatedAt: DateTime.now(),
    );
  }

  factory UploadQueueEntry.fromJson(Map<String, dynamic> json) {
    return UploadQueueEntry(
      queueId: json['queue_id'] as int?,
      draftId: json['draft_id'] as int,
      idempotencyKey: json['idempotency_key'] as String,
      status: UploadStatus.values.byName(json['status'] as String),
      retryCount: json['retry_count'] as int? ?? 0,
      lastAttemptAt: json['last_attempt_at'] != null
          ? DateTime.parse(json['last_attempt_at'] as String)
          : null,
      nextRetryAt: json['next_retry_at'] != null
          ? DateTime.parse(json['next_retry_at'] as String)
          : null,
      uploadError: json['upload_error'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (queueId != null) 'queue_id': queueId,
      'draft_id': draftId,
      'idempotency_key': idempotencyKey,
      'status': status.name,
      'retry_count': retryCount,
      if (lastAttemptAt != null)
        'last_attempt_at': lastAttemptAt!.toIso8601String(),
      if (nextRetryAt != null)
        'next_retry_at': nextRetryAt!.toIso8601String(),
      'upload_error': uploadError,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UploadQueueEntry copyWith({
    int? queueId,
    int? draftId,
    String? idempotencyKey,
    UploadStatus? status,
    int? retryCount,
    DateTime? lastAttemptAt,
    DateTime? nextRetryAt,
    String? uploadError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UploadQueueEntry(
      queueId: queueId ?? this.queueId,
      draftId: draftId ?? this.draftId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      uploadError: uploadError ?? this.uploadError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UploadQueueEntry(id: $queueId, draftId: $draftId, status: $status, retries: $retryCount)';
  }
}

/// Status of upload queue entry
enum UploadStatus {
  pending, // Not yet uploaded
  uploading, // Currently uploading
  completed, // Successfully uploaded
  failed, // Upload failed (will retry)
  cancelled, // User cancelled upload
}
