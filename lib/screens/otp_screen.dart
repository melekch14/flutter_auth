import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  });

  final SignUpData data;

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
  String? _errorMessage;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    for (final node in _focusNodes) {
      node.addListener(() {
        if (mounted) setState(() {});
      });
    }
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

  Future<void> _verifyAndContinue() async {
    if (_verifying) return;
    if (!_isOtpComplete()) {
      _triggerShake();
      return;
    }

    final smsCode = _controllers.map((c) => c.text).join();
    setState(() => _verifying = true);

    try {
      final registerResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name': widget.data.firstName,
          'last_name': widget.data.lastName,
          'email': widget.data.email,
          'phone': widget.data.phone,
          'password': widget.data.password,
          'code': smsCode,
        }),
      );
      if (registerResponse.statusCode >= 400) {
        _setError(_readError(registerResponse, fallback: 'Registration failed. Please try again.'));
        _triggerShake();
        return;
      }

      final body = jsonDecode(registerResponse.body) as Map<String, dynamic>;
      final token = body['token']?.toString();
      final user = body['user'] as Map<String, dynamic>?;
      final uid = user?['id']?.toString();
      if (token == null || uid == null) {
        _setError('Registration failed. Please try again.');
        _triggerShake();
        return;
      }

      await AppSession.save(token: token, userId: uid);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        buildRideRoute(const LoginScreen()),
        (route) => false,
      );
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
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.data.phone}),
      );
      if (response.statusCode >= 400) {
        _setError(_readError(response, fallback: 'OTP resend failed.'));
        return;
      }
      _startTimer();
    } catch (_) {
      _setError('OTP resend failed.');
    }
  }

  void _setError(String message) {
    setState(() => _errorMessage = message);
  }

  String _readError(http.Response response, {required String fallback}) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final message = body['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          return message;
        }
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
                              children:
                                  List.generate(_otpLength * 2 - 1, (index) {
                                if (index.isOdd) {
                                  return const SizedBox(width: 12);
                                }
                                final fieldIndex = index ~/ 2;
                                final isFilled = _controllers[fieldIndex]
                                    .text
                                    .isNotEmpty;
                                return Expanded(
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 160),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _focusNodes[fieldIndex].hasFocus
                                          ? const Color(0xFF273248)
                                          : const Color(0xFF1D2433),
                                      borderRadius:
                                          BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _focusNodes[fieldIndex].hasFocus
                                            ? AppColors.accent
                                            : AppColors.stroke
                                                .withOpacity(0.95),
                                        width: _focusNodes[fieldIndex].hasFocus
                                            ? 1.6
                                            : 1.2,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x33000000),
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: _controllers[fieldIndex],
                                      focusNode: _focusNodes[fieldIndex],
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
                                        hintStyle: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              color: AppColors.textMuted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        filled: false,
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        setState(() => _errorMessage = null);
                                        if (value.isEmpty) {
                                          _handleOtpBackspace(fieldIndex);
                                        } else {
                                          _handleOtpChange(fieldIndex, value);
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
