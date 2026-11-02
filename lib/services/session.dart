import 'package:shared_preferences/shared_preferences.dart';

/// 本地登录状态存储（token + 用户名）
class SessionStore {
  static SharedPreferences? _prefs;

  /// 必须在 runApp 之前调用
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static bool get hasToken => (_prefs?.getString('token') ?? '').isNotEmpty;
  static String? get token => _prefs?.getString('token');
  static String? get username => _prefs?.getString('username');

  static Future<void> save(String token, String username) async {
    await _prefs?.setString('token', token);
    await _prefs?.setString('username', username);
  }

  static Future<void> clear() async {
    await _prefs?.remove('token');
    await _prefs?.remove('username');
  }
}
