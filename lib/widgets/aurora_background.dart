import 'dart:math';
import 'package:flutter/material.dart';

import '../core/theme/dark_palette.dart';
/// Full-bleed dark navy background with soft glow blobs and slowly drifting
/// leaf particles. Used behind splash, onboarding, and login/register.
class AuroraBackground extends StatefulWidget {
  final Widget child;

  const AuroraBackground({super.key, required this.child});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = List.generate(14, (i) => _Particle.random(i));

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: DarkPalette.backgroundGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _glowBlob(DarkPalette.leafGreen.withOpacity(0.18), 260),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _glowBlob(DarkPalette.cyanAccent.withOpacity(0.14), 300),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _ParticlePainter(_particles, _controller.value),
                size: Size.infinite,
              );
            },
          ),
          widget.child,
        ],
      ),
    );
  }

  Widget _glowBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 160, spreadRadius: 60)],
      ),
    );
  }
}

class _Particle {
  final double x;
  final double startY;
  final double size;
  final double speed;
  final double opacity;

  _Particle({required this.x, required this.startY, required this.size, required this.speed, required this.opacity});

  factory _Particle.random(int seed) {
    final r = Random(seed * 97);
    return _Particle(
      x: r.nextDouble(),
      startY: r.nextDouble(),
      size: 3 + r.nextDouble() * 5,
      speed: 0.3 + r.nextDouble() * 0.7,
      opacity: 0.2 + r.nextDouble() * 0.35,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = ((p.startY + t * p.speed) % 1.0) * size.height;
      final x = p.x * size.width + sin((t * 2 * pi) + p.startY * 10) * 12;
      final rotation = (t * 2 * pi * p.speed) + p.startY * 6;
      final paint = Paint()..color = DarkPalette.leafGreen.withOpacity(p.opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      _drawLeaf(canvas, p.size * 2.2, paint);
      canvas.restore();
    }
  }

  void _drawLeaf(Canvas canvas, double size, Paint paint) {
    final path = Path()
      ..moveTo(0, -size)
      ..quadraticBezierTo(size * 0.9, -size * 0.3, 0, size)
      ..quadraticBezierTo(-size * 0.9, -size * 0.3, 0, -size)
      ..close();
    canvas.drawPath(path, paint);

    final veinPaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..strokeWidth = size * 0.08
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, -size * 0.8), Offset(0, size * 0.8), veinPaint);
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}