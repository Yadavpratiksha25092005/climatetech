class LeaderboardEntryModel {
  final String userId;
  final String name;
  final String? avatar;
  final int totalPoints;
  final List<String> badges;
  final int rank;

  LeaderboardEntryModel({
    required this.userId,
    required this.name,
    required this.avatar,
    required this.totalPoints,
    required this.badges,
    required this.rank,
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    final badgesJson = json['badges'] as List<dynamic>? ?? [];
    return LeaderboardEntryModel(
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String?,
      totalPoints: json['total_points'] as int? ?? 0,
      badges: badgesJson.map((e) => e as String).toList(),
      rank: json['rank'] as int? ?? 0,
    );
  }
}

class LeaderboardResult {
  final List<LeaderboardEntryModel> top;
  final LeaderboardEntryModel? yourRank;
  final bool inTopList;

  LeaderboardResult({required this.top, required this.yourRank, required this.inTopList});

  factory LeaderboardResult.fromJson(Map<String, dynamic> json) {
    final topJson = json['top'] as List<dynamic>? ?? [];
    final yourRankJson = json['your_rank'] as Map<String, dynamic>?;
    return LeaderboardResult(
      top: topJson.map((e) => LeaderboardEntryModel.fromJson(e as Map<String, dynamic>)).toList(),
      yourRank: yourRankJson != null ? LeaderboardEntryModel.fromJson(yourRankJson) : null,
      inTopList: json['in_top_list'] as bool? ?? false,
    );
  }
}
