import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppSession {
  static const _storage = FlutterSecureStorage();
  static String? jwt;
  static String? uid;

  static Future<void> init() async {
    jwt = await _storage.read(key: 'jwt');
    uid = await _storage.read(key: 'uid');
  }

  static Future<void> save({required String token, required String userId}) async {
    jwt = token;
    uid = userId;
    await _storage.write(key: 'jwt', value: token);
    await _storage.write(key: 'uid', value: userId);
  }

  static Future<void> clear() async {
    jwt = null;
    uid = null;
    await _storage.delete(key: 'jwt');
    await _storage.delete(key: 'uid');
  }
}
