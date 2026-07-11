import 'package:dio/dio.dart';

import '../models/news_article_model.dart';
import 'api_service.dart';

class NewsException implements Exception {
  final String message;
  NewsException(this.message);
  @override
  String toString() => message;
}

class NewsService {
  final ApiService _api;

  NewsService(this._api);

  Future<List<NewsArticleModel>> getNews({int page = 1}) async {
    try {
      final response = await _api.dio.get('/news', queryParameters: {'page': page});
      final data = response.data['data'];
      final articles = (data is Map ? data['articles'] as List<dynamic>? : null) ?? [];
      return articles.map((e) => NewsArticleModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw NewsException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not load climate news.';
  }
}
