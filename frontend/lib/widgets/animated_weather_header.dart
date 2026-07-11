import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum WeatherCondition {
  clearDay,
  clearNight,
  partlyCloudy,
  cloudy,
  rain,
  thunderstorm,
  snow,
  fog,
}

/// Maps OpenWeatherMap icon codes (e.g. "01d", "10n") to a WeatherCondition.
WeatherCondition weatherConditionFromIcon(String icon) {
  if (icon.isEmpty) return WeatherCondition.partlyCloudy;
  final code = icon.substring(0, icon.length > 2 ? 2 : icon.length);
  final isNight = icon.endsWith('n');

  switch (code) {
    case '01':
      return isNight ? WeatherCondition.clearNight : WeatherCondition.clearDay;
    case '02':
      return WeatherCondition.partlyCloudy;
    case '03':
    case '04':
      return WeatherCondition.cloudy;
    case '09':
    case '10':
      return WeatherCondition.rain;
    case '11':
      return WeatherCondition.thunderstorm;
    case '13':
      return WeatherCondition.snow;
    case '50':
      return WeatherCondition.fog;
    default:
      return WeatherCondition.partlyCloudy;
  }
}

/// Animated weather header confined to the top [heightFraction] of the screen.
/// [child] is the fixed foreground content (temperature, location, etc.) and
/// never animates — only the background behind it does.
class AnimatedWeatherHeader extends StatefulWidget {
  final WeatherCondition condition;
  final double heightFraction;
  final Widget child;

  const AnimatedWeatherHeader({
    super.key,
    required this.condition,
    required this.child,
    this.heightFraction = 0.42,
  });

  @override
  State<AnimatedWeatherHeader> createState() => _AnimatedWeatherHeaderState();
}

