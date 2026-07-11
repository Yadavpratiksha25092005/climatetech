class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final String benefitInfo;
  final String category;
  final String iconHint;
  final int pointsPerCheckIn;
  final int durationDays;
  final bool isActive;
  final bool joined;
  final int totalCheckIns;
  final String status;
  final bool checkedInToday;
  final String? personalizedBenefit;
  final String source;

  ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.benefitInfo,
    required this.category,
    required this.iconHint,
    required this.pointsPerCheckIn,
    required this.durationDays,
    required this.isActive,
    required this.joined,
    required this.totalCheckIns,
    required this.status,
    required this.checkedInToday,
    this.personalizedBenefit,
    this.source = 'rule_based',
  });

  bool get isCompleted => status == 'completed';

  /// The benefit text to show — the AI-personalized one when present, else
  /// the static [benefitInfo].
  String get displayBenefit => personalizedBenefit ?? benefitInfo;

  bool get isAiPersonalized => personalizedBenefit != null && source == 'ai';

  ChallengeModel copyWith({
    bool? joined,
    int? totalCheckIns,
    String? status,
    bool? checkedInToday,
  }) {
    return ChallengeModel(
      id: id,
      title: title,
      description: description,
      benefitInfo: benefitInfo,
      category: category,
      iconHint: iconHint,
      pointsPerCheckIn: pointsPerCheckIn,
      durationDays: durationDays,
      isActive: isActive,
      joined: joined ?? this.joined,
      totalCheckIns: totalCheckIns ?? this.totalCheckIns,
      status: status ?? this.status,
      checkedInToday: checkedInToday ?? this.checkedInToday,
      personalizedBenefit: personalizedBenefit,
      source: source,
    );
  }

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    return ChallengeModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      benefitInfo: json['benefit_info'] as String? ?? '',
      category: json['category'] as String? ?? '',
      iconHint: json['icon_hint'] as String? ?? '',
      pointsPerCheckIn: json['points_per_check_in'] as int? ?? 0,
      durationDays: json['duration_days'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      joined: json['joined'] as bool? ?? false,
      totalCheckIns: json['total_check_ins'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      checkedInToday: json['checked_in_today'] as bool? ?? false,
      personalizedBenefit: json['personalized_benefit'] as String?,
      source: json['source'] as String? ?? 'rule_based',
    );
  }
}
