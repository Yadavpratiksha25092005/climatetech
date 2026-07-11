import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'api_service.dart';

class ReportException implements Exception {
  final String message;
  ReportException(this.message);
  @override
  String toString() => message;
}

class ReportsService {
  final ApiService _api;
  ReportsService(this._api);

  Future<Uint8List> generateReport({String period = 'week'}) async {
    try {
      final response = await _api.dio.get<List<int>>(
        '/reports/generate',
        queryParameters: {'period': period},
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null || data.isEmpty) {
        throw ReportException('No report data received.');
      }
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      throw ReportException(_extractError(e));
    }
  }

  /// With [ResponseType.bytes], even a failed request's body comes back as
  /// raw bytes rather than an auto-parsed JSON map, so the backend's
  /// {"message": ...} error body has to be decoded manually here.
  String _extractError(DioException e) {
    final raw = e.response?.data;
    if (raw is List<int>) {
      try {
        final decoded = jsonDecode(utf8.decode(raw));
        if (decoded is Map && decoded['message'] != null) {
          return decoded['message'].toString();
        }
      } catch (_) {
        // fall through to the generic message below
      }
    }
    return e.message ?? 'Could not generate the report.';
  }
}

final reportsServiceProvider = Provider<ReportsService>((ref) {
  return ReportsService(ref.read(apiServiceProvider));
});
