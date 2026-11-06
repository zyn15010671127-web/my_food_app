double _number(Map<String, dynamic> json, String key) {
  return (json[key] as num? ?? 0).toDouble();
}

/// 一条已保存的饮食记录，营养值是保存时的历史快照。
class MealRecord {
  final int id;
  final int foodId;
  final String foodName;
  final double grams;
  final String mealType;
  final String recordDate;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String source;

  const MealRecord({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.grams,
    required this.mealType,
    required this.recordDate,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.source,
  });

  factory MealRecord.fromJson(Map<String, dynamic> json) {
    return MealRecord(
      id: (json['id'] as num? ?? 0).toInt(),
      foodId: (json['food_id'] as num? ?? 0).toInt(),
      foodName: json['food_name']?.toString() ?? '未命名食物',
      grams: _number(json, 'grams'),
      mealType: json['meal_type']?.toString() ?? 'lunch',
      recordDate: json['record_date']?.toString() ?? '',
      calories: _number(json, 'calories_kcal'),
      protein: _number(json, 'protein_g'),
      carbs: _number(json, 'carbs_g'),
      fat: _number(json, 'fat_g'),
      source: json['source']?.toString() ?? 'manual',
    );
  }
}
