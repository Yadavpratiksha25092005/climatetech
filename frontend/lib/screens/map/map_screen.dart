import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/dark_palette.dart';
import '../../providers/climate_provider.dart';

class _RadarFrame {
  final DateTime time;
  final String path;
  final bool isForecast;

  _RadarFrame({required this.time, required this.path, required this.isForecast});
}

enum BaseLayer { standard, dark, satellite }

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  String? _radarHost;
  // Now permanently empty/false — the only code that ever populated these
  // (_loadRadar) was removed along with its AppBar entry point. Left as-is
  // rather than also tearing out the now-unreachable timeline/legend/opacity
  // UI that depends on them, since that's a bigger feature-removal decision
  // than "remove this one button" — worth a deliberate follow-up if the
  // whole radar feature should go.
  final List<_RadarFrame> _frames = [];
  int _frameIndex = 0;
  final bool _radarEnabled = false;
  bool _playing = false;
  Timer? _playTimer;

  double _radarOpacity = 0.7;
  BaseLayer _baseLayer = BaseLayer.standard;
  bool _showLayersPanel = false;
  bool _windEnabled = false;

  late final AnimationController _windController =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  @override
  void dispose() {
    _playTimer?.cancel();
    _windController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_playing) {
      _playTimer?.cancel();
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    _playTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (_frames.isEmpty) return;
      setState(() {
        _frameIndex = (_frameIndex + 1) % _frames.length;
      });
    });
  }

  String get _baseLayerUrl {
    switch (_baseLayer) {
      case BaseLayer.standard:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case BaseLayer.dark:
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
      case BaseLayer.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final climateState = ref.watch(climateProvider);
    final data = climateState.data;
    final hasLocation = data != null;
    final center = hasLocation ? LatLng(data.latitude, data.longitude) : const LatLng(20.5937, 78.9629);
    final hasFrames = _frames.isNotEmpty;
    final currentFrame = hasFrames ? _frames[_frameIndex] : null;

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Climate map', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers_outlined, color: DarkPalette.textPrimary),
            tooltip: 'Layers',
            onPressed: () => setState(() => _showLayersPanel = !_showLayersPanel),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: hasLocation ? 12 : 4),
            children: [
              if (_baseLayer == BaseLayer.satellite) ...[
                // Esri's World_Imagery and World_Boundaries_and_Places tile services don't
                // have native tiles beyond zoom 19 in many areas and return a "zoom level
                // not supported" placeholder instead of an error. Capping maxNativeZoom stops
                // flutter_map from requesting past z19 and upscales the last tile instead.
                TileLayer(
                  urlTemplate: _baseLayerUrl,
                  userAgentPackageName: 'com.climatetech.frontend',
                  maxNativeZoom: 19,
                ),
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.climatetech.frontend',
                  maxNativeZoom: 19,
                ),
              ] else
                TileLayer(urlTemplate: _baseLayerUrl, userAgentPackageName: 'com.climatetech.frontend'),
              if (_radarEnabled && currentFrame != null && _radarHost != null)
                Opacity(
                  opacity: _radarOpacity,
                  child: TileLayer(
                    key: ValueKey(currentFrame.path),
                    urlTemplate: '$_radarHost${currentFrame.path}/256/{z}/{x}/{y}/2/1_1.png',
                    userAgentPackageName: 'com.climatetech.frontend',
                  ),
                ),
              if (_windEnabled)
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _windController,
                    builder: (context, _) => CustomPaint(
                      painter: _WindParticlePainter(
                        t: _windController.value,
                        windDeg: (data?.windDeg ?? 0).toDouble(),
                        windSpeed: data?.windSpeed ?? 3,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              if (hasLocation)
                MarkerLayer(markers: [
                  Marker(
                    point: center,
                    width: 60,
                    height: 60,
                    child: _LocationMarker(aqi: data.aqi, aqiLabel: data.aqiLabel),
                  ),
                ]),
            ],
          ),

          if (_windEnabled) const Positioned(left: 8, top: 12, child: _WindLegend()),

          if (_radarEnabled) const Positioned(left: 8, top: 12, bottom: 140, child: _RadarLegend()),

          if (hasLocation)
            Positioned(
              left: 16,
              right: 16,
              bottom: hasFrames ? 96 : 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: DarkPalette.navyCard.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: DarkPalette.leafGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(data.locationName,
                          style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Text('${data.temperature.round()}°C · AQI ${data.aqi}',
                        style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),

          if (hasFrames && _radarEnabled)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _TimelineBar(
                frames: _frames,
                index: _frameIndex,
                playing: _playing,
                onPlayToggle: _togglePlay,
                onScrub: (i) {
                  _playTimer?.cancel();
                  setState(() {
                    _playing = false;
                    _frameIndex = i;
                  });
                },
              ),
            ),

          if (_showLayersPanel)
            Positioned(
              right: 12,
              top: 12,
              child: _LayersPanel(
                baseLayer: _baseLayer,
                opacity: _radarOpacity,
                windEnabled: _windEnabled,
                onBaseLayerChanged: (v) => setState(() => _baseLayer = v),
                onOpacityChanged: (v) => setState(() => _radarOpacity = v),
                onWindChanged: (v) => setState(() => _windEnabled = v),
                onClose: () => setState(() => _showLayersPanel = false),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineBar extends StatelessWidget {
  final List<_RadarFrame> frames;
  final int index;
  final bool playing;
  final VoidCallback onPlayToggle;
  final ValueChanged<int> onScrub;

  const _TimelineBar({
    required this.frames,
    required this.index,
    required this.playing,
    required this.onPlayToggle,
    required this.onScrub,
  });

  @override
  Widget build(BuildContext context) {
    final current = frames[index];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 14),
      decoration: BoxDecoration(
        color: DarkPalette.navyCard.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onPlayToggle,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(color: DarkPalette.leafGreen, shape: BoxShape.circle),
                  child: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: DarkPalette.leafGreen,
                    inactiveTrackColor: Colors.white.withOpacity(0.15),
                    thumbColor: DarkPalette.leafGreen,
                    overlayColor: DarkPalette.leafGreen.withOpacity(0.2),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    min: 0,
                    max: (frames.length - 1).toDouble(),
                    value: index.toDouble(),
                    divisions: frames.length > 1 ? frames.length - 1 : null,
                    onChanged: (v) => onScrub(v.round()),
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('h:mm a').format(frames.first.time.toLocal()),
                  style: const TextStyle(color: DarkPalette.textMuted, fontSize: 10)),
              Text(
                '${current.isForecast ? "Forecast · " : ""}${DateFormat('h:mm a').format(current.time.toLocal())}',
                style: TextStyle(
                  color: current.isForecast ? DarkPalette.cyanAccent : DarkPalette.leafGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(DateFormat('h:mm a').format(frames.last.time.toLocal()),
                  style: const TextStyle(color: DarkPalette.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LayersPanel extends StatelessWidget {
  final BaseLayer baseLayer;
  final double opacity;
  final bool windEnabled;
  final ValueChanged<BaseLayer> onBaseLayerChanged;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<bool> onWindChanged;
  final VoidCallback onClose;

  const _LayersPanel({
    required this.baseLayer,
    required this.opacity,
    required this.windEnabled,
    required this.onBaseLayerChanged,
    required this.onOpacityChanged,
    required this.onWindChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DarkPalette.navyCard.withOpacity(0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Base layer', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              InkWell(onTap: onClose, child: const Icon(Icons.close, color: DarkPalette.textMuted, size: 18)),
            ],
          ),
          const SizedBox(height: 8),
          _radioTile('Standard', BaseLayer.standard),
          _radioTile('Dark', BaseLayer.dark),
          _radioTile('Satellite', BaseLayer.satellite),
          const SizedBox(height: 12),
          Text('Radar opacity: ${(opacity * 100).round()}%',
              style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: DarkPalette.leafGreen,
              inactiveTrackColor: Colors.white.withOpacity(0.15),
              thumbColor: DarkPalette.leafGreen,
              trackHeight: 3,
            ),
            child: Slider(min: 0.1, max: 1.0, value: opacity, onChanged: onOpacityChanged),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Wind', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              Switch(
                value: windEnabled,
                onChanged: onWindChanged,
                activeThumbColor: DarkPalette.cyanAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _radioTile(String label, BaseLayer value) {
    final selected = baseLayer == value;
    return InkWell(
      onTap: () => onBaseLayerChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? DarkPalette.leafGreen : DarkPalette.textMuted,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: selected ? DarkPalette.textPrimary : DarkPalette.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _RadarLegend extends StatelessWidget {
  const _RadarLegend();

  @override
  Widget build(BuildContext context) {
    final stops = [
      const Color(0xFF4FD8E8),
      const Color(0xFF3DDC84),
      const Color(0xFFFFC857),
      const Color(0xFFE0605A),
      const Color(0xFF8C5AE0),
    ];
    return Container(
      width: 34,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: DarkPalette.navyCard.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Light', style: TextStyle(color: DarkPalette.textMuted, fontSize: 8)),
          const SizedBox(height: 4),
          Container(
            width: 10,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(colors: stops, begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Heavy', style: TextStyle(color: DarkPalette.textMuted, fontSize: 8)),
        ],
      ),
    );
  }
}

class _LocationMarker extends StatelessWidget {
  final int aqi;
  final String aqiLabel;

  const _LocationMarker({required this.aqi, required this.aqiLabel});

  Color get _color {
    if (aqi >= 4) return const Color(0xFFE0605A);
    if (aqi >= 3) return const Color(0xFFFFC857);
    return DarkPalette.leafGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(8)),
          child: Text('AQI $aqi', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 2),
        Icon(Icons.location_pin, color: _color, size: 34),
      ],
    );
  }
}

class _WindLegend extends StatelessWidget {
  const _WindLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: DarkPalette.navyCard.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.air, color: DarkPalette.cyanAccent, size: 14),
          const SizedBox(width: 6),
          const Text('Wind flow (simulated)',
              style: TextStyle(color: DarkPalette.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// A single drifting particle used by [_WindParticlePainter]. Positions are
/// stored in 0..1 screen-fraction space so they scale with the canvas size.
class _WindParticle {
  final double x;
  final double y;
  final double offset;
  final double lengthFactor;
  final double speedFactor;

  _WindParticle({
    required this.x,
    required this.y,
    required this.offset,
    required this.lengthFactor,
    required this.speedFactor,
  });
}

/// Lightweight, non-gridded wind visualization: a handful of streak-shaped
/// particles drifting uniformly in the direction implied by [windDeg].
/// This is a stylistic approximation, not a real wind-vector field.
class _WindParticlePainter extends CustomPainter {
  static final List<_WindParticle> _particles = List.generate(50, (i) {
    final rnd = math.Random(i * 97 + 1);
    return _WindParticle(
      x: rnd.nextDouble(),
      y: rnd.nextDouble(),
      offset: rnd.nextDouble(),
      lengthFactor: 0.6 + rnd.nextDouble() * 0.8,
      speedFactor: 0.6 + rnd.nextDouble() * 0.8,
    );
  });

  final double t; // 0..1 looping
  final double windDeg;
  final double windSpeed;

  _WindParticlePainter({required this.t, required this.windDeg, required this.windSpeed});

  @override
  void paint(Canvas canvas, Size size) {
    // Meteorological convention: wind direction is where it blows FROM,
    // so the travel vector points 180° from windDeg.
    final rad = (windDeg + 180) * math.pi / 180;
    final dir = Offset(math.sin(rad), -math.cos(rad));
    final speed = 0.15 + (windSpeed.clamp(0, 25) / 25) * 0.55;
    final diagonal = size.width + size.height;

    for (final p in _particles) {
      final progress = ((t * speed) + p.offset * p.speedFactor) % 1.0;
      final travel = progress * diagonal;

      var x = (p.x * size.width) + dir.dx * travel;
      var y = (p.y * size.height) + dir.dy * travel;

      x = ((x % size.width) + size.width) % size.width;
      y = ((y % size.height) + size.height) % size.height;

      final fade = math.sin(progress * math.pi).clamp(0.0, 1.0);
      final opacity = 0.15 + fade * 0.45;
      final length = 8 * p.lengthFactor;

      final start = Offset(x, y);
      final end = Offset(x - dir.dx * length, y - dir.dy * length);

      final paint = Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            DarkPalette.cyanAccent.withOpacity(0),
            Colors.white.withOpacity(opacity),
          ],
        ).createShader(Rect.fromPoints(start, end));

      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WindParticlePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.windDeg != windDeg || oldDelegate.windSpeed != windSpeed;
}