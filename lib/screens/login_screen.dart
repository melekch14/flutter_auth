import 'package:flutter/material.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';
import '../widgets/ride_widgets.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
                  const DelayedFadeSlide(
                    delay: Duration(milliseconds: 80),
                    child: BrandHeader(),
                  ),
                  const SizedBox(height: 16),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 160),
                    child: Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 210),
                    child: Text(
                      'Sign in to start moving with confidence.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 18),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 260),
                    child: FrostedPanel(
                      child: Column(
                        children: [
                          const RideTextField(
                            label: 'Email or phone',
                            hint: 'you@example.com',
                            icon: Icons.alternate_email,
                          ),
                        const SizedBox(height: 12),
                          const RideTextField(
                            label: 'Password',
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            obscure: true,
                          ),
                        const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Forgot password?',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.accentSoft),
                            ),
                          ),
                        const SizedBox(height: 16),
                          PrimaryButton(
                            label: 'Login',
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                buildRideRoute(const HomeScreen()),
                              );
                            },
                          ),
                        const SizedBox(height: 10),
                          GhostButton(
                            label: 'Create account',
                            onTap: () {
                              Navigator.of(context).push(
                                buildRideRoute(const RegisterScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
