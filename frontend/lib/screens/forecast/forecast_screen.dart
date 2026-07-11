import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/forecast_model.dart';
import '../../providers/climate_provider.dart';
import '../../widgets/mini_weather_icon.dart';

const _compassPoints = [
  'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
  'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
];

/// Converts a wind bearing in degrees (0-360) to a 16-point compass label.
String windCompassDirection(int deg) {
  final normalized = ((deg % 360) + 360) % 360;
  final index = (normalized / 22.5).round() % 16;
  return _compassPoints[index];
}

enum _ForecastMode { hourly, daily }

class ForecastScreen extends ConsumerStatefulWidget {
  const ForecastScreen({super.key});

  @override
  ConsumerState<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends ConsumerState<ForecastScreen> {
  _ForecastMode _mode = _ForecastMode.hourly;
  bool _loading = true;
  String? _error;
  String _locationName = 'Your location';
  List<ForecastItem> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      double lat;
      double lon;
      final climateData = ref.read(climateProvider).data;
      if (climateData != null) {
        lat = climateData.latitude;
        lon = climateData.longitude;
        _locationName = climateData.locationName;
      } else {
        final position = await ref.read(locationServiceProvider).getCurrentLocation();
        lat = position.latitude;
        lon = position.longitude;
      }

      final result = await ref.read(climateServiceProvider).getForecast(lat: lat, lon: lon, count: 40);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        if (result.location.isNotEmpty) _locationName = result.location;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load forecast. Please try again.';
      });
    }
  }

  /// One representative (highest-temp) slot per calendar day, oldest first.
  List<ForecastItem> get _dailyItems {
    final byDate = <String, ForecastItem>{};
    for (final item in _items) {
      final key = DateFormat('yyyy-MM-dd').format(item.time.toLocal());
      final existing = byDate[key];
      if (existing == null || item.temperature > existing.temperature) {
        byDate[key] = item;
      }
    }
    return byDate.values.toList()..sort((a, b) => a.time.compareTo(b.time));
  }

  List<ForecastItem> get _displayItems => _mode == _ForecastMode.hourly ? _items : _dailyItems;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Forecast', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen))
          : _error != null
              ? _buildErrorState()
              : _displayItems.isEmpty
                  ? _buildEmptyState()
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final items = _displayItems;
    final chartItems = items.take(8).toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: DarkPalette.leafGreen,
      backgroundColor: DarkPalette.navyCard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildLocationChip(),
            const SizedBox(height: 16),
            _buildModeToggle(),
            const SizedBox(height: 16),
            _buildTimeChips(items),
            const SizedBox(height: 20),
            _buildTrendCard(chartItems),
            const SizedBox(height: 24),
            const Text('Forecast details', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _detailCard(items[i]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationChip() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: DarkPalette.leafGreen, size: 14),
            const SizedBox(width: 6),
            Text(_locationName, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: _modeTab('Hourly', _ForecastMode.hourly)),
          Expanded(child: _modeTab('Daily', _ForecastMode.daily)),
        ],
      ),
    );
  }

  Widget _modeTab(String label, _ForecastMode value) {
    final selected = _mode == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _mode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? DarkPalette.leafGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : DarkPalette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeChips(List<ForecastItem> items) {
    final now = DateTime.now();
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final local = item.time.toLocal();
          final isCurrent = _mode == _ForecastMode.hourly
              ? i == 0
              : local.year == now.year && local.month == now.month && local.day == now.day;

          return Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isCurrent ? DarkPalette.leafGreen.withOpacity(0.12) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: isCurrent ? Border.all(color: DarkPalette.leafGreen.withOpacity(0.3)) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isCurrent && _mode == _ForecastMode.hourly ? 'Now' : _chipTimeLabel(item),
                  style: TextStyle(color: isCurrent ? DarkPalette.textSecondary : DarkPalette.textMuted, fontSize: 10),
                ),
                const SizedBox(height: 6),
                MiniWeatherIcon(icon: item.weatherIcon, size: 32),
                const SizedBox(height: 6),
                Text(
                  '${item.temperature.round()}°',
                  style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _chipTimeLabel(ForecastItem item) {
    return _mode == _ForecastMode.hourly
        ? DateFormat('h a').format(item.time.toLocal())
        : DateFormat('E').format(item.time.toLocal());
  }

  Widget _buildTrendCard(List<ForecastItem> items) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text('Temperature trend', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          SizedBox(height: 190, child: _TrendChart(items: items, mode: _mode)),
        ],
      ),
    );
  }

  Widget _detailCard(ForecastItem item) {
    final description = item.description.isNotEmpty
        ? item.description[0].toUpperCase() + item.description.substring(1)
        : item.weatherMain;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MiniWeatherIcon(icon: item.weatherIcon, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _detailDateTimeLabel(item),
                      style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(description, style: const TextStyle(color: DarkPalette.leafGreen, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                '${item.temperature.round()}°',
                style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 24, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniFact(Icons.thermostat_outlined, 'Feels like ${item.feelsLike.round()}°')),
              Expanded(
                child: _miniFact(
                  Icons.air_rounded,
                  '${windCompassDirection(item.windDeg)} · ${item.windSpeed.toStringAsFixed(0)} km/h',
                ),
              ),
              Expanded(child: _miniFact(Icons.water_drop_outlined, '${item.pop.round()}% rain')),
            ],
          ),
        ],
      ),
    );
  }

  String _detailDateTimeLabel(ForecastItem item) {
    final local = item.time.toLocal();
    return _mode == _ForecastMode.hourly
        ? DateFormat('h:mm a · E, MMM d').format(local)
        : DateFormat('EEEE, MMM d').format(local);
  }

  Widget _miniFact(IconData icon, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: DarkPalette.textSecondary, size: 14),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: DarkPalette.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Could not load forecast.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No forecast data available right now.',
          textAlign: TextAlign.center,
          style: TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<ForecastItem> items;
  final _ForecastMode mode;

  const _TrendChart({required this.items, required this.mode});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final temps = items.map((e) => e.temperature).toList();
    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
    final pad = (maxTemp - minTemp).abs() < 4 ? 4.0 : (maxTemp - minTemp) * 0.25;

    return LineChart(
      LineChartData(
        minY: minTemp - pad,
        maxY: maxTemp + pad,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        backgroundColor: Colors.transparent,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => DarkPalette.navyCard,
            getTooltipItems: (spots) => spots.map((s) {
              final item = items[s.x.toInt()];
              return LineTooltipItem(
                '${item.temperature.round()}°\n${item.pop.round()}% rain',
                const TextStyle(color: DarkPalette.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= items.length) return const SizedBox.shrink();
                final item = items[i];
                final label = mode == _ForecastMode.hourly
                    ? DateFormat('h a').format(item.time.toLocal())
                    : DateFormat('E').format(item.time.toLocal());
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 10)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.water_drop, color: DarkPalette.cyanAccent, size: 8),
                          const SizedBox(width: 2),
                          Text('${item.pop.round()}%', style: const TextStyle(color: DarkPalette.cyanAccent, fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(items.length, (i) => FlSpot(i.toDouble(), items[i].temperature)),
            isCurved: true,
            color: DarkPalette.cyanAccent,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: DarkPalette.cyanAccent,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [DarkPalette.cyanAccent.withOpacity(0.25), DarkPalette.cyanAccent.withOpacity(0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
