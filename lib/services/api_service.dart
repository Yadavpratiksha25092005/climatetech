import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/api_constants.dart';
import 'storage_service.dart';

class ApiService {
  final Dio dio;
  final StorageService _storage;

  ApiService(this._storage)
      : dio = Dio(BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        )) {
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
    }
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getAccessToken();
          if (token != null && !options.path.contains('/auth/')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final isRetry = error.requestOptions.extra['retried'] == true;

          if (isUnauthorized && !isRetry) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final opts = error.requestOptions;
              opts.extra['retried'] = true;
              final newToken = await _storage.getAccessToken();
              opts.headers['Authorization'] = 'Bearer $newToken';
              try {
                final response = await dio.fetch(opts);
                return handler.resolve(response);
              } catch (_) {
                // fall through to original error
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  // Multiple requests can 401 at nearly the same moment (e.g. every provider
  // firing its first request on cold start); without this, each one would
  // independently call the refresh endpoint. Concurrent callers instead all
  // await the same in-flight Future, so only one refresh call ever happens
  // at a time — matching the isRefreshing/queue pattern the admin panel's
  // client.js already uses for the same problem.
  Future<bool>? _refreshFuture;

  Future<bool> _tryRefreshToken() {
    return _refreshFuture ??= _performRefresh().whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final response = await Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      )).post(
        ApiConstants.refresh,
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      final newAccessToken = data is Map && data['data'] is Map ? data['data']['access_token'] as String? : null;
      if (newAccessToken == null) {
        await _storage.clear();
        return false;
      }
      await _storage.saveAccessToken(newAccessToken);
      return true;
    } catch (_) {
      await _storage.clear();
      return false;
    }
  }
}
