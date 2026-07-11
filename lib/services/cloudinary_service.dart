import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CloudinaryException implements Exception {
  final String message;
  CloudinaryException(this.message);
  @override
  String toString() => message;
}

/// Uploads images directly to Cloudinary using an unsigned upload preset —
/// deliberately a bare Dio instance with no base URL or auth interceptors,
/// since this talks to a third-party host and must never carry this app's
/// own backend Bearer token.
class CloudinaryService {
  static const String _cloudName = 'da7gbpujc';
  static const String _uploadPreset = 'climatetech_marketplace';
  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  final Dio _dio = Dio();

  Future<String> uploadImage(File file) async {
    try {
      final formData = FormData.fromMap({
        'upload_preset': _uploadPreset,
        'file': await MultipartFile.fromFile(file.path,
            filename: file.uri.pathSegments.last),
      });

      final response = await _dio.post(_uploadUrl, data: formData);

      final secureUrl =
          response.data is Map ? response.data['secure_url'] as String? : null;
      if (secureUrl == null || secureUrl.isEmpty) {
        throw CloudinaryException('Cloudinary did not return an image URL.');
      }
      return secureUrl;
    } on DioException catch (e) {
      throw CloudinaryException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map &&
        data['error'] is Map &&
        data['error']['message'] != null) {
      return data['error']['message'].toString();
    }
    return e.message ?? 'Could not upload image.';
  }
}

final cloudinaryServiceProvider =
    Provider<CloudinaryService>((ref) => CloudinaryService());
