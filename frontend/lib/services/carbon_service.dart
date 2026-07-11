import 'package:dio/dio.dart';

import '../models/carbon_activity_model.dart';
import 'api_service.dart';

class CarbonException implements Exception {
  final String message;
  CarbonException(this.message);
  @override
  String toString() => message;
}

class CarbonService {
  final ApiService _api;

  CarbonService(this._api);

  Future<CarbonActivityModel> logActivity({
    required String category,
    required String subType,
    required double quantity,
    String? notes,
  }) async {
    try {
      final response = await _api.dio.post('/carbon/log', data: {
        'category': category,
        'sub_type': subType,
        'quantity': quantity,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      return CarbonActivityModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw CarbonException(_extractError(e));
    }
  }

  Future<List<CarbonActivityModel>> getHistory({int limit = 50}) async {
    try {
      final response = await _api.dio.get('/carbon/history', queryParameters: {'limit': limit});
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => CarbonActivityModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw CarbonException(_extractError(e));
    }
  }

  Future<CarbonSummaryModel> getSummary() async {
    try {
      final response = await _api.dio.get('/carbon/summary');
      return CarbonSummaryModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw CarbonException(_extractError(e));
    }
  }

  Future<List<DailyBreakdown>> getDailyBreakdown({int days = 7}) async {
    try {
      final response = await _api.dio.get('/carbon/daily', queryParameters: {'days': days});
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => DailyBreakdown.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw CarbonException(_extractError(e));
    }
  }

  Future<Map<String, List<CarbonSubTypeOption>>> getOptions() async {
    try {
      final response = await _api.dio.get('/carbon/options');
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      return data.map((category, subTypes) => MapEntry(
            category,
            (subTypes as List<dynamic>? ?? []).map((e) => CarbonSubTypeOption.fromJson(e as Map<String, dynamic>)).toList(),
          ));
    } on DioException catch (e) {
      throw CarbonException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not reach the carbon tracker.';
  }
}
