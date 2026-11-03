import 'package:flutter/material.dart';

import '../models/nutrition.dart';
import '../services/api_client.dart';
import '../services/nutrition_service.dart';
import '../theme.dart';
import '../widgets/ring_chart.dart';

typedef DashboardLoader = Future<HomeDashboard> Function();

/// Tab 1 · 首页：后端今日营养进度 + 后端推荐菜谱。
class HomePage extends StatefulWidget {
  /// 仅用于组件测试注入数据；正常运行时保持为空。
  final DashboardLoader? dashboardLoader;

  const HomePage({super.key, this.dashboardLoader});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late Future<HomeDashboard> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<HomeDashboard> _loadDashboard() {
    return widget.dashboardLoader?.call() ?? NutritionService.loadDashboard();
  }

  void _retry() {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
  }

  Future<void> _refresh() async {
    final next = _loadDashboard();
    setState(() {
      _dashboardFuture = next;
    });
    // RefreshIndicator 需要等待请求结束；错误由 FutureBuilder 展示。
    try {
      await next;
    } catch (_) {}
  }

  /// 识别页保存记录后，主框架切回首页时调用。
  Future<void> refresh() => _refresh();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日饮食'),
        actions: [
          IconButton(
            onPressed: _retry,
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<HomeDashboard>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return _loadingView();
            }
            if (!snapshot.hasData) {
              return _errorView(snapshot.error);
            }
            return _dashboardView(snapshot.data!);
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
        SizedBox(height: 16),
        Center(
          child: Text(
            '正在读取今日营养数据…',
            style: TextStyle(color: AppColors.textLight),
          ),
        ),
      ],
    );
  }

  Widget _errorView(Object? error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        AppCard(
          child: Column(
            children: [
              const Icon(Icons.cloud_off, size: 42, color: AppColors.accent),
              const SizedBox(height: 14),
              const Text(
                '暂时无法显示今日数据',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage(error),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textLight,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _errorMessage(Object? error) {
    if (error is ApiException) {
      if (error.statusCode == 404 && error.message.contains('档案')) {
        return '当前账号还没有个人档案，后端无法计算营养目标。本次演示请退出后使用 demo_user 登录。';
      }
      return error.message;
    }
    return '无法连接后端，请确认 backend/run.ps1 已启动，再点击重新加载。';
  }

  Widget _dashboardView(HomeDashboard dashboard) {
    final data = dashboard.progress;
    final calorieTarget = data.target.calories;
    final calorieIntake = data.consumed.calories;
    final calorieProgress =
        calorieTarget <= 0 ? 0.0 : calorieIntake / calorieTarget;
    final exceeded = data.exceeded.calories;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text(
          '${_dateLabel(data.recordDate)} · 数据来自后端',
          style: const TextStyle(color: AppColors.textLight, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          calorieIntake <= 0 ? '今天还没有饮食记录' : '今日饮食记录已汇总 · 下拉可刷新',
          style: const TextStyle(color: AppColors.textLight, fontSize: 12),
        ),
        const SizedBox(height: 16),

        // 热量总览卡
        AppCard(
          child: Row(
            children: [
              RingChart(
                progress: calorieProgress,
                size: 132,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${calorieIntake.round()}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const Text(
                      '已摄入 kcal',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statRow('今日目标', '${calorieTarget.round()} kcal'),
                    const SizedBox(height: 10),
                    _statRow(
                      exceeded > 0 ? '已超出' : '剩余可吃',
                      '${(exceeded > 0 ? exceeded : data.remaining.calories).round()} kcal',
                      highlight: true,
                    ),
                    const SizedBox(height: 10),
                    _statRow(
                      '进度',
                      '${data.completionPercent.calories.toStringAsFixed(0)}%',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const SectionTitle('三大营养素', trailing: '已摄入 / 目标'),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              _macroBar(
                '蛋白质',
                data.consumed.protein,
                data.target.protein,
                AppColors.protein,
              ),
              const SizedBox(height: 14),
              _macroBar(
                '碳水',
                data.consumed.carbs,
                data.target.carbs,
                AppColors.carbs,
              ),
              const SizedBox(height: 14),
              _macroBar(
                '脂肪',
                data.consumed.fat,
                data.target.fat,
                AppColors.fat,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const SectionTitle('为你推荐', trailing: '按当前剩余营养'),
        const SizedBox(height: 12),
        if (dashboard.recommendations.isEmpty)
          const AppCard(
            child: Text(
              '当前没有可推荐的菜谱，请稍后刷新或补充菜谱库。',
              style: TextStyle(color: AppColors.textLight),
            ),
          )
        else
          ...dashboard.recommendations.map(
            (recipe) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _recipeCard(recipe),
            ),
          ),
        if (dashboard.recommendationMessage.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            dashboard.recommendationMessage,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  String _dateLabel(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return '今日饮食';
    return '${date.month}月${date.day}日';
  }

  Widget _recipeCard(RecommendedRecipe recipe) {
    final ingredients = recipe.ingredients.isEmpty
        ? '食材信息待补充'
        : recipe.ingredients.map((item) => item.label).join(' · ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  recipe.cuisine,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  recipe.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ingredients,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textLight,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _recipeMetric(
                Icons.local_fire_department,
                AppColors.accent,
                '${recipe.calories.round()} kcal',
              ),
              _recipeMetric(
                Icons.fitness_center,
                AppColors.protein,
                '蛋白质 ${recipe.protein.toStringAsFixed(1)} g',
              ),
              Text(
                '${recipe.matchScore.toStringAsFixed(0)}% 匹配',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _recipeMetric(IconData icon, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _statRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: highlight ? AppColors.accent : AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _macroBar(
    String name,
    double intake,
    double target,
    Color color,
  ) {
    final progress = target <= 0
        ? 0.0
        : (intake / target).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              '${intake.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} g',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
