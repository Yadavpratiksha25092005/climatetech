import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/climate_logo_mark.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _navigateNext();
  }

 Future<void> _navigateNext() async {
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    // Mirrors app_router.dart's own redirect rule (authenticated ->
    // dashboard, unauthenticated -> login) rather than a separate one —
    // the router explicitly skips redirect handling for '/splash' itself,
    // so this screen is what actually owns this decision.
    var status = ref.read(authProvider).status;
    while (status == AuthStatus.unknown) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      status = ref.read(authProvider).status;
    }

    if (!mounted) return;
    context.go(status == AuthStatus.authenticated ? '/dashboard' : '/login');
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ClimateLogoMark(size: 96),
                  const SizedBox(height: 24),
                  const ClimateWordmark(fontSize: 32),
                  const SizedBox(height: 10),
                  const Text(
                    'Technology for a Sustainable Future',
                    style: TextStyle(color: DarkPalette.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 56),
                  SizedBox(
                    width: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: const AlwaysStoppedAnimation(DarkPalette.leafGreen),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Loading...', style: TextStyle(color: DarkPalette.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}