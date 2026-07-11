import 'package:flutter/material.dart';

class MiniWeatherIcon extends StatelessWidget {
  final String icon;
  final double size;

  const MiniWeatherIcon({super.key, required this.icon, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final code = icon.length >= 2 ? icon.substring(0, 2) : '02';

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MiniIconPainter(code: code),
      ),
    );
  }
}

class _MiniIconPainter extends CustomPainter {
  final String code;

  _MiniIconPainter({required this.code});

  @override
  void paint(Canvas canvas, Size size) {
    switch (code) {
      case '01':
        _sun(canvas, size, center: Offset(size.width * 0.5, size.height * 0.5), radius: size.width * 0.28);
        break;
      case '02':
        _sun(canvas, size, center: Offset(size.width * 0.65, size.height * 0.35), radius: size.width * 0.2);
        _cloud(canvas, size, opacity: 0.9);
        break;
      case '03':
      case '04':
        _cloud(canvas, size, opacity: 0.65, tint: const Color(0xFFB8C4D0));
        break;
      case '09':
      case '10':
        _cloud(canvas, size, opacity: 0.75, tint: const Color(0xFFC8DCFF));
        _rain(canvas, size);
        break;
      case '11':
        _cloud(canvas, size, opacity: 0.6, tint: const Color(0xFF8C97A8));
        _bolt(canvas, size);
        break;
      case '13':
        _cloud(canvas, size, opacity: 0.7);
        _snow(canvas, size);
        break;
      case '50':
        _fog(canvas, size);
        break;
      default:
        _sun(canvas, size, center: Offset(size.width * 0.65, size.height * 0.35), radius: size.width * 0.2);
        _cloud(canvas, size, opacity: 0.9);
    }
  }

  void _sun(Canvas canvas, Size size, {required Offset center, required double radius}) {
    final glow = Paint()
      ..shader = RadialGradient(colors: [const Color(0xFFFFDC8C).withOpacity(0.6), const Color(0xFFFFDC8C).withOpacity(0)])
          .createShader(Rect.fromCircle(center: center, radius: radius * 2.2));
    canvas.drawCircle(center, radius * 2.2, glow);

    final core = Paint()
      ..shader = const RadialGradient(colors: [Color(0xFFFFEBA8), Color(0xFFFFC93C)])
          .createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, core);
  }

  void _cloud(Canvas canvas, Size size, {double opacity = 0.8, Color tint = Colors.white}) {
    final paint = Paint()
      ..color = tint.withOpacity(opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

    final base = Offset(size.width * 0.15, size.height * 0.45);
    final bumps = <Offset>[
      const Offset(0, 6),
      const Offset(8, 0),
      const Offset(17, 4),
      const Offset(25, 7),
      const Offset(4, 10),
    ];
    final radii = [6.0, 8.0, 7.0, 5.5, 9.5];
    final scale = size.width / 40;

    for (var i = 0; i < bumps.length; i++) {
      canvas.drawCircle(base + (bumps[i] * scale), radii[i] * scale, paint);
    }
  }

  void _rain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4FD8E8)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final y = size.height * 0.78;
    for (final dx in [0.28, 0.48, 0.68]) {
      final x = size.width * dx;
      canvas.drawLine(Offset(x, y), Offset(x, y + size.height * 0.16), paint);
    }
  }

  void _snow(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final y = size.height * 0.8;
    for (final dx in [0.3, 0.5, 0.7]) {
      canvas.drawCircle(Offset(size.width * dx, y), 1.6, paint);
    }
  }

  void _bolt(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFDC8C);
    final path = Path()
      ..moveTo(size.width * 0.55, size.height * 0.55)
      ..lineTo(size.width * 0.42, size.height * 0.75)
      ..lineTo(size.width * 0.52, size.height * 0.75)
      ..lineTo(size.width * 0.4, size.height * 0.95)
      ..lineTo(size.width * 0.62, size.height * 0.68)
      ..lineTo(size.width * 0.5, size.height * 0.68)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _fog(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final dy in [0.4, 0.55, 0.7]) {
      canvas.drawLine(
        Offset(size.width * 0.15, size.height * dy),
        Offset(size.width * 0.85, size.height * dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniIconPainter oldDelegate) => oldDelegate.code != code;
}