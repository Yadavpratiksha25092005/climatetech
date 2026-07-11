class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatar;
  final int totalPoints;
  final List<String> badges;
  final int completedChallengesCount;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.avatar,
    this.totalPoints = 0,
    this.badges = const [],
    this.completedChallengesCount = 0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final badgesJson = json['badges'] as List<dynamic>? ?? [];
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      avatar: json['avatar'] as String?,
      totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
      badges: badgesJson.map((e) => e as String).toList(),
      // Only present on the /users/profile response, not on auth
      // login/register responses — defaults to 0 there, which is correct
      // for a fresh signup and self-corrects after the next profile refresh.
      completedChallengesCount: (json['completed_challenges_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  UserModel copyWith({String? name, String? avatar}) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      role: role,
      avatar: avatar ?? this.avatar,
      totalPoints: totalPoints,
      badges: badges,
      completedChallengesCount: completedChallengesCount,
      createdAt: createdAt,
    );
  }
}
