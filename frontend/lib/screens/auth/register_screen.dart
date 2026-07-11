import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/climate_logo_mark.dart';
import '../../widgets/dark_text_field.dart';
import '../../widgets/glass_card.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    final success = await ref.read(authProvider.notifier).register(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
        );
    if (success && mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const ClimateLogoMark(size: 64),
                    const SizedBox(height: 16),
                    const ClimateWordmark(fontSize: 26),
                    const SizedBox(height: 20),
                    const Text(
                      'Create your account 🌱',
                      style: TextStyle(color: DarkPalette.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Start your climate journey today.',
                      style: TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 28),
                    GlassCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DarkTextField(
                              hint: 'Full name',
                              icon: Icons.person_outline,
                              controller: _nameController,
                              validator: (v) => (v == null || v.length < 2) ? 'Enter your full name' : null,
                            ),
                            const SizedBox(height: 14),
                            DarkTextField(
                              hint: 'Email',
                              icon: Icons.email_outlined,
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Email is required';
                                if (!v.contains('@')) return 'Enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            DarkTextField(
                              hint: 'Password',
                              icon: Icons.lock_outline,
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              validator: (v) => (v == null || v.length < 8) ? 'Minimum 8 characters' : null,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: DarkPalette.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            const SizedBox(height: 14),
                            DarkTextField(
                              hint: 'Confirm password',
                              icon: Icons.lock_outline,
                              controller: _confirmController,
                              obscureText: _obscurePassword,
                              validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                            ),
                            if (authState.errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                authState.errorMessage!,
                                style: const TextStyle(color: Color(0xFFE0605A), fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 20),
                            _GradientButton(
                              label: 'Create Account',
                              isLoading: authState.isLoading,
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                children: [
                                  const Text(
                                    'Already have an account? ',
                                    style: TextStyle(color: DarkPalette.textSecondary, fontSize: 13),
                                  ),
                                  GestureDetector(
                                    onTap: () => context.go('/login'),
                                    child: const Text(
                                      'Log in',
                                      style: TextStyle(color: DarkPalette.leafGreen, fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _GradientButton({required this.label, required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: DarkPalette.primaryButtonGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: DarkPalette.leafGreen.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isLoading ? null : onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}