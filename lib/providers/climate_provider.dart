import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_summary_model.dart';
import '../models/climate_data_model.dart';
import '../models/forecast_model.dart';
import '../services/climate_service.dart';
import '../services/location_service.dart';
import 'auth_provider.dart';

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final climateServiceProvider = Provider<ClimateService>((ref) {
  return ClimateService(ref.read(apiServiceProvider));
});

enum ClimateStatus { initial, loading, loaded, error }

enum AISummaryStatus { initial, loading, loaded, error }

class ClimateState {
  final ClimateStatus status;
  final ClimateDataModel? data;
  final List<ForecastItem> forecast;
  final String? errorMessage;
  final AISummaryStatus aiSummaryStatus;
  final AISummaryModel? aiSummary;

  const ClimateState({
    this.status = ClimateStatus.initial,
    this.data,
    this.forecast = const [],
    this.errorMessage,
    this.aiSummaryStatus = AISummaryStatus.initial,
    this.aiSummary,
  });

  ClimateState copyWith({
    ClimateStatus? status,
    ClimateDataModel? data,
    List<ForecastItem>? forecast,
    String? errorMessage,
    AISummaryStatus? aiSummaryStatus,
    AISummaryModel? aiSummary,
  }) {
    return ClimateState(
      status: status ?? this.status,
      data: data ?? this.data,
      forecast: forecast ?? this.forecast,
      errorMessage: errorMessage,
      aiSummaryStatus: aiSummaryStatus ?? this.aiSummaryStatus,
      aiSummary: aiSummary ?? this.aiSummary,
    );
  }
}

class ClimateNotifier extends StateNotifier<ClimateState> {
  final ClimateService _climateService;
  final LocationService _locationService;

  // Guards against a stale AI-summary request resolving after a newer one
  // (e.g. a pull-to-refresh fired while the previous request was in flight)
  // and overwriting fresher state.
  int _aiSummaryRequestId = 0;

  ClimateNotifier(this._climateService, this._locationService) : super(const ClimateState()) {
    loadClimate();
  }

  Future<void> loadClimate() async {
    state = state.copyWith(status: ClimateStatus.loading, errorMessage: null);
    try {
      final position = await _locationService.getCurrentLocation();

      final data = await _climateService.getCurrentClimate(lat: position.latitude, lon: position.longitude);

      List<ForecastItem> forecastItems = [];
      try {
        final forecastResult = await _climateService.getForecast(lat: position.latitude, lon: position.longitude);
        forecastItems = forecastResult.items;
      } catch (_) {
        // Forecast is a bonus — don't fail the whole dashboard if only this call fails.
      }

      state = state.copyWith(status: ClimateStatus.loaded, data: data, forecast: forecastItems);

      // Secondary, non-blocking step: the main weather display is already up,
      // so the AI summary loads in the background without holding it up.
      unawaited(_loadAISummary());
    } catch (e) {
      state = state.copyWith(status: ClimateStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> _loadAISummary() async {
    final requestId = ++_aiSummaryRequestId;
    state = state.copyWith(aiSummaryStatus: AISummaryStatus.loading);
    try {
      final summary = await _climateService.getAISummary();
      if (requestId != _aiSummaryRequestId) return; // superseded by a newer request
      state = state.copyWith(aiSummaryStatus: AISummaryStatus.loaded, aiSummary: summary);
    } catch (_) {
      if (requestId != _aiSummaryRequestId) return;
      state = state.copyWith(aiSummaryStatus: AISummaryStatus.error);
    }
  }
}

final climateProvider = StateNotifierProvider<ClimateNotifier, ClimateState>((ref) {
  return ClimateNotifier(ref.read(climateServiceProvider), ref.read(locationServiceProvider));
});