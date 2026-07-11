import 'package:dio/dio.dart';

import '../models/ai_summary_model.dart';
import '../models/climate_data_model.dart';
import '../models/forecast_model.dart';
import 'api_service.dart';

class ClimateException implements Exception {
  final String message;
  ClimateException(this.message);
  @override
  String toString() => message;
}

class ClimateService {
  final ApiService _api;

  ClimateService(this._api);

  Future<ClimateDataModel> getCurrentClimate({required double lat, required double lon}) async {
    try {
      final response = await _api.dio.get(
        '/climate/current',
        queryParameters: {'lat': lat, 'lon': lon},
      );
      return ClimateDataModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ClimateException(_extractError(e));
    }
  }

  Future<ForecastResult> getForecast({required double lat, required double lon, int count = 8}) async {
    try {
      final response = await _api.dio.get(
        '/climate/forecast',
        queryParameters: {'lat': lat, 'lon': lon, 'count': count},
      );
      return ForecastResult.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ClimateException(_extractError(e));
    }
  }

  Future<AISummaryModel> getAISummary() async {
    try {
      final response = await _api.dio.get('/climate/ai-summary');
      return AISummaryModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw ClimateException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not fetch climate data.';
  }
}