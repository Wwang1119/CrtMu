class BackendUserAccount {
  final String id;
  final String membershipTier;

  const BackendUserAccount({required this.id, required this.membershipTier});

  factory BackendUserAccount.fromJson(Map<String, dynamic> json) {
    return BackendUserAccount(
      id: json['id']?.toString() ?? '',
      membershipTier: json['membershipTier']?.toString() ?? 'unknown',
    );
  }
}

class UserProfileSummary {
  final String userId;
  final String membershipTier;
  final int artworkCount;

  const UserProfileSummary({
    required this.userId,
    required this.membershipTier,
    required this.artworkCount,
  });

  factory UserProfileSummary.fromJson(
    Map<String, dynamic> json, {
    required String fallbackUserId,
  }) {
    final profileJson = json['profile'];
    if (profileJson is! Map) {
      throw const FormatException('Profile response missing profile payload.');
    }

    final userJson = profileJson['user'];
    final statsJson = profileJson['stats'];
    final user = userJson is Map ? userJson.cast<String, dynamic>() : null;
    final stats = statsJson is Map ? statsJson.cast<String, dynamic>() : null;

    return UserProfileSummary(
      userId: _nonEmpty(user?['id']) ?? fallbackUserId,
      membershipTier: _nonEmpty(user?['membershipTier']) ?? 'unknown',
      artworkCount: _parseInt(stats?['artworkCount']),
    );
  }

  static String? _nonEmpty(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
