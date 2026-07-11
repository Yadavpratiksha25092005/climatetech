import 'package:dio/dio.dart';

import '../models/insights_model.dart';
import 'api_service.dart';

class InsightsException implements Exception {
  final String message;
  InsightsException(this.message);
  @override
  String toString() => message;
}

class InsightsService {
  final ApiService _api;

  InsightsService(this._api);

  Future<InsightsModel> getInsights() async {
    try {
      final response = await _api.dio.get('/insights');
      return InsightsModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw InsightsException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not load insights.';
  }
}
