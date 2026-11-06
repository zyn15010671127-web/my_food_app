import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/session.dart';
import '../theme.dart';
import 'profile_form_page.dart';
import 'records_page.dart';

typedef ProfileOverviewLoader = Future<ProfileOverview> Function();

/// Tab 4 · 真实个人档案、营养目标与账号功能。
class ProfilePage extends StatefulWidget {
  final Future<void> Function() onLogout;
  final ProfileOverviewLoader? overviewLoader;
  final VoidCallback? onProfileUpdated;

  const ProfilePage({
    super.key,
    required this.onLogout,
    this.overviewLoader,
    this.onProfileUpdated,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<ProfileOverview> _overviewFuture;

  @override
  void initState() {
    super.initState();
    _overviewFuture = _loadOverview();
  }

  Future<ProfileOverview> _loadOverview() {
    return widget.overviewLoader?.call() ?? ProfileService.loadOverview();
  }

  void _reload() {
    setState(() {
      _overviewFuture = _loadOverview();
    });
  }

  Future<void> _refresh() async {
    final next = _loadOverview();
    setState(() {
      _overviewFuture = next;
    });
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _editProfile(UserProfile? profile) async {
    try {
      // 兼容不同补丁版本：旧编辑页返回 UserProfile，新编辑页返回 ProfileOverview。
      final result = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute<dynamic>(
          builder: (_) => ProfileFormPage(initialProfile: profile),
        ),
      );
      if (result == null || !mounted) return;

      final ProfileOverview saved;
      if (result is ProfileOverview) {
        saved = result;
      } else if (result is UserProfile) {
        final target = await ProfileService.getTarget();
        if (!mounted) return;
        saved = ProfileOverview(profile: result, target: target);
      } else {
        throw StateError('编辑页返回了无法识别的数据类型');
      }

      widget.onProfileUpdated?.call();
      if (!mounted) return;
      // 不论编辑页来自哪个版本，都直接显示后端保存后的新档案。
      setState(() {
        _overviewFuture = Future<ProfileOverview>.value(saved);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('档案已更新，身高、体重和营养目标已同步')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? '档案已保存，但最新目标读取失败：${error.message}'
          : '档案页面更新失败：$error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          TextButton(
            onPressed: widget.onLogout,
            child: const Text('退出登录'),
          ),
          IconButton(
            onPressed: _reload,
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<ProfileOverview>(
          future: _overviewFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return _loadingView();
            }
            if (!snapshot.hasData) {
              return _errorView(snapshot.error);
            }
            return _profileView(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _loadingView() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 180),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _errorView(Object? error) {
    final missingProfile = error is ApiException && error.statusCode == 404;
    final unauthorized = error is ApiException && error.statusCode == 401;
    final message = missingProfile
        ? '尚未建立个人档案，请先完成设置。'
        : error is ApiException
            ? error.message
            : '无法读取个人档案，请检查后端后重试。';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        AppCard(
          child: Column(
            children: [
              const Icon(Icons.person_off_outlined,
                  size: 40, color: AppColors.accent),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: unauthorized
                    ? widget.onLogout
                    : missingProfile
                        ? () => _editProfile(null)
                        : _reload,
                child: Text(
                  unauthorized
                      ? '重新登录'
                      : missingProfile
                          ? '填写档案'
                          : '重新加载',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileView(ProfileOverview overview) {
    final profile = overview.profile;
    final target = overview.target;
    final bodyFat = profile.bodyFatPercent;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SessionStore.username ?? '未登录',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profileSexLabel(profile.sex)} · ${profile.age} 岁 · '
                      '${profileGoalLabel(profile.goal)}目标',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _editProfile(profile),
                tooltip: '编辑档案',
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionTitle(
          '身体档案',
          trailing: '更新于 ${_dateLabel(profile.updatedAt)}',
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metric('身高', profile.heightCm.toStringAsFixed(0), 'cm'),
                  _metric('体重', profile.weightKg.toStringAsFixed(1), 'kg'),
                  _metric('BMI', profile.bmi.toStringAsFixed(1), ''),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metric('每日目标', target.calories.round().toString(), 'kcal'),
                  _metric('蛋白质', target.protein.toStringAsFixed(0), 'g'),
                  _metric(
                    '体脂率',
                    bodyFat == null ? '未填' : bodyFat.toStringAsFixed(1),
                    bodyFat == null ? '' : '%',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle('我的目标'),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profileGoalLabel(profile.goal),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _editProfile(profile),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('调整'),
                  ),
                ],
              ),
              Text(
                '活动强度：${profileActivityLabel(profile.activityLevel)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              const SizedBox(height: 6),
              Text(
                '碳水目标 ${target.carbs.toStringAsFixed(0)}g · '
                '脂肪目标 ${target.fat.toStringAsFixed(0)}g',
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
            ],
          ),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
    );
  }

  String _dateLabel(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
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
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
            children: [
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
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
      trailing:
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textLight),
      dense: true,
      onTap: onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('「$title」将在后续任务接入'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
    );
  }
}
