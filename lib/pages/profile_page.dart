import 'package:flutter/material.dart';
import 'records_page.dart';
import '../services/auth_service.dart';
import '../services/session.dart';
import '../theme.dart';

/// Tab 4 · 我的：身体档案 + 目标 + 设置
class ProfilePage extends StatefulWidget {
  final Future<void> Function() onLogout;
  const ProfilePage({super.key, required this.onLogout});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _goal = '减脂';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          AppCard(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.person, size: 32, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SessionStore.username ?? '未登录',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text('已登录 · 数据保存在本机后端',
                        style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const SectionTitle('身体档案'),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metric('身高', '175', 'cm'),
                    _metric('体重', '72', 'kg'),
                    _metric('BMI', '23.5', ''),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metric('每日目标', '2100', 'kcal'),
                    _metric('蛋白质', '120', 'g'),
                    _metric('每周训练', '4', '次'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const SectionTitle('我的目标'),
          const SizedBox(height: 12),
          Row(
            children: ['减脂', '增肌', '维持'].map((g) {
              final selected = g == _goal;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _goal = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        g,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            '当前为「$_goal」目标，推荐热量与营养素比例已相应调整',
            style: const TextStyle(fontSize: 11, color: AppColors.textLight),
          ),

          const SizedBox(height: 20),
          const SectionTitle('更多功能'),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _tile(
                  Icons.history,
                  '历史饮食记录',
                  '按日期查看',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RecordsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 52),
                _tile(Icons.chat_bubble_outline, '营养顾问', 'AI 在线答疑'),
                const Divider(height: 1, indent: 52),
                _tile(Icons.download_outlined, '导出我的数据', 'JSON 格式'),
                const Divider(height: 1, indent: 52),
                _tile(Icons.info_outline, '关于系统', '课程演示版 v1.0'),
              ],
            ),
          ),

          const SizedBox(height: 20),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
                side: const BorderSide(color: Color(0xFFFFCDD2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('退出登录'),
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            '营养数据为课程演示近似值，仅供参考，不构成医疗建议',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.textLight),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出', style: TextStyle(color: Color(0xFFC62828))),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await AuthService.logout();
    if (mounted) await widget.onLogout();
  }

  Widget _metric(String label, String value, String unit) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            text: value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
            children: [
              TextSpan(text: ' $unit', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textLight)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
      ],
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textLight),
      dense: true,
      onTap: onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('「$title」将在下一版本接入'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
    );
  }
}
