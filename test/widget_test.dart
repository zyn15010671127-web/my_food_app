import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_food_app/models/nutrition.dart';
import 'package:my_food_app/pages/home_page.dart';

HomeDashboard _fakeDashboard() {
  final progress = NutritionProgress.fromJson({
    'record_date': '2026-11-03',
    'target': {
      'calories_kcal': 2100,
      'protein_g': 120,
      'carbs_g': 260,
      'fat_g': 58,
    },
    'consumed': {
      'calories_kcal': 1380,
      'protein_g': 62,
      'carbs_g': 168,
      'fat_g': 42,
    },
    'remaining': {
      'calories_kcal': 720,
      'protein_g': 58,
      'carbs_g': 92,
      'fat_g': 16,
    },
    'exceeded': {
      'calories_kcal': 0,
      'protein_g': 0,
      'carbs_g': 0,
      'fat_g': 0,
    },
    'completion_percent': {
      'calories_kcal': 65.71,
      'protein_g': 51.67,
      'carbs_g': 64.62,
      'fat_g': 72.41,
    },
  });
  final recipe = RecommendedRecipe.fromJson({
    'match_score': 92.5,
    'reason': '测试推荐原因',
    'recipe': {
      'id': 1,
      'name': '高蛋白减脂餐',
      'cuisine': '家常',
      'calories_kcal': 486,
      'protein_g': 38.5,
      'ingredients': [
        {'food_name': '糙米饭', 'grams': 150},
        {'food_name': '鸡胸肉', 'grams': 120},
      ],
    },
  });
  return HomeDashboard(
    progress: progress,
    recommendationMessage: '测试推荐说明',
    recommendations: [recipe],
  );
}

void main() {
  test('后端营养 JSON 能正确解析整数和小数', () {
    final dashboard = _fakeDashboard();
    expect(dashboard.progress.target.calories, 2100.0);
    expect(dashboard.progress.consumed.protein, 62.0);
    expect(dashboard.recommendations.single.ingredients.first.label, '糙米饭 150g');
  });

  testWidgets('首页展示真实营养数据与推荐菜谱', (WidgetTester tester) async {
    final dashboard = _fakeDashboard();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(dashboardLoader: () async => dashboard),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日饮食'), findsOneWidget);
    expect(find.text('1380'), findsOneWidget);
    expect(find.text('2100 kcal'), findsOneWidget);
    expect(find.text('62 / 120 g'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('高蛋白减脂餐'), 300);
    expect(find.text('高蛋白减脂餐'), findsOneWidget);
    expect(find.text('糙米饭 150g · 鸡胸肉 120g'), findsOneWidget);
  });
}
