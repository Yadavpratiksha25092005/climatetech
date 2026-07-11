import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/insights_model.dart';
import '../../providers/insights_provider.dart';

IconData insightIcon(String hint) {
  switch (hint) {
    case 'air':
      return Icons.air_rounded;
    case 'transport':
      return Icons.directions_car_outlined;
    case 'electricity':
      return Icons.bolt_outlined;
    case 'food':
      return Icons.restaurant_outlined;
    case 'trend_up':
      return Icons.trending_up_rounded;
    case 'trend_down':
      return Icons.trending_down_rounded;
    case 'water':
      return Icons.water_outlined;
    case 'waste':
      return Icons.delete_outline_rounded;
    case 'start':
      return Icons.rocket_launch_outlined;
    default:
      return Icons.eco_outlined;
  }
}

(String, Color) scoreTier(int score) {
  if (score >= 80) return ('Excellent', DarkPalette.leafGreen);
  if (score >= 60) return ('Good', DarkPalette.leafGreen);
  if (score >= 40) return ('Fair', const Color(0xFFFFC857));
  return ('Needs improvement', const Color(0xFFE0605A));
}

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(insightsProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('AI Insights', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(insightsProvider.notifier).load(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          child: _buildBody(ref, state),
        ),
      ),
    );
  }

  Widget _buildBody(WidgetRef ref, InsightsState state) {
    if (state.status == InsightsStatus.loading && state.data == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen)),
      );
    }
    if (state.status == InsightsStatus.error && state.data == null) {
      return _buildErrorState(ref, state.errorMessage);
    }

    final data = state.data;
    if (data == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildScoreCard(data.score),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _weeklyCard(data)),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                icon: Icons.calendar_month_outlined,
                iconColor: DarkPalette.cyanAccent,
                value: data.monthlyProjectedKg.toStringAsFixed(1),
                unit: 'kg CO₂',
                label: 'Projected this month',
              ),
            ),
          ],
        ),
        if (data.highestCategory.isNotEmpty) ...[
          const SizedBox(height: 14),
          _highestCategoryChip(data.highestCategory),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recommendations', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            if (data.isAiGenerated)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: DarkPalette.cyanAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: DarkPalette.cyanAccent.withOpacity(0.3)),
                ),
                child: const Text(
                  '✨ AI-generated',
                  style: TextStyle(color: DarkPalette.cyanAccent, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...data.recommendations.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _recommendationCard(r),
            )),
      ],
    );
  }

  Widget _buildScoreCard(int score) {
    final tier = scoreTier(score);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Text('Eco score', style: TextStyle(color: DarkPalette.textSecondary, fontSize: 12)),
          const SizedBox(height: 14),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(tier.$2),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score', style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 34, fontWeight: FontWeight.w700)),
                    const Text('/ 100', style: TextStyle(color: DarkPalette.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: tier.$2.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(tier.$1, style: TextStyle(color: tier.$2, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _weeklyCard(InsightsModel data) {
    final trendUp = data.weeklyTrendPercent > 0.5;
    final trendDown = data.weeklyTrendPercent < -0.5;
    final trendColor = trendUp ? const Color(0xFFE0605A) : (trendDown ? DarkPalette.leafGreen : DarkPalette.textMuted);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.eco_outlined, color: DarkPalette.cyanAccent, size: 18),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(data.weeklyCo2Kg.toStringAsFixed(1), style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              const Text('kg CO₂', style: TextStyle(color: DarkPalette.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 2),
          const Text('This week', style: TextStyle(color: DarkPalette.textMuted, fontSize: 11)),
          if (trendUp || trendDown) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(trendUp ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: trendColor, size: 13),
                const SizedBox(width: 3),
                Text('${data.weeklyTrendPercent.abs().round()}% vs last week', style: TextStyle(color: trendColor, fontSize: 10)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _highestCategoryChip(String category) {
    final label = category.isEmpty ? category : category[0].toUpperCase() + category.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.insights_outlined, color: DarkPalette.textSecondary, size: 14),
          const SizedBox(width: 8),
          Text('Biggest source this month: ', style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12)),
          Text(label, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _recommendationCard(InsightRecommendation rec) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [DarkPalette.leafGreen.withOpacity(0.12), DarkPalette.cyanAccent.withOpacity(0.08)]),
        border: Border.all(color: DarkPalette.leafGreen.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: DarkPalette.leafGreen.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(insightIcon(rec.iconHint), color: DarkPalette.leafGreen, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec.title, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(rec.message, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref, String? message) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(
            message ?? 'Could not load insights.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(insightsProvider.notifier).load(),
            style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
