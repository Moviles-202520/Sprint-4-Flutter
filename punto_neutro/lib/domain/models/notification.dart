// =====================================================
// Domain Model: Notification
// Purpose: User notifications from engagement events
// Types: rating_received, comment_received, article_published, system
// Matches: notifications table from 2025-11-28_create_notifications.sql
// =====================================================

enum NotificationType {
  ratingReceived,
  commentReceived,
  articlePublished,
  system;

  static NotificationType fromString(String value) {
    switch (value) {
      case 'rating_received':
        return NotificationType.ratingReceived;
      case 'comment_received':
        return NotificationType.commentReceived;
      case 'article_published':
        return NotificationType.articlePublished;
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.system;
    }
  }

  String toValue() {
    switch (this) {
      case NotificationType.ratingReceived:
        return 'rating_received';
      case NotificationType.commentReceived:
        return 'comment_received';
      case NotificationType.articlePublished:
        return 'article_published';
      case NotificationType.system:
        return 'system';
    }
  }
}

class AppNotification {
  final int notificationId;
  final int userProfileId; // Recipient
  final int? actorUserProfileId; // Who performed the action
  final int? newsItemId;
  final NotificationType type;
  final Map<String, dynamic>? payload; // Additional data (comment text, rating value)
  final bool isRead;
  final DateTime createdAt;

  // Denormalized fields (from JOINs in queries)
  final String? actorEmail;
  final String? newsTitle;

  const AppNotification({
    required this.notificationId,
    required this.userProfileId,
    this.actorUserProfileId,
    this.newsItemId,
    required this.type,
    this.payload,
    required this.isRead,
    required this.createdAt,
    this.actorEmail,
    this.newsTitle,
  });

  // Copy with method for marking as read
  AppNotification copyWith({
    int? notificationId,
    int? userProfileId,
    int? actorUserProfileId,
    int? newsItemId,
    NotificationType? type,
    Map<String, dynamic>? payload,
    bool? isRead,
    DateTime? createdAt,
    String? actorEmail,
    String? newsTitle,
  }) {
    return AppNotification(
      notificationId: notificationId ?? this.notificationId,
      userProfileId: userProfileId ?? this.userProfileId,
      actorUserProfileId: actorUserProfileId ?? this.actorUserProfileId,
      newsItemId: newsItemId ?? this.newsItemId,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      actorEmail: actorEmail ?? this.actorEmail,
      newsTitle: newsTitle ?? this.newsTitle,
    );
  }

  // Factory from JSON (Supabase response with JOINs)
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    // Handle nested JOINs from Supabase
    final actorProfile = json['actor:user_profiles'] as Map<String, dynamic>?;
    final newsItem = json['news_items'] as Map<String, dynamic>?;

    return AppNotification(
      notificationId: json['notification_id'] as int,
      userProfileId: json['user_profile_id'] as int,
      actorUserProfileId: json['actor_user_profile_id'] as int?,
      newsItemId: json['news_item_id'] as int?,
      type: NotificationType.fromString(json['type'] as String),
      payload: json['payload'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      actorEmail: actorProfile?['user_auth_email'] as String?,
      newsTitle: newsItem?['title'] as String?,
    );
  }

  // To JSON (for updates)
  Map<String, dynamic> toJson() {
    return {
      'notification_id': notificationId,
      'user_profile_id': userProfileId,
      'actor_user_profile_id': actorUserProfileId,
      'news_item_id': newsItemId,
      'type': type.toValue(),
      'payload': payload,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Get display message based on type
  String getMessage() {
    switch (type) {
      case NotificationType.ratingReceived:
        final actorName = actorEmail?.split('@').first ?? 'Alguien';
        return '$actorName calificó tu noticia';
      case NotificationType.commentReceived:
        final actorName = actorEmail?.split('@').first ?? 'Alguien';
        return '$actorName comentó en tu noticia';
      case NotificationType.articlePublished:
        return 'Tu artículo fue publicado';
      case NotificationType.system:
        return payload?['message'] as String? ?? 'Notificación del sistema';
    }
  }

  // Get subtitle/preview
  String? getPreview() {
    switch (type) {
      case NotificationType.ratingReceived:
        final score = payload?['rating_score'];
        return score != null ? 'Puntuación: ${(score * 100).toStringAsFixed(0)}%' : null;
      case NotificationType.commentReceived:
        final preview = payload?['comment_preview'] as String?;
        return preview;
      case NotificationType.articlePublished:
        return newsTitle;
      case NotificationType.system:
        return null;
    }
  }

  // Get time ago string
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 7) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Ahora mismo';
    }
  }

  @override
  String toString() {
    return 'AppNotification(id: $notificationId, type: ${type.toValue()}, read: $isRead)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNotification && other.notificationId == notificationId;
  }

  @override
  int get hashCode => notificationId.hashCode;
}

