import 'api_client.dart';
import 'session.dart';

/// 认证相关接口：注册 / 登录 / 登出 / 后端连通性检查
class AuthService {
  /// 登录成功后保存 token 与用户名
  static Future<void> login(String username, String password) async {
    final data = await ApiClient.post('/api/auth/login', {
      'username': username,
      'password': password,
    });
    await SessionStore.save(data['access_token'] as String, username);
  }

  /// 注册成功后自动登录，省去用户再登一次
  static Future<void> register(String username, String password) async {
    await ApiClient.post('/api/auth/register', {
      'username': username,
      'password': password,
    });
    await login(username, password);
  }

  /// 登出：即使后端调用失败，也要清掉本地状态
  static Future<void> logout() async {
    try {
      await ApiClient.post('/api/auth/logout', {}, auth: true);
    } catch (_) {
      // 网络失败或 token 已失效都不影响本地退出
    }
  }

  /// 检查后端是否已启动，用于登录页的状态提示
  static Future<bool> checkBackend() async {
    try {
      await ApiClient.get('/api/health');
      return true;
    } catch (_) {
      return false;
    }
  }
}
