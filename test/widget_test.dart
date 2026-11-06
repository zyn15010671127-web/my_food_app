import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_food_app/models/meal_record.dart';
import 'package:my_food_app/models/nutrition.dart';
import 'package:my_food_app/models/recognition.dart';
import 'package:my_food_app/pages/home_page.dart';
import 'package:my_food_app/pages/records_page.dart';
import 'package:my_food_app/pages/scan_page.dart';
import 'package:my_food_app/pages/search_page.dart';

MealRecord _fakeMealRecord() {
  return MealRecord.fromJson({
    'id': 1,
    'food_id': 1,
    'food_name': '米饭（熟）',
    'grams': 150,
    'meal_type': 'lunch',
    'record_date': '2026-11-05',
    'calories_kcal': 174,
    'protein_g': 3.9,
    'carbs_g': 38.85,
    'fat_g': 0.45,
    'source': 'manual',
  });
}

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

  test('识别降级响应和食物库 JSON 能正确解析', () {
    final result = RecognitionResult.fromJson({
      'id': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'image_id': 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      'status': 'manual_required',
      'mode': 'local_fallback',
      'message': '请手动核对',
      'dishes': <dynamic>[],
      'confirmed_record_ids': <dynamic>[],
    });
    final food = FoodOption.fromJson({
      'id': 1,
      'name': '测试食物',
      'calories_kcal': 100,
      'protein_g': 5,
      'carbs_g': 15,
      'fat_g': 3,
    });
    expect(result.status, 'manual_required');
    expect(result.dishes, isEmpty);
    expect(food.name, '测试食物');
    expect(food.calories, 100.0);
  });

  testWidgets('识别页初始状态正常渲染', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ScanPage()));
    expect(find.text('拍照识别'), findsOneWidget);
    expect(find.text('拍摄或选择菜品照片'), findsOneWidget);
    expect(find.text('允许使用外部视觉服务'), findsOneWidget);
  });

  test('饮食记录 JSON 能正确解析', () {
    final record = _fakeMealRecord();
    expect(record.foodName, '米饭（熟）');
    expect(record.grams, 150.0);
    expect(record.calories, 174.0);
    expect(record.mealType, 'lunch');
  });

  testWidgets('食物库展示接口返回的食物', (WidgetTester tester) async {
    const food = FoodOption(
      id: 5,
      name: '鸡胸肉（水煮）',
      calories: 133,
      protein: 23.3,
      carbs: 0,
      fat: 3.6,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SearchPage(
          foodLoader: ({
            required String query,
            required int offset,
            required int limit,
          }) async => [food],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('鸡胸肉（水煮）'), findsOneWidget);
    expect(find.text('133'), findsOneWidget);
  });

  testWidgets('饮食记录页展示餐次和食物', (WidgetTester tester) async {
    final record = _fakeMealRecord();
    await tester.pumpWidget(
      MaterialApp(
        home: RecordsPage(recordsLoader: (_) async => [record]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('饮食记录'), findsOneWidget);
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('米饭（熟）'), findsOneWidget);
    expect(find.text('174'), findsOneWidget);
  });
}
