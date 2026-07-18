import 'package:flutter/material.dart';

import '../core/theme/dark_palette.dart';

/// A short, plain-language explainer shown near the top of a feature screen
/// so first-time users immediately understand what the screen is for and
/// why it matters — without needing a separate onboarding flow.
class FeatureIntroBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const FeatureIntroBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DarkPalette.leafGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DarkPalette.leafGreen.withOpacity(0.25), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: DarkPalette.leafGreen.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: DarkPalette.leafGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: DarkPalette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: DarkPalette.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}