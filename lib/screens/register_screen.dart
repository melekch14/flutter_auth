import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/signup_data.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';
import '../widgets/ride_widgets.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dialCode = ValueNotifier<String>('+216');
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _dialCode.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_loading) return;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final dialCode = _dialCode.value.trim();

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty) {
      _setError('Please fill all fields.');
      return;
    }

    final fullPhone = '$dialCode$phone';

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        verificationCompleted: (credential) {},
        verificationFailed: (e) {
          _setError(_mapAuthError(e));
        },
        codeSent: (verificationId, resendToken) {
          final data = SignUpData(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: fullPhone,
            password: password,
          );
          Navigator.of(context).push(
            buildRideRoute(
              OtpScreen(
                data: data,
                verificationId: verificationId,
                resendToken: resendToken,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (e) {
      _setError(_mapAuthError(e));
    } catch (_) {
      _setError('OTP failed. Please try again.');
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
      case 'invalid-phone-number':
        return 'That phone number looks invalid.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'captcha-check-failed':
      case 'missing-recaptcha-token':
        return 'reCAPTCHA check failed. Please try again.';
      case 'app-not-authorized':
        return 'App not authorized. Check SHA keys in Firebase.';
      default:
        return e.message ?? 'OTP failed.';
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
                          if (_errorMessage != null) ...[
                            _InlineError(
                              message: _errorMessage!,
                              onDismiss: () => setState(() => _errorMessage = null),
                            ),
                            const SizedBox(height: 10),
                          ],
                          RideTextField(
                            label: 'First name',
                            hint: 'Amina',
                            icon: Icons.person_outline,
                            controller: _firstNameController,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) =>
                                setState(() => _errorMessage = null),
                          ),
                          const SizedBox(height: 12),
                          RideTextField(
                            label: 'Last name',
                            hint: 'Karim',
                            icon: Icons.person_outline,
                            controller: _lastNameController,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) =>
                                setState(() => _errorMessage = null),
                          ),
                          const SizedBox(height: 12),
                          RideTextField(
                            label: 'Email',
                            hint: 'you@example.com',
                            icon: Icons.email_outlined,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) =>
                                setState(() => _errorMessage = null),
                          ),
                          const SizedBox(height: 12),
                          CountryCodePhoneField(
                            label: 'Phone',
                            hint: '00 000 000',
                            controller: _phoneController,
                            dialCode: _dialCode,
                            onChanged: () =>
                                setState(() => _errorMessage = null),
                          ),
                          const SizedBox(height: 12),
                          RideTextField(
                            label: 'Password',
                            hint: 'Create a strong password',
                            icon: Icons.lock_outline,
                            obscure: true,
                            controller: _passwordController,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) =>
                                setState(() => _errorMessage = null),
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            label: _loading ? 'Sending OTP...' : 'Create account',
                            onTap: _sendOtp,
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
