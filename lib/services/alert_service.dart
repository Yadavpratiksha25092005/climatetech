import 'package:dio/dio.dart';

import '../models/alert_model.dart';
import 'api_service.dart';

class AlertException implements Exception {
  final String message;
  AlertException(this.message);
  @override
  String toString() => message;
}

class AlertService {
  final ApiService _api;

  AlertService(this._api);

  Future<List<AlertModel>> getAlertHistory({int limit = 50}) async {
    try {
      final response = await _api.dio.get('/alerts/history', queryParameters: {'limit': limit});
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => AlertModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw AlertException(_extractError(e));
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _api.dio.get('/alerts/unread-count');
      final data = response.data['data'];
      return (data is Map ? data['count'] as int? : null) ?? 0;
    } on DioException catch (e) {
      throw AlertException(_extractError(e));
    }
  }

  Future<void> markAsRead(String alertId) async {
    try {
      await _api.dio.put('/alerts/$alertId/read');
    } on DioException catch (e) {
      throw AlertException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not load alerts.';
  }
}
