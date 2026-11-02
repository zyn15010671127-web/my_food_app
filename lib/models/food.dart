/// 食物营养模型，单位：每 100 克可食部分
class Food {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String category;

  const Food({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.category,
  });
}

/// 一次饮食打卡记录
class MealEntry {
  final Food food;
  final double grams;
  final String mealType; // 早餐 / 午餐 / 晚餐 / 加餐

  const MealEntry({required this.food, required this.grams, required this.mealType});

  double get calories => food.calories * grams / 100;
  double get protein => food.protein * grams / 100;
  double get carbs => food.carbs * grams / 100;
  double get fat => food.fat * grams / 100;
}

/// 推荐菜谱
class Recipe {
  final String name;
  final List<String> items;
  final int calories;
  final double protein;
  final String scene; // 食堂 / 外卖

  const Recipe({
    required this.name,
    required this.items,
    required this.calories,
    required this.protein,
    required this.scene,
  });
}
