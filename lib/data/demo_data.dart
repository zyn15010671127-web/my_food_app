import '../models/food.dart';

/// D1 演示用假数据。后续接入后端 /api/foods 后替换本文件。
/// 营养值按每 100 克可食部分，来源为课程演示近似值。
class DemoData {
  static const int calorieTarget = 2100;
  static const int calorieIntake = 1380;

  static const double proteinTarget = 120;
  static const double proteinIntake = 62;
  static const double carbsTarget = 260;
  static const double carbsIntake = 168;
  static const double fatTarget = 58;
  static const double fatIntake = 42;

  static const List<Food> foods = [
    Food(name: '米饭（熟）', calories: 116, protein: 2.6, carbs: 25.9, fat: 0.3, category: '主食'),
    Food(name: '糙米饭（熟）', calories: 111, protein: 2.6, carbs: 23.0, fat: 0.9, category: '主食'),
    Food(name: '全麦面包', calories: 250, protein: 9.0, carbs: 43.0, fat: 4.0, category: '主食'),
    Food(name: '燕麦片（干）', calories: 380, protein: 13.5, carbs: 66.0, fat: 7.0, category: '主食'),
    Food(name: '鸡胸肉（水煮）', calories: 133, protein: 23.3, carbs: 0.0, fat: 3.6, category: '荤菜'),
    Food(name: '红烧鸡腿', calories: 209, protein: 17.5, carbs: 3.2, fat: 13.6, category: '荤菜'),
    Food(name: '番茄炒蛋', calories: 122, protein: 7.4, carbs: 5.8, fat: 7.8, category: '荤菜'),
    Food(name: '清蒸鲈鱼', calories: 105, protein: 18.6, carbs: 0.0, fat: 3.4, category: '荤菜'),
    Food(name: '宫保鸡丁', calories: 178, protein: 14.2, carbs: 9.1, fat: 9.6, category: '荤菜'),
    Food(name: '红烧肉', calories: 477, protein: 11.4, carbs: 6.2, fat: 46.1, category: '荤菜'),
    Food(name: '西兰花（清炒）', calories: 43, protein: 3.1, carbs: 5.2, fat: 1.6, category: '素菜'),
    Food(name: '蒜蓉油麦菜', calories: 58, protein: 2.0, carbs: 3.4, fat: 4.1, category: '素菜'),
    Food(name: '麻婆豆腐', calories: 137, protein: 8.6, carbs: 5.4, fat: 8.8, category: '素菜'),
    Food(name: '凉拌黄瓜', calories: 26, protein: 0.8, carbs: 3.6, fat: 0.9, category: '素菜'),
    Food(name: '紫菜蛋花汤', calories: 28, protein: 2.2, carbs: 1.6, fat: 1.2, category: '汤'),
    Food(name: '玉米排骨汤', calories: 86, protein: 6.4, carbs: 5.1, fat: 4.6, category: '汤'),
  ];

  static const List<Recipe> recipes = [
    Recipe(
      name: '高蛋白减脂餐',
      items: ['糙米饭 150g', '水煮鸡胸肉 120g', '清炒西兰花 100g'],
      calories: 486,
      protein: 38.5,
      scene: '食堂',
    ),
    Recipe(
      name: '均衡家常餐',
      items: ['米饭 150g', '番茄炒蛋 150g', '蒜蓉油麦菜 120g'],
      calories: 550,
      protein: 16.2,
      scene: '食堂',
    ),
    Recipe(
      name: '低卡轻食餐',
      items: ['全麦面包 80g', '清蒸鲈鱼 120g', '凉拌黄瓜 150g'],
      calories: 396,
      protein: 30.8,
      scene: '外卖',
    ),
  ];
}
