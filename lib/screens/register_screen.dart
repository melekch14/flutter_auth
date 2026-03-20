import 'package:flutter/material.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';
import '../widgets/ride_widgets.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

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
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 80),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Create account',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 140),
                    child: Text(
                      'Let’s get you moving in minutes.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 18),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 200),
                    child: FrostedPanel(
                      child: Column(
                        children: [
                        const RideTextField(
                          label: 'First name',
                          hint: 'Amina',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 12),
                        const RideTextField(
                          label: 'Last name',
                          hint: 'Karim',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 12),
                          const RideTextField(
                            label: 'Email',
                            hint: 'you@example.com',
                            icon: Icons.email_outlined,
                          ),
                        const SizedBox(height: 12),
                        const CountryCodePhoneField(
                          label: 'Phone',
                          hint: '00 000 000',
                        ),
                          const SizedBox(height: 16),
                          const RideTextField(
                            label: 'Password',
                            hint: 'Create a strong password',
                            icon: Icons.lock_outline,
                            obscure: true,
                          ),
                        const SizedBox(height: 16),
                          PrimaryButton(
                            label: 'Create account',
                            onTap: () {
                              Navigator.of(context).push(
                                buildRideRoute(const OtpScreen()),
                              );
                            },
                          ),
                        const SizedBox(height: 8),
                          GhostButton(
                            label: 'Already have an account? Login',
                            onTap: () => Navigator.of(context).pop(),
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
    );
  }
}
