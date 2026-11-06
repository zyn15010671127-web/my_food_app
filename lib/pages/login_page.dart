import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme.dart';

/// 登录 / 注册页
class LoginPage extends StatefulWidget {
  final ValueChanged<bool> onSuccess;
  const LoginPage({super.key, required this.onSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _isRegister = false;
  bool _busy = false;
  bool _obscure = true;
  bool? _backendOnline; // null=检测中 true/false=结果
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    final ok = await AuthService.checkBackend();
    if (mounted) setState(() => _backendOnline = ok);
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;

    // 前端先校验，规则与后端保持一致，避免无谓的 422
    if (!RegExp(r'^[a-z0-9_]{3,32}$').hasMatch(username)) {
      setState(() => _error = '用户名需 3-32 位小写字母、数字或下划线');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = '密码至少 8 位');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final registering = _isRegister;
    try {
      if (registering) {
        await AuthService.register(username, password);
      } else {
        await AuthService.login(username, password);
      }
      // hasProfile 表示“已经有档案”，与 needsProfile 的含义正好相反。
      final hasProfile = registering ? false : await ProfileService.hasProfile();
      if (mounted) widget.onSuccess(!hasProfile);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '无法连接后端，请确认 backend/run.ps1 已启动');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fillDemo() {
    setState(() {
      _userCtrl.text = 'demo_user';
      _passCtrl.text = 'DemoPass123!';
      _isRegister = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                    child: const Icon(Icons.restaurant_menu, size: 44, color: AppColors.primary),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '智能饮食搭配推荐',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '拍照识菜 · 营养统计 · 科学推荐',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 12),
                  _backendBadge(),
                  const SizedBox(height: 24),

                  // 登录 / 注册切换
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        _tabButton('登录', !_isRegister, () => setState(() {
                              _isRegister = false;
                              _error = null;
                            })),
                        _tabButton('注册', _isRegister, () => setState(() {
                              _isRegister = true;
                              _error = null;
                            })),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _userCtrl,
                    autocorrect: false,
                    decoration: _decoration('用户名', Icons.person_outline, hint: '小写字母、数字或下划线'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: _decoration('密码', Icons.lock_outline, hint: '至少 8 位').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onSubmitted: (_) => _busy ? null : _submit(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: Color(0xFFC62828)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFC62828)))),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isRegister ? '注册并登录' : '登录', style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _busy ? null : _fillDemo,
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text('使用演示账号一键填充'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _backendBadge() {
    final online = _backendOnline;
    final color = online == null
        ? AppColors.textLight
        : online
            ? AppColors.primary
            : AppColors.accent;
    final text = online == null
        ? '正在检测后端连接…'
        : online
            ? '后端已连接（127.0.0.1:8010）'
            : '后端未启动，请先运行 backend/run.ps1';
    return GestureDetector(
      onTap: _checkBackend,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textLight,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12),
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}
