import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../services/session.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';
import '../widgets/ride_widgets.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  static const String _backendBaseUrl = 'http://10.0.2.2:4000';
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    if (AppSession.jwt != null) {
      await http.post(
        Uri.parse('$_backendBaseUrl/api/auth/logout'),
        headers: {'Authorization': 'Bearer ' + AppSession.jwt!},
      );
    }
    await FirebaseAuth.instance.signOut();
    await AppSession.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      buildRideRoute(const LoginScreen()),
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 80),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good evening, Amina',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ready for your next ride?',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                        const Spacer(),
                        PopupMenuButton<String>(
                          color: AppColors.surface,
                          onSelected: (value) {
                            if (value == 'logout') {
                              _logout(context);
                            } else if (value == 'profile') {
                              Navigator.of(context).push(
                                buildRideRoute(const ProfileScreen()),
                              );
                            } else if (value == 'settings') {
                              Navigator.of(context).push(
                                buildRideRoute(const SettingsScreen()),
                              );
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'profile',
                              child: Text('Profile'),
                            ),
                            PopupMenuItem<String>(
                              value: 'settings',
                              child: Text('Settings'),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem<String>(
                              value: 'logout',
                              child: Text('Logout'),
                            ),
                          ],
                          child: const CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.surfaceElevated,
                            child: Icon(Icons.person, color: AppColors.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 160),
                    child: FrostedPanel(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppColors.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Where to?',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Set',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const DelayedFadeSlide(
                    delay: Duration(milliseconds: 220),
                    child: Row(
                      children: [
                        Expanded(
                          child: ActionCard(
                            icon: Icons.local_taxi,
                            title: 'Ride now',
                            subtitle: 'Fast pickup',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ActionCard(
                            icon: Icons.calendar_today_outlined,
                            title: 'Schedule',
                            subtitle: 'Plan ahead',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 260),
                    child: Text(
                      'Nearby options',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: const [
                        DelayedFadeSlide(
                          delay: Duration(milliseconds: 300),
                          child: RideTile(
                            title: 'RideWave Go',
                            subtitle: '2 min away · 4 seats',
                            price: 'TND 8.4',
                          ),
                        ),
                        SizedBox(height: 12),
                        DelayedFadeSlide(
                          delay: Duration(milliseconds: 340),
                          child: RideTile(
                            title: 'RideWave Comfort',
                            subtitle: '5 min away · Extra legroom',
                            price: 'TND 12.1',
                          ),
                        ),
                        SizedBox(height: 12),
                        DelayedFadeSlide(
                          delay: Duration(milliseconds: 380),
                          child: RideTile(
                            title: 'RideWave XL',
                            subtitle: '7 min away · 6 seats',
                            price: 'TND 16.6',
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
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        onTap: (index) {
          if (index == 3) {
            Navigator.of(context).push(
              buildRideRoute(const ProfileScreen()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Trips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
