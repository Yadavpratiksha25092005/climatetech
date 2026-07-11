import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/ai_summary_model.dart';
import '../../models/climate_data_model.dart';
import '../../models/forecast_model.dart';
import '../../providers/alerts_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/challenge_provider.dart';
import '../../providers/climate_provider.dart';
import '../../widgets/animated_weather_header.dart';
import '../../widgets/mini_weather_icon.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final climateState = ref.watch(climateProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      body: RefreshIndicator(
        onRefresh: () => ref.read(climateProvider.notifier).loadClimate(),
        color: DarkPalette.leafGreen,
        backgroundColor: DarkPalette.navyCard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, ref, climateState, user?.name),
              const SizedBox(height: 16),
              if (climateState.status == ClimateStatus.loaded &&
                  climateState.data != null) ...[
                _buildForecastRow(context, climateState.forecast),
                const SizedBox(height: 16),
                _buildContent(context, climateState.data!,
                    climateState.aiSummary, climateState.aiSummaryStatus),
              ] else if (climateState.status == ClimateStatus.error)
                _buildErrorState(ref, climateState.errorMessage),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref,
      ClimateState climateState, String? userName) {
    final data = climateState.data;
    final condition = data != null
        ? weatherConditionFromIcon(data.weatherIcon)
        : WeatherCondition.partlyCloudy;

    return AnimatedWeatherHeader(
      condition: condition,
      heightFraction: 0.5,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  const Align(
                    alignment: Alignment.center,
                    child: Text('Today',
                        style: TextStyle(
                            color: DarkPalette.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _IconWithBadge(
                      icon: Icons.emoji_events_outlined,
                      countProvider:
                          challengeProvider.select((s) => s.newChallengesCount),
                      onTap: () => context.push('/challenges'),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _IconWithBadge(
                          icon: Icons.notifications_outlined,
                          countProvider:
                              alertsProvider.select((s) => s.unreadCount),
                          onTap: () => context.push('/alerts'),
                        ),
                        const SizedBox(width: 8),
                        _circleIconButton(
                            icon: Icons.person_outline_rounded,
                            onTap: () => context.push('/profile')),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: climateState.status == ClimateStatus.loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : data != null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${data.temperature.round()}°C',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 68,
                                      fontWeight: FontWeight.w300,
                                      height: 1.1),
                                ),
                                const SizedBox(height: 10),
                                Text(data.locationName,
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14)),
                                const SizedBox(height: 8),
                                Text(
                                  data.weatherDescription.isNotEmpty
                                      ? data.weatherDescription[0]
                                              .toUpperCase() +
                                          data.weatherDescription.substring(1)
                                      : '',
                                  style: const TextStyle(
                                      color: DarkPalette.leafGreen,
                                      fontSize: 14),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleIconButton(
      {required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }

  Widget _buildForecastRow(BuildContext context, List<ForecastItem> forecast) {
    if (forecast.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Next 24 hours',
                  style: TextStyle(
                      color: DarkPalette.textSecondary, fontSize: 12)),
              InkWell(
                onTap: () => context.push('/forecast'),
                child: const Text('Full forecast ›',
                    style:
                        TextStyle(color: DarkPalette.leafGreen, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: forecast.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final item = forecast[i];
                final isFirst = i == 0;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.push('/forecast'),
                  child: Container(
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isFirst
                          ? DarkPalette.leafGreen.withOpacity(0.12)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: isFirst
                          ? Border.all(
                              color: DarkPalette.leafGreen.withOpacity(0.3))
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isFirst
                              ? 'Now'
                              : DateFormat('h a').format(item.time.toLocal()),
                          style: TextStyle(
                              color: isFirst
                                  ? DarkPalette.textSecondary
                                  : DarkPalette.textMuted,
                              fontSize: 10),
                        ),
                        const SizedBox(height: 4),
                        MiniWeatherIcon(icon: item.weatherIcon, size: 32),
                        const SizedBox(height: 4),
                        Text(
                          '${item.temperature.round()}°',
                          style: const TextStyle(
                              color: DarkPalette.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ClimateDataModel data,
    AISummaryModel? aiSummary,
    AISummaryStatus aiSummaryStatus,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                  child: _metricCard(Icons.blur_on_rounded,
                      '${data.pm25.toStringAsFixed(1)}', 'PM2.5 µg/m³')),
              const SizedBox(width: 10),
              Expanded(
                  child: _metricCard(Icons.grain_rounded,
                      '${data.pm10.toStringAsFixed(1)}', 'PM10 µg/m³')),
            ],
          ),
          const SizedBox(height: 14),
          _aiSuggestionCard(data, aiSummary, aiSummaryStatus),
          const SizedBox(height: 24),
          const Text('Current details',
              style: TextStyle(
                  color: DarkPalette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildCurrentDetails(data),
          const SizedBox(height: 14),
          Text(
            'Last updated ${DateFormat('h:mm a').format(data.recordedAt.toLocal())}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentDetails(ClimateDataModel data) {
    final humidityStatus = _humidityStatus(data.humidity);
    final visibilityKm = data.visibility / 1000;
    final visibilityStatus = _visibilityStatus(visibilityKm);
    final windStatus = _windStatus(data.windSpeed);
    final feelsStatus = _feelsLikeStatus(data.feelsLike);
    final pressureStatus = _pressureStatus(data.pressure);
    final dewStatus = _dewPointStatus(data.dewPoint);

    return Column(
      children: [
        _detailCardFull(
          icon: Icons.water_drop_outlined,
          label: 'Precipitation',
          value: data.rainVolume.toStringAsFixed(1),
          unit: 'mm',
          status: data.rainVolume > 0 ? 'Rain expected' : 'No rain expected',
          statusColor: data.rainVolume > 0
              ? const Color(0xFF4FD8E8)
              : DarkPalette.leafGreen,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _detailCard(
                icon: Icons.water_drop_outlined,
                label: 'Humidity',
                value: '${data.humidity}',
                unit: '%',
                status: humidityStatus.$1,
                statusColor: humidityStatus.$2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _detailCard(
                icon: Icons.visibility_outlined,
                label: 'Visibility',
                value: visibilityKm.toStringAsFixed(1),
                unit: 'km',
                status: visibilityStatus.$1,
                statusColor: visibilityStatus.$2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _detailCard(
                icon: Icons.air_rounded,
                label: 'Wind',
                value: data.windSpeed.toStringAsFixed(1),
                unit: 'km/h',
                status: windStatus.$1,
                statusColor: windStatus.$2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _detailCard(
                icon: Icons.thermostat_outlined,
                label: 'Feels like',
                value: '${data.feelsLike.round()}',
                unit: '°C',
                status: feelsStatus.$1,
                statusColor: feelsStatus.$2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _detailCard(
                icon: Icons.speed_outlined,
                label: 'Pressure',
                value: '${data.pressure}',
                unit: 'hPa',
                status: pressureStatus.$1,
                statusColor: pressureStatus.$2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _detailCard(
                icon: Icons.opacity_outlined,
                label: 'Dew point',
                value: '${data.dewPoint.round()}',
                unit: '°C',
                status: dewStatus.$1,
                statusColor: dewStatus.$2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  (String, Color) _humidityStatus(int h) {
    if (h >= 80) return ('Very humid', const Color(0xFFE0605A));
    if (h <= 30) return ('Dry', const Color(0xFFFFC857));
    return ('Comfortable', DarkPalette.leafGreen);
  }

  (String, Color) _visibilityStatus(double km) {
    if (km < 2) return ('Poor', const Color(0xFFE0605A));
    if (km < 5) return ('Reduced', const Color(0xFFFFC857));
    return ('Good', DarkPalette.leafGreen);
  }

  (String, Color) _windStatus(double kmh) {
    if (kmh >= 30) return ('Strong breeze', const Color(0xFFE0605A));
    if (kmh >= 15) return ('Breezy', const Color(0xFFFFC857));
    return ('Calm', DarkPalette.leafGreen);
  }

  (String, Color) _feelsLikeStatus(double temp) {
    if (temp >= 35) return ('Hot', const Color(0xFFE0605A));
    if (temp >= 25) return ('Warm', const Color(0xFFFFC857));
    return ('Comfortable', DarkPalette.leafGreen);
  }

  (String, Color) _pressureStatus(int hpa) {
    if (hpa < 1000) return ('Low pressure', const Color(0xFFFFC857));
    if (hpa > 1020) return ('High pressure', const Color(0xFFFFC857));
    return ('Normal', DarkPalette.leafGreen);
  }

  (String, Color) _dewPointStatus(double dp) {
    if (dp >= 24) return ('Oppressive', const Color(0xFFE0605A));
    if (dp >= 18) return ('Humid', const Color(0xFFFFC857));
    return ('Comfortable', DarkPalette.leafGreen);
  }

  Widget _detailCardFull({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: DarkPalette.textSecondary, size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: DarkPalette.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: DarkPalette.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Text(unit,
                  style: const TextStyle(
                      color: DarkPalette.textMuted, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _detailCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: DarkPalette.textSecondary, size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: DarkPalette.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: DarkPalette.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Text(unit,
                  style: const TextStyle(
                      color: DarkPalette.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _aiSuggestionCard(ClimateDataModel data, AISummaryModel? aiSummary,
      AISummaryStatus aiSummaryStatus) {
    final showAI =
        aiSummaryStatus == AISummaryStatus.loaded && aiSummary != null;
    final message = showAI
        ? '${aiSummary.weatherSummary} ${aiSummary.activitySuggestion}'
        : _suggestionFor(data);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          DarkPalette.leafGreen.withOpacity(0.12),
          DarkPalette.cyanAccent.withOpacity(0.08)
        ]),
        border: Border.all(color: DarkPalette.leafGreen.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: DarkPalette.leafGreen.withOpacity(0.15),
                shape: BoxShape.circle),
            child: const Icon(Icons.lightbulb_outline,
                color: DarkPalette.leafGreen, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('AI suggestion',
                        style: TextStyle(
                            color: DarkPalette.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    if (showAI && aiSummary.isAiGenerated)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: DarkPalette.cyanAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: DarkPalette.cyanAccent.withOpacity(0.3)),
                        ),
                        child: const Text(
                          '✨ AI-generated',
                          style: TextStyle(
                              color: DarkPalette.cyanAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(message,
                    style: const TextStyle(
                        color: DarkPalette.textSecondary,
                        fontSize: 12,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _suggestionFor(ClimateDataModel data) {
    if (data.aqi >= 4) {
      return 'Air quality is poor today. Consider wearing a mask outdoors and keeping windows closed.';
    }
    if (data.temperature >= 35) {
      return 'It\'s quite hot today. Stay hydrated and avoid peak sun hours between 12–3 PM.';
    }
    return 'Conditions look good today — a great day to walk or cycle instead of driving.';
  }

  Widget _metricCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: DarkPalette.cyanAccent, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  color: DarkPalette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(color: DarkPalette.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref, String? message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: DarkPalette.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(
            message ?? 'Could not load climate data.',
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(climateProvider.notifier).loadClimate(),
            style: ElevatedButton.styleFrom(
                backgroundColor: DarkPalette.leafGreen,
                foregroundColor: Colors.black),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      color: DarkPalette.navyDeep,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
            color: DarkPalette.navyCard,
            borderRadius: BorderRadius.circular(28)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                heightFactor: 1,
                child:
                    _navItem(icon: Icons.home_rounded, label: 'Home'),
              ),
            ),
            Expanded(
              child: Align(
                heightFactor: 1,
                child: _navItem(
                    icon: Icons.map_outlined,
                    label: 'Map',
                    onTap: () => context.push('/map')),
              ),
            ),
            Expanded(
              child: Align(
                heightFactor: 1,
                child: InkWell(
                  onTap: () => context.push('/carbon'),
                  child: Transform.translate(
                    offset: const Offset(0, -14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: DarkPalette.primaryButtonGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      DarkPalette.leafGreen.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6))
                            ],
                          ),
                          child: const Icon(Icons.eco_rounded,
                              color: Colors.black, size: 22),
                        ),
                        const SizedBox(height: 2),
                        const Text('Carbon',
                            style: TextStyle(
                                color: DarkPalette.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Align(
                heightFactor: 1,
                child: _navItem(
                    icon: Icons.storefront_outlined,
                    label: 'Market',
                    onTap: () => context.push('/marketplace')),
              ),
            ),
            Expanded(
              child: Align(
                heightFactor: 1,
                child: _navItem(
                    icon: Icons.article_outlined,
                    label: 'News',
                    onTap: () => context.push('/news')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
      {required IconData icon, required String label, VoidCallback? onTap}) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: DarkPalette.textMuted, size: 20),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: DarkPalette.textMuted, fontSize: 9)),
      ],
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// A small circular icon button with an optional count badge in the corner.
/// Watches [countProvider] itself (via `ref.watch`) rather than taking a
/// plain int, so a count change only rebuilds this small widget — not the
/// whole dashboard header.
class _IconWithBadge extends ConsumerWidget {
  final IconData icon;
  final ProviderListenable<int> countProvider;
  final VoidCallback onTap;

  const _IconWithBadge(
      {required this.icon, required this.countProvider, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(countProvider);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 17),
          ),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0605A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: DarkPalette.navyDeep, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
