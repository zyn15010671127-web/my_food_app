/// 后端营养接口的数据模型。
///
/// 所有营养数值统一使用 double，避免后端返回整数或小数时解析失败。
library;

double _readNumber(Map<String, dynamic> json, String key) {
  return (json[key] as num? ?? 0).toDouble();
}

Map<String, dynamic> _readMap(dynamic value) {
  return (value as Map).cast<String, dynamic>();
}

/// 一组热量与三大营养素数值。
class NutritionValues {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const NutritionValues({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory NutritionValues.fromJson(Map<String, dynamic> json) {
    return NutritionValues(
      calories: _readNumber(json, 'calories_kcal'),
      protein: _readNumber(json, 'protein_g'),
      carbs: _readNumber(json, 'carbs_g'),
      fat: _readNumber(json, 'fat_g'),
    );
  }
}

/// GET /api/nutrition/progress 的响应。
class NutritionProgress {
  final String recordDate;
  final NutritionValues target;
  final NutritionValues consumed;
  final NutritionValues remaining;
  final NutritionValues exceeded;
  final NutritionValues completionPercent;

  const NutritionProgress({
    required this.recordDate,
    required this.target,
    required this.consumed,
    required this.remaining,
    required this.exceeded,
    required this.completionPercent,
  });

  factory NutritionProgress.fromJson(Map<String, dynamic> json) {
    return NutritionProgress(
      recordDate: json['record_date']?.toString() ?? '',
      target: NutritionValues.fromJson(_readMap(json['target'])),
      consumed: NutritionValues.fromJson(_readMap(json['consumed'])),
      remaining: NutritionValues.fromJson(_readMap(json['remaining'])),
      exceeded: NutritionValues.fromJson(_readMap(json['exceeded'])),
      completionPercent:
          NutritionValues.fromJson(_readMap(json['completion_percent'])),
    );
  }
}

/// 推荐菜谱中的一种食材。
class RecipeIngredient {
  final String foodName;
  final double grams;

  const RecipeIngredient({required this.foodName, required this.grams});

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      foodName: json['food_name']?.toString() ?? '未命名食材',
      grams: _readNumber(json, 'grams'),
    );
  }

  String get label {
    final weight = grams == grams.roundToDouble()
        ? grams.toStringAsFixed(0)
        : grams.toStringAsFixed(1);
    return '$foodName ${weight}g';
  }
}

/// /api/recommendations 中的一项推荐。
class RecommendedRecipe {
  final int id;
  final String name;
  final String cuisine;
  final List<RecipeIngredient> ingredients;
  final double calories;
  final double protein;
  final double matchScore;
  final String reason;

  const RecommendedRecipe({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.ingredients,
    required this.calories,
    required this.protein,
    required this.matchScore,
    required this.reason,
  });

  factory RecommendedRecipe.fromJson(Map<String, dynamic> json) {
    final recipe = _readMap(json['recipe']);
    final rawIngredients = recipe['ingredients'] as List<dynamic>? ?? [];
    return RecommendedRecipe(
      id: (recipe['id'] as num? ?? 0).toInt(),
      name: recipe['name']?.toString() ?? '未命名菜谱',
      cuisine: recipe['cuisine']?.toString() ?? '推荐',
      ingredients: rawIngredients
          .map((item) => RecipeIngredient.fromJson(_readMap(item)))
          .toList(),
      calories: _readNumber(recipe, 'calories_kcal'),
      protein: _readNumber(recipe, 'protein_g'),
      matchScore: _readNumber(json, 'match_score'),
      reason: json['reason']?.toString() ?? '',
    );
  }
}

/// 首页需要的全部真实数据。
class HomeDashboard {
  final NutritionProgress progress;
  final String recommendationMessage;
  final List<RecommendedRecipe> recommendations;

  const HomeDashboard({
    required this.progress,
    required this.recommendationMessage,
    required this.recommendations,
  });
}
