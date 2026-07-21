import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dark_palette.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh so completed_challenges_count/badges are current even if the
    // in-memory user was last populated by a login/register response
    // (which doesn't include the profile-only completed-challenges count).
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    final success = await ref.read(authProvider.notifier).refreshProfile();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not refresh your latest activity.')),
      );
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: DarkPalette.navyDeep,
      appBar: AppBar(
        backgroundColor: DarkPalette.navyDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DarkPalette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profile', style: TextStyle(color: DarkPalette.textPrimary, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: DarkPalette.textPrimary),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator(color: DarkPalette.leafGreen))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _avatarSection(user),
                    const SizedBox(height: 24),
                    _statCards(user),
                    const SizedBox(height: 24),
                    _menuList(context),
                    const Spacer(),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DarkPalette.leafGreen,
                          foregroundColor: Colors.black,
                          overlayColor: Colors.black.withOpacity(0.1),
                          elevation: 0,
                          surfaceTintColor: Colors.transparent,
                        ),
                        child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _avatarSection(UserModel user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: DarkPalette.leafGreen.withOpacity(0.15),
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 32, color: DarkPalette.leafGreen, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Text(user.name, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(user.phone, style: const TextStyle(color: DarkPalette.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _statCards(UserModel user) {
    return Row(
      children: [
        Expanded(
          child: _statCard(icon: Icons.military_tech_outlined, value: '${user.badges.length}', label: 'Badges'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.task_alt_rounded,
            value: '${user.completedChallengesCount}',
            label: 'Completed Activities',
          ),
        ),
      ],
    );
  }

  Widget _statCard({required IconData icon, required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(icon, color: DarkPalette.leafGreen, size: 22),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: DarkPalette.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _menuList(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _menuItem(context, icon: Icons.eco_outlined, label: 'My Activities', onTap: () => context.push('/carbon')),
          _menuDivider(),
          _menuItem(context, icon: Icons.help_outline_rounded, label: 'Help & Support', onTap: () => context.push('/help')),
          _menuDivider(),
          _menuItem(context, icon: Icons.info_outline_rounded, label: 'About App', onTap: () => context.push('/about')),
        ],
      ),
    );
  }

  Widget _menuDivider() => Divider(height: 1, color: Colors.white.withOpacity(0.06), indent: 16, endIndent: 16);

  Widget _menuItem(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: DarkPalette.textSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: const TextStyle(color: DarkPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right, color: DarkPalette.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
