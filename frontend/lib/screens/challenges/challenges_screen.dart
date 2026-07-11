import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/challenge_model.dart';
import '../../providers/challenge_provider.dart';

IconData challengeIcon(String hint) {
  switch (hint) {
    case 'park':
      return Icons.park_outlined;
    case 'recycle':
      return Icons.recycling_outlined;
    case 'bike':
      return Icons.directions_bike_outlined;
    case 'bolt':
      return Icons.bolt_outlined;
    case 'water_drop':
      return Icons.water_drop_outlined;
    default:
      return Icons.emoji_events_outlined;
  }
}

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(challengeProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Challenges', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined, color: DarkPalette.textPrimary),
            tooltip: 'Leaderboard',
            onPressed: () => context.push('/leaderboard'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(challengeProvider.notifier).loadChallenges(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ChallengeState state) {
    if (state.challengesStatus == LoadStatus.loading && state.challenges.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen));
    }
    if (state.challengesStatus == LoadStatus.error && state.challenges.isEmpty) {
      return _buildErrorState(ref, state.challengesError);
    }
    if (state.challenges.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: Text('No challenges available right now.', style: TextStyle(color: DarkPalette.textMuted, fontSize: 13))),
          ),
        ],
      );
    }

    final active = state.challenges.where((c) => !c.isCompleted).toList();
    final completed = state.challenges.where((c) => c.isCompleted).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        if (active.isNotEmpty) ...[
          _sectionHeader('Active', active.length),
          const SizedBox(height: 10),
          ...active.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _challengeCard(
                  ref,
                  c,
                  isJoining: state.joiningIds.contains(c.id),
                  isCheckingIn: state.checkingInIds.contains(c.id),
                ),
              )),
        ],
        if (completed.isNotEmpty) ...[
          if (active.isNotEmpty) const SizedBox(height: 22),
          _sectionHeader('Completed', completed.length),
          const SizedBox(height: 10),
          ...completed.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _challengeCard(ref, c, isJoining: false, isCheckingIn: false),
              )),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Row(
      children: [
        Text(title, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Text('$count', style: const TextStyle(color: DarkPalette.textMuted, fontSize: 13)),
      ],
    );
  }

  Widget _challengeCard(
    WidgetRef ref,
    ChallengeModel challenge, {
    required bool isJoining,
    required bool isCheckingIn,
  }) {
    final progress = challenge.durationDays > 0 ? (challenge.totalCheckIns / challenge.durationDays).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: DarkPalette.leafGreen.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(challengeIcon(challenge.iconHint), color: DarkPalette.leafGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(challenge.title, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(challenge.description, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              if (challenge.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: DarkPalette.leafGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: const Text('✓ Completed', style: TextStyle(color: DarkPalette.leafGreen, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: DarkPalette.cyanAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: DarkPalette.cyanAccent.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.eco_outlined, color: DarkPalette.cyanAccent, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        challenge.displayBenefit,
                        style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 11.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
                if (challenge.isAiPersonalized) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DarkPalette.cyanAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: DarkPalette.cyanAccent.withOpacity(0.3)),
                    ),
                    child: const Text(
                      '✨ AI-generated',
                      style: TextStyle(color: DarkPalette.cyanAccent, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (challenge.joined) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${challenge.totalCheckIns}/${challenge.durationDays} days',
                  style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text('+${challenge.pointsPerCheckIn} pts/day', style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation(DarkPalette.leafGreen),
              ),
            ),
          ],
          if (!challenge.isCompleted) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: _actionButton(ref, challenge, isJoining: isJoining, isCheckingIn: isCheckingIn),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(
    WidgetRef ref,
    ChallengeModel challenge, {
    required bool isJoining,
    required bool isCheckingIn,
  }) {
    if (!challenge.joined) {
      return ElevatedButton(
        onPressed: isJoining ? null : () => ref.read(challengeProvider.notifier).joinChallenge(challenge.id),
        style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
        child: isJoining
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : const Text('Join challenge'),
      );
    }
    return ElevatedButton(
      onPressed: (challenge.checkedInToday || isCheckingIn) ? null : () => ref.read(challengeProvider.notifier).checkIn(challenge.id),
      style: ElevatedButton.styleFrom(
        backgroundColor: challenge.checkedInToday ? Colors.white.withOpacity(0.08) : DarkPalette.cyanAccent,
        foregroundColor: challenge.checkedInToday ? DarkPalette.textMuted : Colors.black,
      ),
      child: isCheckingIn
          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
          : Text(challenge.checkedInToday ? 'Checked in today' : 'Check in'),
    );
  }

  Widget _buildErrorState(WidgetRef ref, String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              message ?? 'Could not load challenges.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(challengeProvider.notifier).loadChallenges(),
              style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
