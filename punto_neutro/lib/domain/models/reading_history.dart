/// Domain model for reading history entries.
/// 
/// This model tracks when and how long users read news articles.
/// By default, history is stored locally only (100% offline).
/// Optional server sync can be enabled for analytics purposes.
class ReadingHistory {
  final int? readId; // Local ID (autoincrement) or server ID
  final int? userProfileId;
  final int newsItemId;
  final int? categoryId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds; // Calculated: endedAt - startedAt
  final DateTime createdAt;

  // Local-only fields (not synced to server)
  final bool isSynced; // True if uploaded to server
  final DateTime? lastSyncAttempt;
  
  // ⚠️ NUEVO: Datos del JOIN con news_items
  final String? newsTitle;
  final String? newsImageUrl;

  const ReadingHistory({
    this.readId,
    this.userProfileId,
    required this.newsItemId,
    this.categoryId,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    required this.createdAt,
    this.isSynced = false,
    this.lastSyncAttempt,
    this.newsTitle, // ⚠️ NUEVO
    this.newsImageUrl, // ⚠️ NUEVO
  });

  /// Calculate duration in seconds from startedAt and endedAt
  int? calculateDuration() {
    if (endedAt == null) return null;
    return endedAt!.difference(startedAt).inSeconds;
  }

  /// Create a reading session that's currently in progress (no endedAt yet)
  factory ReadingHistory.startSession({
    required int newsItemId,
    int? categoryId,
    int? userProfileId,
  }) {
    final now = DateTime.now();
    return ReadingHistory(
      newsItemId: newsItemId,
      categoryId: categoryId,
      userProfileId: userProfileId,
      startedAt: now,
      createdAt: now,
      isSynced: false,
    );
  }

  /// End a reading session by adding endedAt and calculating duration
  ReadingHistory endSession(DateTime endedAt) {
    final duration = endedAt.difference(startedAt).inSeconds;
    return copyWith(
      endedAt: endedAt,
      durationSeconds: duration,
    );
  }

  /// Create from JSON (local database)
  factory ReadingHistory.fromJson(Map<String, dynamic> json) {
    return ReadingHistory(
      readId: json['read_id'] as int?,
      userProfileId: json['user_profile_id'] as int?,
      newsItemId: json['news_item_id'] as int,
      categoryId: json['category_id'] as int?,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isSynced: (json['is_synced'] as int?) == 1,
      lastSyncAttempt: json['last_sync_attempt'] != null
          ? DateTime.parse(json['last_sync_attempt'] as String)
          : null,
    );
  }

  /// Convert to JSON (for local database)
  Map<String, dynamic> toJson() {
    return {
      if (readId != null) 'read_id': readId,
      if (userProfileId != null) 'user_profile_id': userProfileId,
      'news_item_id': newsItemId,
      if (categoryId != null) 'category_id': categoryId,
      'started_at': startedAt.toIso8601String(),
      if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      if (lastSyncAttempt != null)
        'last_sync_attempt': lastSyncAttempt!.toIso8601String(),
    };
  }

  /// Convert to JSON for server upload (batch format)
  Map<String, dynamic> toServerJson() {
    return {
      if (userProfileId != null) 'user_profile_id': userProfileId,
      'news_item_id': newsItemId,
      if (categoryId != null) 'category_id': categoryId,
      'started_at': startedAt.toIso8601String(),
      if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ReadingHistory copyWith({
    int? readId,
    int? userProfileId,
    int? newsItemId,
    int? categoryId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    DateTime? createdAt,
    bool? isSynced,
    DateTime? lastSyncAttempt,
  }) {
    return ReadingHistory(
      readId: readId ?? this.readId,
      userProfileId: userProfileId ?? this.userProfileId,
      newsItemId: newsItemId ?? this.newsItemId,
      categoryId: categoryId ?? this.categoryId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
    );
  }

  @override
  String toString() {
    return 'ReadingHistory(readId: $readId, newsItemId: $newsItemId, '
        'duration: ${durationSeconds}s, synced: $isSynced)';
  }
}
