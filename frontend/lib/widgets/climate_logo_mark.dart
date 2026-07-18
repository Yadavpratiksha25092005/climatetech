import 'package:flutter/material.dart';

import '../core/theme/dark_palette.dart';

class ClimateLogoMark extends StatelessWidget {
  final double size;

  const ClimateLogoMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4B7A), DarkPalette.leafGreenDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: DarkPalette.leafGreen.withOpacity(0.35), blurRadius: size * 0.5, spreadRadius: 1),
        ],
      ),
      child: Icon(Icons.public, color: Colors.white.withOpacity(0.95), size: size * 0.55),
    );
  }
}

class ClimateWordmark extends StatelessWidget {
  final double fontSize;

  const ClimateWordmark({super.key, this.fontSize = 28});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: DarkPalette.textPrimary),
        children: const [
          TextSpan(text: 'OneClimate '),
          TextSpan(text: 'AI', style: TextStyle(color: DarkPalette.leafGreen)),
        ],
      ),
    );
  }
}