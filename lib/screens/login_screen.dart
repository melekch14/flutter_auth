import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';
import '../widgets/ride_widgets.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _setError('Please enter email and password.');
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        buildRideRoute(const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      _setError(_mapAuthError(e));
    } catch (_) {
      _setError('Login failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _setError(String message) {
    setState(() => _errorMessage = message);
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      default:
        return e.message ?? 'Login failed.';
    }
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
                          if (_errorMessage != null) ...[
                            _InlineError(
                              message: _errorMessage!,
                              onDismiss: () => setState(() => _errorMessage = null),
                            ),
                            const SizedBox(height: 10),
                          ],
                          RideTextField(
                            label: 'Email',
                            hint: 'you@example.com',
                            icon: Icons.alternate_email,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) =>
                                setState(() => _errorMessage = null),
                          ),
                          const SizedBox(height: 12),
                          RideTextField(
                            label: 'Password',
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            obscure: true,
                            controller: _passwordController,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) =>
                                setState(() => _errorMessage = null),
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
                            label: _loading ? 'Signing in...' : 'Login',
                            onTap: _login,
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x26FF5C5C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66FF5C5C)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF5C5C), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xFFFFC7C7)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close, color: Color(0xFFFFC7C7), size: 16),
          ),
        ],
      ),
    );
  }
}
