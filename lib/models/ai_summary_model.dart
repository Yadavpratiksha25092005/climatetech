class AISummaryModel {
  final String weatherSummary;
  final String activitySuggestion;
  final String source;

  AISummaryModel({
    required this.weatherSummary,
    required this.activitySuggestion,
    required this.source,
  });

  bool get isAiGenerated => source == 'ai';

  factory AISummaryModel.fromJson(Map<String, dynamic> json) {
    return AISummaryModel(
      weatherSummary: json['weather_summary'] as String? ?? '',
      activitySuggestion: json['activity_suggestion'] as String? ?? '',
      source: json['source'] as String? ?? 'rule_based',
    );
  }
}
