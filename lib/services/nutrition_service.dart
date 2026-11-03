import '../models/nutrition.dart';
import 'api_client.dart';

/// 首页营养总览与推荐接口。
class NutritionService {
  /// 并行读取今日营养进度和午餐推荐，两次请求都携带登录 token。
  static Future<HomeDashboard> loadDashboard() async {
    final responses = await Future.wait<dynamic>([
      ApiClient.get('/api/nutrition/progress', auth: true),
      ApiClient.get('/api/recommendations?meal_type=lunch&limit=3', auth: true),
    ]);

    final progressJson = (responses[0] as Map).cast<String, dynamic>();
    final recommendationJson = (responses[1] as Map).cast<String, dynamic>();
    final rawRecipes =
        recommendationJson['recommendations'] as List<dynamic>? ?? [];

    return HomeDashboard(
      progress: NutritionProgress.fromJson(progressJson),
      recommendationMessage:
          recommendationJson['message']?.toString() ?? '',
      recommendations: rawRecipes
          .map((item) => RecommendedRecipe.fromJson(
              (item as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
