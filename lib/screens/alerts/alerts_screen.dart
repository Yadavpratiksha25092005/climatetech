import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/alert_model.dart';
import '../../providers/alerts_provider.dart';

IconData alertIcon(String alertType) {
  switch (alertType) {
    case 'poor_air_quality':
      return Icons.air_rounded;
    case 'heat_wave':
      return Icons.thermostat_outlined;
    case 'heavy_rain':
      return Icons.water_drop_outlined;
    default:
      return Icons.notifications_outlined;
  }
}

Color severityColor(String severity) {
  switch (severity) {
    case 'danger':
      return const Color(0xFFE0605A);
    case 'warning':
      return const Color(0xFFFFC857);
    default:
      return DarkPalette.cyanAccent;
  }
}

String alertTypeLabel(String alertType) {
  switch (alertType) {
    case 'poor_air_quality':
      return 'Poor air quality';
    case 'heat_wave':
      return 'Heat wave';
    case 'heavy_rain':
      return 'Heavy rain';
    default:
      return alertType;
  }
}

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(alertsProvider);

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Alerts', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(alertsProvider.notifier).load(),
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

  Widget _buildBody(WidgetRef ref, AlertsState state) {
    if (state.status == AlertsStatus.loading && state.alerts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen)),
      );
    }
    if (state.status == AlertsStatus.error && state.alerts.isEmpty) {
      return _buildErrorState(ref, state.errorMessage);
    }
    if (state.alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        child: const Center(
          child: Text('No alerts yet.', style: TextStyle(color: DarkPalette.textMuted, fontSize: 13)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _alertTile(ref, state.alerts[i]),
    );
  }

  Widget _alertTile(WidgetRef ref, AlertModel alert) {
    final color = severityColor(alert.severity);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: alert.isRead ? null : () => ref.read(alertsProvider.notifier).markAsRead(alert.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(alertIcon(alert.alertType), color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!alert.isRead) ...[
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(color: DarkPalette.cyanAccent, shape: BoxShape.circle),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          alert.title,
                          style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          alertTypeLabel(alert.alertType),
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(alert.message, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12, height: 1.4)),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('MMM d, h:mm a').format(alert.createdAt.toLocal()),
                    style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            message ?? 'Could not load alerts.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(alertsProvider.notifier).load(),
            style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
