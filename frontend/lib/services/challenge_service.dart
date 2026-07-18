import 'package:dio/dio.dart';

import '../models/challenge_model.dart';
import '../models/leaderboard_entry_model.dart';
import 'api_service.dart';

class ChallengeException implements Exception {
  final String message;
  ChallengeException(this.message);
  @override
  String toString() => message;
}

class ChallengeService {
  final ApiService _api;

  ChallengeService(this._api);

  Future<List<ChallengeModel>> getChallenges() async {
    try {
      final response = await _api.dio.get('/challenges');
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => ChallengeModel.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ChallengeException(_extractError(e));
    }
  }

  Future<void> joinChallenge(String id) async {
    try {
      await _api.dio.post('/challenges/$id/join');
    } on DioException catch (e) {
      throw ChallengeException(_extractError(e));
    }
  }

  Future<Map<String, dynamic>> checkIn(String id) async {
    try {
      final response = await _api.dio.post('/challenges/$id/checkin');
      return response.data['data'] as Map<String, dynamic>? ?? {};
    } on DioException catch (e) {
      throw ChallengeException(_extractError(e));
    }
  }

  Future<LeaderboardResult> getLeaderboard({int limit = 20}) async {
    try {
      final response = await _api.dio.get('/leaderboard', queryParameters: {'limit': limit});
      return LeaderboardResult.fromJson(response.data['data'] as Map<String, dynamic>? ?? {});
    } on DioException catch (e) {
      throw ChallengeException(_extractError(e));
    }
  }

  Future<int> getNewChallengesCount() async {
    try {
      final response = await _api.dio.get('/challenges/new-count');
      final data = response.data['data'];
      return (data is Map ? (data['count'] as num?)?.toInt() : null) ?? 0;
    } on DioException catch (e) {
      throw ChallengeException(_extractError(e));
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Could not reach challenges.';
  }
}
