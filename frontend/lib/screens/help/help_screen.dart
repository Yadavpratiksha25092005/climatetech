import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/dark_palette.dart';

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem(this.question, this.answer);
}

const _faqs = [
  _FaqItem(
    'How do I log a carbon activity?',
    'Open My Activities from your profile, or the leaf icon on the bottom bar, then use the log form to add a category, sub-type, and quantity.',
  ),
  _FaqItem(
    'How do challenge points and badges work?',
    'Joining and checking in daily on a challenge earns points once per calendar day. Badges unlock automatically at point thresholds and show up on your profile and the leaderboard.',
  ),
  _FaqItem(
    'Where can I download my report?',
    'Open My Activities from your profile, then use the download icon in the top bar to generate a PDF for this week or this month.',
  ),
  _FaqItem(
    'Why am I not receiving climate alerts?',
    'Make sure notification permissions are granted for this app in your device settings, and that you have a stable connection when the app is running.',
  ),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _contactSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@climatetech.app',
      query: 'subject=OneClimate AI support request',
    );
    bool launched = false;
    try {
      launched = await launchUrl(uri);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open an email app. Contact: support@climatetech.app')),
      );
    }
  }

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
        title: const Text('Help & Support', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          const Text('Frequently asked questions', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ..._faqs.map(
            (faq) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(faq.question, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(faq.answer, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 12.5, height: 1.4)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _contactSupport(context),
              icon: const Icon(Icons.mail_outline_rounded, size: 18),
              label: const Text('Contact Support'),
              style: ElevatedButton.styleFrom(backgroundColor: DarkPalette.leafGreen, foregroundColor: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
