import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session.dart';

/// 统一的接口异常，message 已转成可直接展示给用户的中文
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// 后端 HTTP 客户端封装
///
/// 注意：
/// 1. 真机 / Android 模拟器调试时，127.0.0.1 要改成电脑局域网 IP（模拟器可用 10.0.2.2）
/// 2. Flutter Web 必须用 --web-port=8080 启动，否则会被后端 CORS 拦截
class ApiClient {
  static const String baseUrl = 'http://127.0.0.1:8010';
  static const Duration _timeout = Duration(seconds: 10);

  static Map<String, String> _headers({bool auth = false}) {
    final headers = {'Content-Type': 'application/json'};
    final t = SessionStore.token;
    if (auth && t != null && t.isNotEmpty) {
      headers['Authorization'] = 'Bearer $t';
    }
    return headers;
  }

  static Future<dynamic> get(String path, {bool auth = false}) async {
    final res = await http
        .get(Uri.parse('$baseUrl$path'), headers: _headers(auth: auth))
        .timeout(_timeout);
    return _handle(res);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body, {bool auth = false}) async {
    final res = await http
        .post(Uri.parse('$baseUrl$path'), headers: _headers(auth: auth), body: jsonEncode(body))
        .timeout(_timeout);
    return _handle(res);
  }

  static dynamic _handle(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    dynamic data;
    try {
      data = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      data = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    var msg = '请求失败（${res.statusCode}）';
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      // 参数校验失败时 detail 是数组，取第一条原因
      msg = d is List && d.isNotEmpty ? (d.first['msg']?.toString() ?? msg) : d.toString();
    } else if (res.statusCode == 401) {
      msg = '登录已过期，请重新登录';
    }
    throw ApiException(res.statusCode, msg);
  }
}
