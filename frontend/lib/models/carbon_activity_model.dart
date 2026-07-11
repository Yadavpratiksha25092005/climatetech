class CarbonActivityModel {
  final String id;
  final String category;
  final String subType;
  final double quantity;
  final String unit;
  final double co2Kg;
  final bool isCustom;
  final String notes;
  final DateTime recordedAt;

  CarbonActivityModel({
    required this.id,
    required this.category,
    required this.subType,
    required this.quantity,
    required this.unit,
    required this.co2Kg,
    required this.isCustom,
    required this.notes,
    required this.recordedAt,
  });

  factory CarbonActivityModel.fromJson(Map<String, dynamic> json) {
    return CarbonActivityModel(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? '',
      subType: json['sub_type'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? '',
      co2Kg: (json['co2_kg'] as num?)?.toDouble() ?? 0,
      isCustom: json['is_custom'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
      recordedAt: DateTime.tryParse(json['recorded_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class CarbonCategoryTotal {
  final String category;
  final double co2Kg;

  CarbonCategoryTotal({required this.category, required this.co2Kg});

  factory CarbonCategoryTotal.fromJson(Map<String, dynamic> json) {
    return CarbonCategoryTotal(
      category: json['category'] as String? ?? '',
      co2Kg: (json['co2_kg'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CarbonSummaryModel {
  final double todayKg;
  final double thisWeekKg;
  final double thisMonthKg;
  final double thisYearKg;
  final List<CarbonCategoryTotal> monthByCategory;

  const CarbonSummaryModel({
    required this.todayKg,
    required this.thisWeekKg,
    required this.thisMonthKg,
    required this.thisYearKg,
    required this.monthByCategory,
  });

  factory CarbonSummaryModel.fromJson(Map<String, dynamic> json) {
    final breakdown = json['month_by_category'] as List<dynamic>? ?? [];
    return CarbonSummaryModel(
      todayKg: (json['today_kg'] as num?)?.toDouble() ?? 0,
      thisWeekKg: (json['this_week_kg'] as num?)?.toDouble() ?? 0,
      thisMonthKg: (json['this_month_kg'] as num?)?.toDouble() ?? 0,
      thisYearKg: (json['this_year_kg'] as num?)?.toDouble() ?? 0,
      monthByCategory: breakdown.map((e) => CarbonCategoryTotal.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  factory CarbonSummaryModel.empty() {
    return CarbonSummaryModel(todayKg: 0, thisWeekKg: 0, thisMonthKg: 0, thisYearKg: 0, monthByCategory: const []);
  }
}

class DailyBreakdown {
  final DateTime date;
  final double totalKg;

  DailyBreakdown({required this.date, required this.totalKg});

  factory DailyBreakdown.fromJson(Map<String, dynamic> json) {
    final dateRaw = json['date'] as String?;
    return DailyBreakdown(
      date: DateTime.tryParse(dateRaw ?? '') ?? DateTime.now(),
      totalKg: (json['total_kg'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CarbonSubTypeOption {
  final String subType;
  final String unit;
  final double factorKgCo2PerUnit;

  CarbonSubTypeOption({required this.subType, required this.unit, required this.factorKgCo2PerUnit});

  factory CarbonSubTypeOption.fromJson(Map<String, dynamic> json) {
    return CarbonSubTypeOption(
      subType: json['sub_type'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      factorKgCo2PerUnit: (json['factor_kg_co2_per_unit'] as num?)?.toDouble() ?? 0,
    );
  }
}
