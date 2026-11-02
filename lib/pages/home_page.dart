import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../theme.dart';
import '../widgets/ring_chart.dart';

/// Tab 1 · 首页：今日摄入总览 + 推荐菜谱
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const remaining = DemoData.calorieTarget - DemoData.calorieIntake;
    const progress = DemoData.calorieIntake / DemoData.calorieTarget;

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日饮食'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text(
            '坚持记录的第 7 天，继续保持',
            style: TextStyle(color: AppColors.textLight, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // 热量总览卡
          AppCard(
            child: Row(
              children: [
                RingChart(
                  progress: progress,
                  size: 132,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${DemoData.calorieIntake}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                      ),
                      const Text('已摄入 kcal', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statRow('今日目标', '${DemoData.calorieTarget} kcal'),
                      const SizedBox(height: 10),
                      _statRow('剩余可吃', '$remaining kcal', highlight: true),
                      const SizedBox(height: 10),
                      _statRow('进度', '${(progress * 100).round()}%'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const SectionTitle('三大营养素', trailing: '目标 / 已摄入'),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                _macroBar('蛋白质', DemoData.proteinIntake, DemoData.proteinTarget, AppColors.protein),
                const SizedBox(height: 14),
                _macroBar('碳水', DemoData.carbsIntake, DemoData.carbsTarget, AppColors.carbs),
                const SizedBox(height: 14),
                _macroBar('脂肪', DemoData.fatIntake, DemoData.fatTarget, AppColors.fat),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const SectionTitle('为你推荐', trailing: '按剩余热量'),
          const SizedBox(height: 12),
          ...DemoData.recipes.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: r.scene == '食堂' ? AppColors.primaryLight : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r.scene,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: r.scene == '食堂' ? AppColors.primaryDark : const Color(0xFFE65100),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(r.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                          const Icon(Icons.chevron_right, size: 18, color: AppColors.textLight),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(r.items.join(' · '),
                          style: const TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.5)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.local_fire_department, size: 15, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text('${r.calories} kcal', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 16),
                          const Icon(Icons.fitness_center, size: 14, color: AppColors.protein),
                          const SizedBox(width: 4),
                          Text('蛋白质 ${r.protein} g', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
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

  Widget _macroBar(String name, double intake, double target, Color color) {
    final p = (intake / target).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${intake.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} g',
                style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: p,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
