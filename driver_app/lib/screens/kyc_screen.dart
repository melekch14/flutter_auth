import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../services/session.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_reveal.dart';
import '../widgets/ride_widgets.dart';
import 'kyc_pending_screen.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  XFile? _idCard;
  XFile? _driverLicense;
  XFile? _selfie;

  bool _uploading = false;
  double _uploadProgress = 0;
  String? _errorMessage;
  late final AnimationController _progressController;
  bool _hasProgress = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _pickFile({required bool camera, required String type}) async {
    final source = camera ? ImageSource.camera : ImageSource.gallery;
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _errorMessage = null;
      if (type == 'id') {
        _idCard = picked;
      } else if (type == 'license') {
        _driverLicense = picked;
      } else {
        _selfie = picked;
      }
    });
  }

  bool _ready() =>
      _idCard != null && _driverLicense != null && _selfie != null;

  Future<void> _submit() async {
    if (_uploading) return;
    if (!_ready()) {
      setState(() => _errorMessage = 'Please upload all required documents.');
      return;
    }
    if (AppSession.jwt == null) {
      setState(() => _errorMessage = 'Session expired. Please login again.');
      return;
    }

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _hasProgress = false;
      _errorMessage = null;
    });
    _progressController.value = 0;

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/kyc/upload'),
      );
      request.headers['Authorization'] = 'Bearer ' + AppSession.jwt!;
      request.files.add(await http.MultipartFile.fromPath(
        'id_card',
        _idCard!.path,
      ));
      request.files.add(await http.MultipartFile.fromPath(
        'driver_license',
        _driverLicense!.path,
      ));
      request.files.add(await http.MultipartFile.fromPath(
        'selfie',
        _selfie!.path,
      ));

      final totalBytes = request.contentLength;
      _hasProgress = totalBytes > 0;
      final stream = request.finalize();

      final streamed = http.StreamedRequest('POST', request.url);
      streamed.headers.addAll(request.headers);
      streamed.contentLength = totalBytes;

      final client = http.Client();

      int sent = 0;
      final completer = Completer<void>();
      stream.listen(
        (data) {
          sent += data.length;
          if (totalBytes > 0) {
            final progress = sent / totalBytes;
            _setProgress(progress.clamp(0, 1));
          }
          streamed.sink.add(data);
        },
        onDone: () {
          streamed.sink.close();
          completer.complete();
        },
        onError: (error) {
          streamed.sink.addError(error);
          completer.completeError(error);
        },
        cancelOnError: true,
      );

      await completer.future;
      final response = await client.send(streamed);
      final status = response.statusCode;
      final bodyText = await response.stream.bytesToString();
      client.close();
      if (status >= 400) {
        final message = _readError(bodyText) ??
            'Upload failed. Please try again. (${response.statusCode})';
        setState(() => _errorMessage = message);
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        buildRideRoute(const KycPendingScreen()),
      );
    } catch (_) {
      setState(() => _errorMessage = 'Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String? _readError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final error = data['error']?.toString();
        if (error != null && error.trim().isNotEmpty) return error;
      }
    } catch (_) {}
    return null;
  }

  void _setProgress(double value) {
    _uploadProgress = value;
    _progressController.animateTo(
      value,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GradientBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DelayedFadeSlide(
                    delay: Duration(milliseconds: 80),
                    child: BrandHeader(),
                  ),
                  const SizedBox(height: 16),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 140),
                    child: Text(
                      'KYC Verification',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      'Upload your documents to start driving. We verify everything within 24 hours.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_uploading)
                    DelayedFadeSlide(
                      delay: const Duration(milliseconds: 240),
                      child: !_hasProgress
                          ? Column(
                              children: [
                                LinearProgressIndicator(
                                  backgroundColor: AppColors.surfaceElevated,
                                  color: AppColors.accent,
                                  minHeight: 6,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Uploading your documents...',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                            )
                          : AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, _) {
                                final value = _progressController.value;
                                return Column(
                                  children: [
                                    LinearProgressIndicator(
                                      value: value.clamp(0, 1),
                                      backgroundColor:
                                          AppColors.surfaceElevated,
                                      color: AppColors.accent,
                                      minHeight: 6,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Uploading your documents... ${(value * 100).round()}%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textMuted,
                                          ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  const SizedBox(height: 16),
                  DelayedFadeSlide(
                    delay: const Duration(milliseconds: 260),
                    child: FrostedPanel(
                      child: Column(
                        children: [
                          if (_errorMessage != null) ...[
                            _InlineError(
                              message: _errorMessage!,
                              onDismiss: () =>
                                  setState(() => _errorMessage = null),
                            ),
                            const SizedBox(height: 10),
                          ],
                          _KycTile(
                            title: 'Government ID',
                            subtitle: _idCard == null
                                ? 'Upload a clear photo of your ID card.'
                                : 'Selected: ${_fileName(_idCard!)}',
                            icon: Icons.badge_outlined,
                            onCamera: () => _pickFile(camera: true, type: 'id'),
                            onGallery:
                                () => _pickFile(camera: false, type: 'id'),
                            selected: _idCard != null,
                          ),
                          const SizedBox(height: 12),
                          _KycTile(
                            title: 'Driver License',
                            subtitle: _driverLicense == null
                                ? 'Upload your valid driver license.'
                                : 'Selected: ${_fileName(_driverLicense!)}',
                            icon: Icons.card_membership_outlined,
                            onCamera:
                                () => _pickFile(camera: true, type: 'license'),
                            onGallery: () =>
                                _pickFile(camera: false, type: 'license'),
                            selected: _driverLicense != null,
                          ),
                          const SizedBox(height: 12),
                          _KycTile(
                            title: 'Selfie',
                            subtitle: _selfie == null
                                ? 'Take a clear selfie with good lighting.'
                                : 'Selected: ${_fileName(_selfie!)}',
                            icon: Icons.camera_alt_outlined,
                            onCamera:
                                () => _pickFile(camera: true, type: 'selfie'),
                            onGallery:
                                () => _pickFile(camera: false, type: 'selfie'),
                            selected: _selfie != null,
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            label: _uploading ? 'Uploading...' : 'Submit for review',
                            onTap: _submit,
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

  String _fileName(XFile file) {
    final name = file.path.split(Platform.pathSeparator).last;
    return name.length > 22 ? '${name.substring(0, 19)}...' : name;
  }
}

class _KycTile extends StatelessWidget {
  const _KycTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onCamera,
    required this.onGallery,
    required this.selected,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.stroke,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.accent),
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
                    const SizedBox(height: 4),
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
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.accent),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery'),
                ),
              ),
            ],
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
