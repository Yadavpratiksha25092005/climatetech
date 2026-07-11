import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/leaderboard_entry_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/challenge_provider.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(challengeProvider.notifier).loadLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(challengeProvider);
    final currentUserId = ref.watch(authProvider.select((s) => s.user?.id));

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Leaderboard', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(challengeProvider.notifier).loadLeaderboard(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: Column(
          children: [
            Expanded(child: _buildBody(state, currentUserId)),
            if (state.leaderboard?.yourRank != null) _yourRankCard(state.leaderboard!.yourRank!),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ChallengeState state, String? currentUserId) {
    if (state.leaderboardStatus == LoadStatus.loading && state.leaderboard == null) {
      return const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen));
    }
    if (state.leaderboardStatus == LoadStatus.error && state.leaderboard == null) {
      return _buildErrorState(state.leaderboardError);
    }

    final top = state.leaderboard?.top ?? [];
    if (top.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: Text('No one has earned points yet — be the first!', style: TextStyle(color: DarkPalette.textMuted, fontSize: 13)),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      itemCount: top.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _rankTile(top[i], isCurrentUser: top[i].userId == currentUserId),
    );
  }

  Widget _rankTile(LeaderboardEntryModel entry, {required bool isCurrentUser}) {
    final medalColor = entry.rank == 1
        ? const Color(0xFFFFC857)
        : entry.rank == 2
            ? const Color(0xFFC7CDD6)
            : entry.rank == 3
                ? const Color(0xFFCD8A5A)
                : DarkPalette.textMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrentUser ? DarkPalette.leafGreen.withOpacity(0.1) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: isCurrentUser ? Border.all(color: DarkPalette.leafGreen.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(color: entry.rank <= 3 ? medalColor : DarkPalette.textMuted, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: DarkPalette.leafGreen.withOpacity(0.15),
            child: Text(
              entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
              style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrentUser ? '${entry.name} (You)' : entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isCurrentUser ? DarkPalette.leafGreen : DarkPalette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (entry.badges.isNotEmpty)
                  Text(entry.badges.last, style: const TextStyle(color: DarkPalette.textMuted, fontSize: 10)),
              ],
            ),
          ),
          Text('${entry.totalPoints} pts', style: const TextStyle(color: DarkPalette.cyanAccent, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _yourRankCard(LeaderboardEntryModel entry) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: DarkPalette.primaryButtonGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text('#${entry.rank}', style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Your rank', style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          Text('${entry.totalPoints} pts', style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              message ?? 'Could not load the leaderboard.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(challengeProvider.notifier).loadLeaderboard(),
              style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
