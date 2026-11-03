double _number(Map<String, dynamic> json, String key) {
  return (json[key] as num? ?? 0).toDouble();
}

Map<String, dynamic> _map(dynamic value) {
  return (value as Map).cast<String, dynamic>();
}

/// 食物库中可供识别结果核对的食物。
class FoodOption {
  final int id;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const FoodOption({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory FoodOption.fromJson(Map<String, dynamic> json) {
    return FoodOption(
      id: (json['id'] as num? ?? 0).toInt(),
      name: json['name']?.toString() ?? '未命名食物',
      calories: _number(json, 'calories_kcal'),
      protein: _number(json, 'protein_g'),
      carbs: _number(json, 'carbs_g'),
      fat: _number(json, 'fat_g'),
    );
  }
}

/// 外部视觉服务返回的一道候选菜品。
class RecognitionDish {
  final String name;
  final double confidence;
  final int? foodId;

  const RecognitionDish({
    required this.name,
    required this.confidence,
    required this.foodId,
  });

  factory RecognitionDish.fromJson(Map<String, dynamic> json) {
    return RecognitionDish(
      name: json['name']?.toString() ?? '未命名菜品',
      confidence: _number(json, 'confidence'),
      foodId: (json['food_id'] as num?)?.toInt(),
    );
  }
}

/// POST /api/recognitions 的响应。
class RecognitionResult {
  final String id;
  final String imageId;
  final String status;
  final String mode;
  final String message;
  final List<RecognitionDish> dishes;
  final List<int> confirmedRecordIds;

  const RecognitionResult({
    required this.id,
    required this.imageId,
    required this.status,
    required this.mode,
    required this.message,
    required this.dishes,
    required this.confirmedRecordIds,
  });

  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    final rawDishes = json['dishes'] as List<dynamic>? ?? [];
    final rawRecordIds = json['confirmed_record_ids'] as List<dynamic>? ?? [];
    return RecognitionResult(
      id: json['id']?.toString() ?? '',
      imageId: json['image_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      mode: json['mode']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      dishes: rawDishes
          .map((item) => RecognitionDish.fromJson(_map(item)))
          .toList(),
      confirmedRecordIds: rawRecordIds
          .map((item) => (item as num).toInt())
          .toList(),
    );
  }
}
