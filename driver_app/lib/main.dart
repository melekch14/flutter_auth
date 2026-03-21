import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'services/session.dart';
import 'services/api_config.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/kyc_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSession.init();
  runApp(const RideApp());
}

class RideApp extends StatelessWidget {
  const RideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RideWave',
      theme: buildAppTheme(),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late Future<_AuthState> _stateFuture;

  @override
  void initState() {
    super.initState();
    _stateFuture = _resolveState();
  }

  Future<_AuthState> _resolveState() async {
    if (AppSession.jwt == null) return _AuthState.loggedOut;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/me'),
        headers: {'Authorization': 'Bearer ' + AppSession.jwt!},
      );
      if (response.statusCode >= 400) {
        return _AuthState.loggedOut;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final user = body['user'] as Map<String, dynamic>?;
      final status = user?['status']?.toString() ?? 'not_verified';
      return status == 'verified'
          ? _AuthState.verified
          : _AuthState.needsKyc;
    } catch (_) {
      return _AuthState.loggedOut;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AuthState>(
      future: _stateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final state = snapshot.data ?? _AuthState.loggedOut;
        switch (state) {
          case _AuthState.verified:
            return const HomeScreen();
          case _AuthState.needsKyc:
            return const KycScreen();
          case _AuthState.loggedOut:
          default:
            return const LoginScreen();
        }
      },
    );
  }
}

enum _AuthState { loggedOut, verified, needsKyc }
