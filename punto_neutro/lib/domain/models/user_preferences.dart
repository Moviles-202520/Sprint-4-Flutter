// =====================================================
// Domain Model: UserPreferences
// Purpose: User preferences for app customization
// Features: Dark mode, notifications, language
// =====================================================

class UserPreferences {
  final int userProfileId;
  final bool darkMode;
  final bool notificationsEnabled;
  final String language; // ISO 639-1 code ('es', 'en', etc.)
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserPreferences({
    required this.userProfileId,
    required this.darkMode,
    required this.notificationsEnabled,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
  });

  // Copy with method for updates
  UserPreferences copyWith({
    int? userProfileId,
    bool? darkMode,
    bool? notificationsEnabled,
    String? language,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      userProfileId: userProfileId ?? this.userProfileId,
      darkMode: darkMode ?? this.darkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Factory from JSON (Supabase response)
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      userProfileId: json['user_profile_id'] as int,
      darkMode: json['dark_mode'] as bool? ?? false,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      language: json['language'] as String? ?? 'es',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // To JSON (for Supabase upsert)
  Map<String, dynamic> toJson() {
    return {
      'user_profile_id': userProfileId,
      'dark_mode': darkMode,
      'notifications_enabled': notificationsEnabled,
      'language': language,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Default preferences
  factory UserPreferences.defaultPreferences(int userProfileId) {
    final now = DateTime.now();
    return UserPreferences(
      userProfileId: userProfileId,
      darkMode: false,
      notificationsEnabled: true,
      language: 'es',
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  String toString() {
    return 'UserPreferences(userId: $userProfileId, darkMode: $darkMode, notifications: $notificationsEnabled, lang: $language)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPreferences &&
        other.userProfileId == userProfileId &&
        other.darkMode == darkMode &&
        other.notificationsEnabled == notificationsEnabled &&
        other.language == language;
  }

  @override
  int get hashCode {
    return Object.hash(
      userProfileId,
      darkMode,
      notificationsEnabled,
      language,
    );
  }
}
