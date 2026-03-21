import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/session.dart';
import '../services/api_config.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';
import '../widgets/ride_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>?>? _profileFuture;

  @override
  void initState() {
    super.initState();
    if (AppSession.jwt != null) {
      _profileFuture = _fetchProfile();
    }
  }

  Future<Map<String, dynamic>?> _fetchProfile() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/me'),
      headers: {
        'Authorization': 'Bearer ' + (AppSession.jwt ?? ''),
      },
    );
    if (response.statusCode >= 400) {
      return null;
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['user'] as Map<String, dynamic>?;
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
                        'Profile',
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
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.surfaceElevated,
                            child: Icon(Icons.person, color: AppColors.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FutureBuilder<Map<String, dynamic>?>(
                              future: _profileFuture,
                              builder: (context, snapshot) {
                                final data = snapshot.data;
                                final firstName = data?['first_name']?.toString();
                                final lastName = data?['last_name']?.toString();
                                final fullName =
                                    '${firstName ?? 'User'} ${lastName ?? ''}'.trim();
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data?['email']?.toString() ?? 'No email',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.textMuted),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 180),
                    child: FrostedPanel(
                      child: FutureBuilder<Map<String, dynamic>?>(
                        future: _profileFuture,
                        builder: (context, snapshot) {
                          final data = snapshot.data;
                          final phone =
                              data?['phone']?.toString() ?? 'Not set';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InfoRow(
                                label: 'Email',
                                value: data?['email']?.toString() ?? 'Not set',
                              ),
                              const SizedBox(height: 10),
                              _InfoRow(
                                label: 'Phone',
                                value: phone,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 220),
                    child: PrimaryButton(
                      label: 'Edit profile (coming soon)',
                      onTap: () {},
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ),
        Expanded(
          flex: 7,
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
