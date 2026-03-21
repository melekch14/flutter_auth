import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/session.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';
import '../widgets/ride_widgets.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    if (AppSession.jwt != null) {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/logout'),
        headers: {'Authorization': 'Bearer ' + AppSession.jwt!},
      );
    }
    await AppSession.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GradientBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Settings',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 120),
                    child: FrostedPanel(
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            subtitle: 'Ride updates and promotions',
                            onTap: () {},
                          ),
                          const SizedBox(height: 10),
                          _SettingsTile(
                            icon: Icons.security_outlined,
                            title: 'Security',
                            subtitle: 'Password and device settings',
                            onTap: () {},
                          ),
                          const SizedBox(height: 10),
                          _SettingsTile(
                            icon: Icons.language_outlined,
                            title: 'Language',
                            subtitle: 'English (US)',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 180),
                    child: FrostedPanel(
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.help_outline,
                            title: 'Help & Support',
                            subtitle: 'FAQs and contact',
                            onTap: () {},
                          ),
                          const SizedBox(height: 10),
                          _SettingsTile(
                            icon: Icons.info_outline,
                            title: 'About',
                            subtitle: 'Version and licenses',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 220),
                    child: PrimaryButton(
                      label: 'Logout',
                      onTap: () => _logout(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
