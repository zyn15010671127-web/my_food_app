import '../models/meal_record.dart';
import 'api_client.dart';

/// 饮食打卡、按日期查询和删除记录。
class MealService {
  static Future<MealRecord> addRecord({
    required int foodId,
    required double grams,
    required String mealType,
    required String recordDate,
  }) async {
    final data = await ApiClient.post(
      '/api/meal-records',
      {
        'food_id': foodId,
        'grams': grams,
        'meal_type': mealType,
        'record_date': recordDate,
      },
      auth: true,
    );
    return MealRecord.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<List<MealRecord>> listRecords(String recordDate) async {
    final data = await ApiClient.get(
      '/api/meal-records/me?record_date=$recordDate&offset=0&limit=100',
      auth: true,
    );
    return (data as List<dynamic>)
        .map((item) => MealRecord.fromJson(
            (item as Map).cast<String, dynamic>()))
        .toList();
  }

  static Future<void> deleteRecord(int recordId) async {
    await ApiClient.delete('/api/meal-records/$recordId', auth: true);
  }
}
