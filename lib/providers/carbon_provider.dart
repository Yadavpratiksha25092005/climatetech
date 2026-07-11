import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/carbon_activity_model.dart';
import '../services/carbon_service.dart';
import 'auth_provider.dart';

final carbonServiceProvider = Provider<CarbonService>((ref) {
  return CarbonService(ref.read(apiServiceProvider));
});

enum CarbonStatus { initial, loading, loaded, error }

class CarbonState {
  final CarbonStatus status;
  final CarbonSummaryModel summary;
  final List<CarbonActivityModel> history;
  final List<DailyBreakdown> dailyBreakdown;
  final Map<String, List<CarbonSubTypeOption>> options;
  final bool isLogging;
  final String? errorMessage;

  const CarbonState({
    this.status = CarbonStatus.initial,
    this.summary = const CarbonSummaryModel(todayKg: 0, thisWeekKg: 0, thisMonthKg: 0, thisYearKg: 0, monthByCategory: []),
    this.history = const [],
    this.dailyBreakdown = const [],
    this.options = const {},
    this.isLogging = false,
    this.errorMessage,
  });

  CarbonState copyWith({
    CarbonStatus? status,
    CarbonSummaryModel? summary,
    List<CarbonActivityModel>? history,
    List<DailyBreakdown>? dailyBreakdown,
    Map<String, List<CarbonSubTypeOption>>? options,
    bool? isLogging,
    String? errorMessage,
  }) {
    return CarbonState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      history: history ?? this.history,
      dailyBreakdown: dailyBreakdown ?? this.dailyBreakdown,
      options: options ?? this.options,
      isLogging: isLogging ?? this.isLogging,
      errorMessage: errorMessage,
    );
  }
}

class CarbonNotifier extends StateNotifier<CarbonState> {
  final CarbonService _carbonService;

  // Guards against a stale load()/logActivity() refetch resolving after a
  // newer one and overwriting fresher state — same pattern as
  // ClimateNotifier's _aiSummaryRequestId. Shared between both methods since
  // they write the same summary/history/dailyBreakdown fields and can race
  // against each other (e.g. a manual refresh while a log-activity
  // submission's own refetch is still in flight).
  int _dataRequestId = 0;

  CarbonNotifier(this._carbonService) : super(const CarbonState()) {
    load();
  }

  Future<void> load() async {
    final requestId = ++_dataRequestId;
    state = state.copyWith(status: CarbonStatus.loading, errorMessage: null);
    try {
      final results = await Future.wait([
        _carbonService.getSummary(),
        _carbonService.getHistory(),
        _carbonService.getDailyBreakdown(),
        _carbonService.getOptions(),
      ]);
      if (requestId != _dataRequestId) return; // superseded by a newer request
      state = state.copyWith(
        status: CarbonStatus.loaded,
        summary: results[0] as CarbonSummaryModel,
        history: results[1] as List<CarbonActivityModel>,
        dailyBreakdown: results[2] as List<DailyBreakdown>,
        options: results[3] as Map<String, List<CarbonSubTypeOption>>,
      );
    } catch (e) {
      if (requestId != _dataRequestId) return;
      state = state.copyWith(status: CarbonStatus.error, errorMessage: e.toString());
    }
  }

  Future<bool> logActivity({
    required String category,
    required String subType,
    required double quantity,
    String? notes,
  }) async {
    state = state.copyWith(isLogging: true, errorMessage: null);
    try {
      await _carbonService.logActivity(category: category, subType: subType, quantity: quantity, notes: notes);
      final requestId = ++_dataRequestId;
      final results = await Future.wait([
        _carbonService.getSummary(),
        _carbonService.getHistory(),
        _carbonService.getDailyBreakdown(),
      ]);
      if (requestId != _dataRequestId) {
        // Superseded by a newer request — this submission still succeeded,
        // so isLogging must still resolve, just without applying stale data.
        state = state.copyWith(isLogging: false);
        return true;
      }
      state = state.copyWith(
        isLogging: false,
        summary: results[0] as CarbonSummaryModel,
        history: results[1] as List<CarbonActivityModel>,
        dailyBreakdown: results[2] as List<DailyBreakdown>,
      );
      return true;
    } on CarbonException catch (e) {
      state = state.copyWith(isLogging: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLogging: false, errorMessage: e.toString());
      return false;
    }
  }
}

final carbonProvider = StateNotifierProvider<CarbonNotifier, CarbonState>((ref) {
  return CarbonNotifier(ref.read(carbonServiceProvider));
});
