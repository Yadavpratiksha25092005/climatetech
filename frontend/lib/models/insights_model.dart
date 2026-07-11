class InsightRecommendation {
  final String iconHint;
  final String title;
  final String message;

  InsightRecommendation({required this.iconHint, required this.title, required this.message});

  factory InsightRecommendation.fromJson(Map<String, dynamic> json) {
    return InsightRecommendation(
      iconHint: json['icon_hint'] as String? ?? 'start',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

class InsightsModel {
  final int score;
  final double weeklyCo2Kg;
  final double weeklyTrendPercent;
  final double monthlyProjectedKg;
  final String highestCategory;
  final int aqi;
  final double temperature;
  final List<InsightRecommendation> recommendations;
  final String source;

  InsightsModel({
    required this.score,
    required this.weeklyCo2Kg,
    required this.weeklyTrendPercent,
    required this.monthlyProjectedKg,
    required this.highestCategory,
    required this.aqi,
    required this.temperature,
    required this.recommendations,
    required this.source,
  });

  bool get isAiGenerated => source == 'ai';

  factory InsightsModel.fromJson(Map<String, dynamic> json) {
    final recs = json['recommendations'] as List<dynamic>? ?? [];
    return InsightsModel(
      score: json['score'] as int? ?? 0,
      weeklyCo2Kg: (json['weekly_co2_kg'] as num?)?.toDouble() ?? 0,
      weeklyTrendPercent: (json['weekly_trend_percent'] as num?)?.toDouble() ?? 0,
      monthlyProjectedKg: (json['monthly_projected_kg'] as num?)?.toDouble() ?? 0,
      highestCategory: json['highest_category'] as String? ?? '',
      aqi: json['aqi'] as int? ?? 0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      recommendations: recs.map((e) => InsightRecommendation.fromJson(e as Map<String, dynamic>)).toList(),
      source: json['source'] as String? ?? 'rule_based',
    );
  }
}
