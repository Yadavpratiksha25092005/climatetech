import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../widgets/climate_logo_mark.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

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
        title: const Text('About App', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const ClimateLogoMark(size: 72),
            const SizedBox(height: 16),
            const ClimateWordmark(fontSize: 24),
            const SizedBox(height: 8),
            const Text('Version 0.1.0', style: TextStyle(color: DarkPalette.textMuted, fontSize: 12)),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
              child: const Text(
                'ClimateTech helps you track your carbon footprint, stay ahead of local climate risks, and build sustainable habits through community challenges — turning everyday choices into measurable climate action.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DarkPalette.textSecondary, fontSize: 13, height: 1.5),
              ),
            ),
            const Spacer(),
            const Text('Made with care for a healthier planet.', style: TextStyle(color: DarkPalette.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
