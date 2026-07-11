import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/insights_model.dart';
import '../services/insights_service.dart';
import 'auth_provider.dart';

final insightsServiceProvider = Provider<InsightsService>((ref) {
  return InsightsService(ref.read(apiServiceProvider));
});

enum InsightsStatus { initial, loading, loaded, error }

class InsightsState {
  final InsightsStatus status;
  final InsightsModel? data;
  final String? errorMessage;

  const InsightsState({
    this.status = InsightsStatus.initial,
    this.data,
    this.errorMessage,
  });

  InsightsState copyWith({
    InsightsStatus? status,
    InsightsModel? data,
    String? errorMessage,
  }) {
    return InsightsState(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: errorMessage,
    );
  }
}

class InsightsNotifier extends StateNotifier<InsightsState> {
  final InsightsService _insightsService;

  InsightsNotifier(this._insightsService) : super(const InsightsState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(status: InsightsStatus.loading, errorMessage: null);
    try {
      final data = await _insightsService.getInsights();
      state = state.copyWith(status: InsightsStatus.loaded, data: data);
    } catch (e) {
      state = state.copyWith(status: InsightsStatus.error, errorMessage: e.toString());
    }
  }
}

final insightsProvider = StateNotifierProvider<InsightsNotifier, InsightsState>((ref) {
  return InsightsNotifier(ref.read(insightsServiceProvider));
});
