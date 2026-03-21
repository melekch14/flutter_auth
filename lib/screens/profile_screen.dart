import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/session.dart';
import '../services/api_config.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';
import '../widgets/ride_widgets.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>?>? _profileFuture;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _savingProfile = false;
  bool _savingPassword = false;
  String? _profileMessage;
  String? _passwordMessage;
  bool _profileIsError = false;
  bool _passwordIsError = false;

  @override
  void initState() {
    super.initState();
    if (AppSession.jwt != null) {
      _profileFuture = _fetchProfile();
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
    final user = body['user'] as Map<String, dynamic>?;
    if (user != null) {
      _firstNameController.text = user['first_name']?.toString() ?? '';
      _lastNameController.text = user['last_name']?.toString() ?? '';
      _emailController.text = user['email']?.toString() ?? '';
      _phoneController.text = user['phone']?.toString() ?? '';
    }
    return user;
  }

  Future<void> _saveProfile() async {
    if (_savingProfile) return;
    setState(() {
      _savingProfile = true;
      _profileMessage = null;
      _profileIsError = false;
    });
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + (AppSession.jwt ?? ''),
        },
        body: jsonEncode({
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
        }),
      );
      if (response.statusCode >= 400) {
        _setProfileMessage(
          _readError(
            response,
            fallback: 'Update failed. (${response.statusCode})',
          ),
          isError: true,
        );
        return;
      }
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final user = body['user'] as Map<String, dynamic>?;
        if (user != null) {
          _firstNameController.text = user['first_name']?.toString() ?? '';
          _lastNameController.text = user['last_name']?.toString() ?? '';
          _emailController.text = user['email']?.toString() ?? '';
          _phoneController.text = user['phone']?.toString() ?? '';
          setState(() => _profileFuture = Future.value(user));
        }
      } catch (_) {}
      _setProfileMessage('Profile updated successfully.', isError: false);
    } catch (_) {
      _setProfileMessage('Update failed.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_savingPassword) return;
    setState(() {
      _savingPassword = true;
      _passwordMessage = null;
    });
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + (AppSession.jwt ?? ''),
        },
        body: jsonEncode({
          'current_password': _currentPasswordController.text.trim(),
          'new_password': _newPasswordController.text.trim(),
          'confirm_password': _confirmPasswordController.text.trim(),
        }),
      );
      if (response.statusCode >= 400) {
        _setPasswordMessage(
          _readError(response, fallback: 'Password update failed.'),
          isError: true,
        );
        return;
      }
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _setPasswordMessage('Password updated successfully.');
    } catch (_) {
      _setPasswordMessage('Password update failed.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _savingPassword = false);
      }
    }
  }

  void _setProfileMessage(String message, {bool isError = false}) {
    setState(() {
      _profileMessage = message;
      _profileIsError = isError;
    });
  }

  void _setPasswordMessage(String message, {bool isError = false}) {
    setState(() {
      _passwordMessage = message;
      _passwordIsError = isError;
    });
  }

  String _readError(http.Response response, {required String fallback}) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final error = body['error']?.toString();
        if (error != null && error.trim().isNotEmpty) {
          return error;
        }
      }
    } catch (_) {}
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (_profileFuture == null && AppSession.jwt != null) {
      _profileFuture = _fetchProfile();
    }

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
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Text(
                                    'Loading...',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.textMuted),
                                  );
                                }
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
                      child: Column(
                        children: [
                          if (_profileMessage != null) ...[
                            _InlineMessage(
                              message: _profileMessage!,
                              isError: _profileIsError,
                              onDismiss: () => setState(
                                () => _profileMessage = null,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: RideTextField(
                                  label: 'First name',
                                  hint: 'First name',
                                  icon: Icons.person_outline,
                                  controller: _firstNameController,
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => setState(() {
                                    _profileMessage = null;
                                    _profileIsError = false;
                                  }),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RideTextField(
                                  label: 'Last name',
                                  hint: 'Last name',
                                  icon: Icons.person_outline,
                                  controller: _lastNameController,
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => setState(() {
                                    _profileMessage = null;
                                    _profileIsError = false;
                                  }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          RideTextField(
                            label: 'Email',
                            hint: 'you@example.com',
                            icon: Icons.alternate_email,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setState(() {
                              _profileMessage = null;
                              _profileIsError = false;
                            }),
                          ),
                          const SizedBox(height: 10),
                          RideTextField(
                            label: 'Phone',
                            hint: '+216...',
                            icon: Icons.phone_outlined,
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            readOnly: true,
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: _savingProfile
                                ? 'Saving...'
                                : 'Update profile',
                            onTap: _saveProfile,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 220),
                    child: FrostedPanel(
                      child: Column(
                        children: [
                          if (_passwordMessage != null) ...[
                            _InlineMessage(
                              message: _passwordMessage!,
                              isError: _passwordIsError,
                              onDismiss: () => setState(
                                () => _passwordMessage = null,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          RideTextField(
                            label: 'Current password',
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            obscure: true,
                            controller: _currentPasswordController,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 10),
                          RideTextField(
                            label: 'New password',
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            obscure: true,
                            controller: _newPasswordController,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 10),
                          RideTextField(
                            label: 'Confirm new password',
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            obscure: true,
                            controller: _confirmPasswordController,
                            textInputAction: TextInputAction.done,
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: _savingPassword
                                ? 'Updating...'
                                : 'Update password',
                            onTap: _changePassword,
                          ),
                        ],
                      ),
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
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushAndRemoveUntil(
              buildRideRoute(const HomeScreen()),
              (route) => false,
            );
          } else if (index == 3) {
            // already on profile
          } else if (index == 2) {
            Navigator.of(context).pushAndRemoveUntil(
              buildRideRoute(const HomeScreen()),
              (route) => false,
            );
          } else if (index == 1) {
            Navigator.of(context).pushAndRemoveUntil(
              buildRideRoute(const HomeScreen()),
              (route) => false,
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

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    required this.onDismiss,
    required this.isError,
  });

  final String message;
  final VoidCallback onDismiss;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final bg = isError ? const Color(0x26FF5C5C) : const Color(0x2632D583);
    final border =
        isError ? const Color(0x66FF5C5C) : const Color(0x6642F5A6);
    final iconColor =
        isError ? const Color(0xFFFF5C5C) : const Color(0xFF7AF5C5);
    final textColor =
        isError ? const Color(0xFFFFC7C7) : const Color(0xFFCFFFEA);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: iconColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: textColor),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, color: textColor, size: 16),
          ),
        ],
      ),
    );
  }
}
