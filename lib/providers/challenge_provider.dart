import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/challenge_model.dart';
import '../models/leaderboard_entry_model.dart';
import '../services/challenge_service.dart';
import 'auth_provider.dart';

final challengeServiceProvider = Provider<ChallengeService>((ref) {
  return ChallengeService(ref.read(apiServiceProvider));
});

enum LoadStatus { initial, loading, loaded, error }

class ChallengeState {
  final LoadStatus challengesStatus;
  final List<ChallengeModel> challenges;
  final String? challengesError;
  final Set<String> joiningIds;
  final Set<String> checkingInIds;

  final LoadStatus leaderboardStatus;
  final LeaderboardResult? leaderboard;
  final String? leaderboardError;

  final int newChallengesCount;

  const ChallengeState({
    this.challengesStatus = LoadStatus.initial,
    this.challenges = const [],
    this.challengesError,
    this.joiningIds = const {},
    this.checkingInIds = const {},
    this.leaderboardStatus = LoadStatus.initial,
    this.leaderboard,
    this.leaderboardError,
    this.newChallengesCount = 0,
  });

  ChallengeState copyWith({
    LoadStatus? challengesStatus,
    List<ChallengeModel>? challenges,
    String? challengesError,
    Set<String>? joiningIds,
    Set<String>? checkingInIds,
    LoadStatus? leaderboardStatus,
    LeaderboardResult? leaderboard,
    String? leaderboardError,
    int? newChallengesCount,
  }) {
    return ChallengeState(
      challengesStatus: challengesStatus ?? this.challengesStatus,
      challenges: challenges ?? this.challenges,
      challengesError: challengesError,
      joiningIds: joiningIds ?? this.joiningIds,
      checkingInIds: checkingInIds ?? this.checkingInIds,
      leaderboardStatus: leaderboardStatus ?? this.leaderboardStatus,
      leaderboard: leaderboard ?? this.leaderboard,
      leaderboardError: leaderboardError,
      newChallengesCount: newChallengesCount ?? this.newChallengesCount,
    );
  }
}

class ChallengeNotifier extends StateNotifier<ChallengeState> {
  final Ref _ref;
  final ChallengeService _service;

  ChallengeNotifier(this._ref, this._service) : super(const ChallengeState()) {
    loadChallenges();
    loadNewChallengesCount();
  }

  Future<void> loadChallenges() async {
    state = state.copyWith(challengesStatus: LoadStatus.loading, challengesError: null);
    try {
      final challenges = await _service.getChallenges();
      state = state.copyWith(challengesStatus: LoadStatus.loaded, challenges: challenges);
    } catch (e) {
      state = state.copyWith(challengesStatus: LoadStatus.error, challengesError: e.toString());
    }
  }

  Future<void> loadNewChallengesCount() async {
    try {
      final count = await _service.getNewChallengesCount();
      state = state.copyWith(newChallengesCount: count);
    } catch (_) {
      // Best-effort badge count — never surface this as a load error.
    }
  }

  /// Guarded by joiningIds so a double-tap can't fire two join requests for
  /// the same challenge while the first is still in flight.
  Future<bool> joinChallenge(String id) async {
    if (state.joiningIds.contains(id)) return false;
    state = state.copyWith(joiningIds: {...state.joiningIds, id});
    try {
      await _service.joinChallenge(id);
      final updated = state.challenges
          .map((c) => c.id == id ? c.copyWith(joined: true, status: 'active', totalCheckIns: 0, checkedInToday: false) : c)
          .toList();
      state = state.copyWith(
        challenges: updated,
        joiningIds: {...state.joiningIds}..remove(id),
      );

      // Refetches the authoritative count instead of decrementing it
      // locally — a local decrement can only ever approximate the real
      // server-side count and drifts from it over a session (e.g. if new
      // challenges were added since the last fetch), same background-refresh
      // pattern as the profile refresh in checkIn() below.
      unawaited(loadNewChallengesCount());
      return true;
    } catch (e) {
      state = state.copyWith(challengesError: e.toString(), joiningIds: {...state.joiningIds}..remove(id));
      return false;
    }
  }

  /// Same double-tap guard as joinChallenge. Applies the server's authoritative
  /// total_check_ins/status onto the local list instead of re-fetching the
  /// whole challenge list — the check-in response already has everything
  /// needed to update this one card.
  Future<bool> checkIn(String id) async {
    if (state.checkingInIds.contains(id)) return false;
    state = state.copyWith(checkingInIds: {...state.checkingInIds, id});
    try {
      final result = await _service.checkIn(id);
      final totalCheckIns = (result['total_check_ins'] as num?)?.toInt() ?? 0;
      final status = result['status'] as String? ?? 'active';
      final updated = state.challenges
          .map((c) => c.id == id ? c.copyWith(totalCheckIns: totalCheckIns, status: status, checkedInToday: true) : c)
          .toList();
      state = state.copyWith(challenges: updated, checkingInIds: {...state.checkingInIds}..remove(id));

      // A check-in awards points, so the profile's points/badges (shown
      // elsewhere) are now stale — refresh in the background without
      // blocking or failing this check-in on a profile-fetch hiccup.
      unawaited(_ref.read(authProvider.notifier).refreshProfile());
      return true;
    } catch (e) {
      state = state.copyWith(challengesError: e.toString(), checkingInIds: {...state.checkingInIds}..remove(id));
      return false;
    }
  }

  Future<void> loadLeaderboard() async {
    state = state.copyWith(leaderboardStatus: LoadStatus.loading, leaderboardError: null);
    try {
      final leaderboard = await _service.getLeaderboard();
      state = state.copyWith(leaderboardStatus: LoadStatus.loaded, leaderboard: leaderboard);
    } catch (e) {
      state = state.copyWith(leaderboardStatus: LoadStatus.error, leaderboardError: e.toString());
    }
  }
}

final challengeProvider = StateNotifierProvider<ChallengeNotifier, ChallengeState>((ref) {
  return ChallengeNotifier(ref, ref.read(challengeServiceProvider));
});
