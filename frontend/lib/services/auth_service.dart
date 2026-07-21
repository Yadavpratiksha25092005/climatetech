import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthResult {
  final UserModel user;
  AuthResult(this.user);
}

class AuthService {
  final ApiService _api;
  final StorageService _storage;

  AuthService(this._api, this._storage);

  Future<AuthResult> register({
    required String name,
    required String phone,
    required String password,
    String role = 'user',
  }) async {
    try {
      final response = await _api.dio.post(ApiConstants.register, data: {
        'name': name,
        'phone': phone,
        'password': password,
        'role': role,
      });
      return _handleAuthResponse(response.data['data']);
    } on DioException catch (e) {
      throw AuthException(_extractError(e));
    }
  }

  Future<AuthResult> login({required String phone, required String password}) async {
    try {
      final response = await _api.dio.post(ApiConstants.login, data: {
        'phone': phone,
        'password': password,
      });
      return _handleAuthResponse(response.data['data']);
    } on DioException catch (e) {
      throw AuthException(_extractError(e));
    }
  }

  Future<void> logout() async {
    try {
      await _api.dio.post(ApiConstants.logout);
    } catch (_) {
      // best-effort; proceed to clear local session regardless
    } finally {
      await _storage.clear();
    }
  }

  Future<UserModel> fetchProfile() async {
    try {
      final response = await _api.dio.get(ApiConstants.profile);
      final data = response.data['data'];
      if (data is! Map<String, dynamic>) {
        throw AuthException('Unexpected response from server.');
      }
      return UserModel.fromJson(data);
    } on DioException catch (e) {
      throw AuthException(_extractError(e));
    }
  }

  Future<UserModel> updateProfile({String? name, String? avatar}) async {
    try {
      final response = await _api.dio.put(ApiConstants.profile, data: {
        if (name != null) 'name': name,
        if (avatar != null) 'avatar': avatar,
      });
      final data = response.data['data'];
      if (data is! Map<String, dynamic>) {
        throw AuthException('Unexpected response from server.');
      }
      return UserModel.fromJson(data);
    } on DioException catch (e) {
      throw AuthException(_extractError(e));
    }
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    try {
      await _api.dio.put(ApiConstants.changePassword, data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      throw AuthException(_extractError(e));
    }
  }

  Future<AuthResult> _handleAuthResponse(dynamic data) async {
    if (data is! Map<String, dynamic>) {
      throw AuthException('Unexpected response from server.');
    }
    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    if (accessToken == null || refreshToken == null) {
      throw AuthException('Unexpected response from server.');
    }
    await _storage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    final userJson = data['user'];
    if (userJson is! Map<String, dynamic>) {
      throw AuthException('Unexpected response from server.');
    }
    final user = UserModel.fromJson(userJson);
    return AuthResult(user);
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Something went wrong. Please try again.';
  }
}