class _AnimatedWeatherHeaderState extends State<AnimatedWeatherHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _flash = 0;
  Timer? _lightningTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
    _maybeStartLightning();
  }

  @override
  void didUpdateWidget(covariant AnimatedWeatherHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.condition != widget.condition) {
      _lightningTimer?.cancel();
      _maybeStartLightning();
    }
  }

  void _maybeStartLightning() {
    if (widget.condition != WeatherCondition.thunderstorm) return;
    _lightningTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      setState(() => _flash = 0.55);
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      setState(() => _flash = 0.05);
      await Future.delayed(const Duration(milliseconds: 90));
      if (!mounted) return;
      setState(() => _flash = 0.35);
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() => _flash = 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _lightningTimer?.cancel();
    super.dispose();
  }

  List<Color> get _gradientColors {
    switch (widget.condition) {
      case WeatherCondition.clearDay:
        return const [Color(0xFF2E86D8), Color(0xFF123B7A), Color(0xFF0B1524)];
      case WeatherCondition.clearNight:
        return const [Color(0xFF0B1E3D), Color(0xFF081428), Color(0xFF060B14)];
      case WeatherCondition.partlyCloudy:
        return const [Color(0xFF1E5A8F), Color(0xFF11304F), Color(0xFF0B1524)];
      case WeatherCondition.cloudy:
        return const [Color(0xFF35455A), Color(0xFF1D2836), Color(0xFF0B1524)];
    case WeatherCondition.rain:
        return const [Color(0xFF13233F), Color(0xFF0D1A2E), Color(0xFF060B14)];
      case WeatherCondition.thunderstorm:
        return const [Color(0xFF10182A), Color(0xFF0A0F1C), Color(0xFF05070D)];
      case WeatherCondition.snow:
        return const [Color(0xFF2E4A63), Color(0xFF1B2E42), Color(0xFF0B1524)];
      case WeatherCondition.fog:
        return const [Color(0xFF3A4650), Color(0xFF232C34), Color(0xFF0B1524)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * widget.heightFraction;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradientColors,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _ConditionPainter(condition: widget.condition, t: _controller.value),
                size: Size.infinite,
              ),
            ),
            if (widget.condition == WeatherCondition.thunderstorm)
              IgnorePointer(
                child: Container(color: Colors.white.withOpacity(_flash)),
              ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _ConditionPainter extends CustomPainter {
  final WeatherCondition condition;
  final double t; // 0..1 looping

  _ConditionPainter({required this.condition, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    switch (condition) {
      case WeatherCondition.clearDay:
        _paintCornerGlow(canvas, size, const Color(0xFFFFDC8C), 0.55);
        break;
      case WeatherCondition.clearNight:
        _paintStars(canvas, size);
        _paintMoonGlow(canvas, size);
        _paintClouds(canvas, size, count: 1, opacity: 0.12, speed: 0.3);
        break;
      case WeatherCondition.partlyCloudy:
        _paintCornerGlow(canvas, size, const Color(0xFFFFDC8C), 0.4);
        _paintClouds(canvas, size, count: 3, opacity: 0.35, speed: 0.5);
        break;
      case WeatherCondition.cloudy:
        _paintClouds(canvas, size, count: 5, opacity: 0.45, speed: 0.35);
        break;
    case WeatherCondition.rain:
        _paintClouds(canvas, size, count: 4, opacity: 0.4, speed: 0.3);
        _paintRain(canvas, size, density: 60);
        _paintMist(canvas, size);
        break;
      case WeatherCondition.thunderstorm:
        _paintClouds(canvas, size, count: 5, opacity: 0.55, speed: 0.25);
        _paintRain(canvas, size, density: 90);
        break;
      case WeatherCondition.snow:
        _paintClouds(canvas, size, count: 3, opacity: 0.3, speed: 0.3);
        _paintSnow(canvas, size);
        _paintFrostEdge(canvas, size);
        break;
      case WeatherCondition.fog:
        _paintFogLayers(canvas, size);
        break;
    }
  }

  /// Soft warm light glowing in from a top corner — no solid sun disc,
  /// so it never sits behind the temperature text.
  void _paintCornerGlow(Canvas canvas, Size size, Color color, double intensity) {
    final pulse = 0.85 + 0.15 * math.sin(t * 2 * math.pi);
    final center = Offset(size.width * 1.05, size.height * -0.1);
    final radius = size.width * 0.55 * pulse;

    final glowPaint = Paint()
      ..shader = RadialGradient(colors: [color.withOpacity(intensity), color.withOpacity(0)])
          .createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glowPaint);
  }

  void _paintMoonGlow(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.75, size.height * 0.25);
    const radius = 26.0;
    final glowPaint = Paint()
      ..shader = RadialGradient(colors: [Colors.white.withOpacity(0.35), Colors.white.withOpacity(0)])
          .createShader(Rect.fromCircle(center: center, radius: radius * 3));
    canvas.drawCircle(center, radius * 3, glowPaint);
    canvas.drawCircle(center, radius, Paint()..color = Colors.white.withOpacity(0.9));
  }

  void _paintStars(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    for (var i = 0; i < 40; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.85;
      final twinkle = (math.sin((t * 2 * math.pi) + i) + 1) / 2;
      final paint = Paint()..color = Colors.white.withOpacity(0.2 + twinkle * 0.6);
      canvas.drawCircle(Offset(x, y), 1 + twinkle * 1.2, paint);
    }
  }

  void _paintClouds(Canvas canvas, Size size, {required int count, required double opacity, required double speed}) {
    for (var i = 0; i < count; i++) {
      final seed = i * 53.7;
      final rowY = size.height * (0.15 + 0.5 * ((i * 0.37) % 1.0));
      final progress = ((t * speed) + (seed / 100)) % 1.0;
      final x = -140 + progress * (size.width + 280);
      _drawCloudShape(canvas, Offset(x, rowY), scale: 0.7 + 0.5 * ((i % 3) / 2), opacity: opacity);
    }
  }

  /// Draws a soft, blurred cluster of overlapping circles — no rectangle,
  /// no hard edges — for a fluffier, more natural cloud silhouette.
  void _drawCloudShape(Canvas canvas, Offset topLeft, {double scale = 1.0, double opacity = 0.4}) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final bumps = <Offset>[
      const Offset(0, 8),
      const Offset(16, 0),
      const Offset(34, 6),
      const Offset(50, 10),
      const Offset(8, 16),
    ];
    final radii = [13.0, 17.0, 15.0, 11.0, 20.0];

    for (var i = 0; i < bumps.length; i++) {
      final center = topLeft + (bumps[i] * scale);
      canvas.drawCircle(center, radii[i] * scale, paint);
    }
  }

void _paintRain(Canvas canvas, Size size, {required int density}) {
    final rnd = math.Random(11);

    for (var i = 0; i < density; i++) {
      final baseX = rnd.nextDouble() * (size.width + 60) - 30;
      final speedFactor = 0.6 + rnd.nextDouble() * 0.6;
      final length = 10 + rnd.nextDouble() * 16;
      final width = 0.8 + rnd.nextDouble() * 0.7;
final maxOpacity = 0.2 + rnd.nextDouble() * 0.35;
      final fall = ((t * speedFactor * 3) + (i / density)) % 1.0;
      final y = fall * (size.height + 40) - 20;
      final x = baseX - fall * 14;

      final dx = length * 0.32;
      final dy = length;
      final start = Offset(x, y);
      final end = Offset(x + dx, y + dy);

      final paint = Paint()
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [Colors.white.withOpacity(0), Colors.white.withOpacity(maxOpacity), Colors.white.withOpacity(0)],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromPoints(start, end));

      canvas.drawLine(start, end, paint);
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    final rnd = math.Random(23);
    final paint = Paint()..color = Colors.white.withOpacity(0.85);

    for (var i = 0; i < 45; i++) {
      final baseX = rnd.nextDouble() * size.width;
      final speedFactor = 0.3 + rnd.nextDouble() * 0.4;
      final fall = ((t * speedFactor * 2) + (i / 45)) % 1.0;
      final sway = math.sin((t * 4 * math.pi) + i) * 10;
      final y = fall * (size.height + 20) - 10;
      final x = baseX + sway;
      final r = 1.5 + rnd.nextDouble() * 1.8;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  void _paintMist(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _paintFogLayers(Canvas canvas, Size size) {
    for (var i = 0; i < 4; i++) {
      final rowY = size.height * (0.2 + i * 0.2);
      final progress = ((t * 0.4) + (i * 0.25)) % 1.0;
      final x = -size.width + progress * (size.width * 2);
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withOpacity(0), Colors.white.withOpacity(0.18), Colors.white.withOpacity(0)],
        ).createShader(Rect.fromLTWH(x, rowY - 20, size.width, 40));
      canvas.drawRect(Rect.fromLTWH(x, rowY - 20, size.width, 40), paint);
    }
  }

  void _paintFrostEdge(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.25));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.25), paint);
  }

  @override
  bool shouldRepaint(covariant _ConditionPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.condition != condition;
}