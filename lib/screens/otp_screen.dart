import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/signup_data.dart';
import '../services/session.dart';
import '../services/api_config.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';
import '../widgets/ride_widgets.dart';
import 'login_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.data,
    required this.verificationId,
    this.resendToken,
  });

  final SignUpData data;
  final String verificationId;
  final int? resendToken;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  static const int _otpLength = 6;
  static const int _resendSeconds = 45;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  bool _verifying = false;
  String _verificationId = '';
  int? _resendToken;
  String? _errorMessage;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String _formatTimer(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _handleOtpChange(int index, String value) {
    if (value.length > 1) {
      _controllers[index].text = value.characters.last;
    }
    if (value.isNotEmpty) {
      HapticFeedback.selectionClick();
      if (index + 1 < _otpLength) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
      if (_isOtpComplete()) {
        _verifyAndContinue();
      }
    }
  }

  void _handleOtpBackspace(int index) {
    if (index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].selection = TextSelection.fromPosition(
        TextPosition(offset: _controllers[index - 1].text.length),
      );
    }
  }

  bool _isOtpComplete() {
    return _controllers.every((controller) => controller.text.isNotEmpty);
  }

  void _triggerShake() {
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0);
  }

  Future<void> _createSession() async {
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      throw Exception('Missing Firebase token');
    }
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/session'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + idToken,
      },
    );
    if (response.statusCode >= 400) {
      throw Exception('Session creation failed');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['token']?.toString();
    final uid = body['uid']?.toString();
    if (token == null || uid == null) {
      throw Exception('Session response invalid');
    }
    await AppSession.save(token: token, userId: uid);
  }

  Future<void> _verifyAndContinue() async {
    if (_verifying) return;
    if (!_isOtpComplete()) {
      _triggerShake();
      return;
    }

    final smsCode = _controllers.map((c) => c.text).join();
    setState(() => _verifying = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: smsCode,
      );

      final phoneUser =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final emailCredential = EmailAuthProvider.credential(
        email: widget.data.email,
        password: widget.data.password,
      );

      await phoneUser.user?.linkWithCredential(emailCredential);

      await _createSession();

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/users'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + (AppSession.jwt ?? ''),
          },
          body: jsonEncode({
            'firebase_uid': uid,
            'first_name': widget.data.firstName,
            'last_name': widget.data.lastName,
            'email': widget.data.email,
            'phone': widget.data.phone,
          }),
        );
        if (response.statusCode >= 400) {
          throw Exception('Backend error');
        }
      }

      await FirebaseAuth.instance.signOut();
      await AppSession.clear();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        buildRideRoute(const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _setError(_mapAuthError(e));
      _triggerShake();
    } catch (_) {
      _setError('Verification failed. Please try again.');
      _triggerShake();
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  Future<void> _resendCode() async {
    if (_secondsLeft != 0) return;
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.data.phone,
        forceResendingToken: _resendToken,
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          _setError(_mapAuthError(e));
        },
        codeSent: (verificationId, resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
        },
        codeAutoRetrievalTimeout: (_) {},
      );
      _startTimer();
    } catch (_) {
      _setError('OTP resend failed.');
    }
  }

  void _setError(String message) {
    setState(() => _errorMessage = message);
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Invalid code. Please try again.';
      case 'session-expired':
        return 'Code expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'billing-not-enabled':
        return 'Phone auth requires billing enabled on Firebase.';
      case 'app-not-authorized':
        return 'App not authorized. Check SHA keys in Firebase.';
      default:
        return e.message ?? 'Verification failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft == 0;

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
                          'Verify your number',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 140),
                    child: Text(
                      'Enter the 6-digit code we sent to ${widget.data.phone}.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 18),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 200),
                    child: AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: child,
                        );
                      },
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
                            Row(
                              children: List.generate(_otpLength, (index) {
                                final isFilled =
                                    _controllers[index].text.isNotEmpty;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: index == _otpLength - 1 ? 0 : 12,
                                    ),
                                    child: TextField(
                                      controller: _controllers[index],
                                      focusNode: _focusNodes[index],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      maxLength: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                      decoration: InputDecoration(
                                        counterText: '',
                                        hintText: '_',
                                        prefixIcon: null,
                                        filled: true,
                                        fillColor: isFilled
                                            ? AppColors.surfaceElevated
                                            : AppColors.fieldFill,
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: isFilled
                                                ? AppColors.accent
                                                    .withOpacity(0.6)
                                                : AppColors.stroke
                                                    .withOpacity(0.8),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: AppColors.accent,
                                            width: 1.4,
                                          ),
                                        ),
                                      ),
                                      onChanged: (value) {
                                        setState(() => _errorMessage = null);
                                        if (value.isEmpty) {
                                          _handleOtpBackspace(index);
                                        } else {
                                          _handleOtpChange(index, value);
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Didn’t receive the code?',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: _resendCode,
                              child: Text(
                                canResend
                                    ? 'Resend code'
                                    : 'Resend in ${_formatTimer(_secondsLeft)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: canResend
                                          ? AppColors.accent
                                          : AppColors.accentSoft,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            PrimaryButton(
                              label: _verifying
                                  ? 'Verifying...'
                                  : 'Verify & Continue',
                              onTap: _verifyAndContinue,
                            ),
                          ],
                        ),
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
