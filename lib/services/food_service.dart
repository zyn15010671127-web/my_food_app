import '../models/recognition.dart';
import 'api_client.dart';

/// 食物库公开查询接口。
class FoodService {
  static Future<List<FoodOption>> search({
    String query = '',
    int offset = 0,
    int limit = 20,
  }) async {
    final keyword = Uri.encodeQueryComponent(query.trim());
    final data = await ApiClient.get(
      '/api/foods?q=$keyword&offset=$offset&limit=$limit',
      auth: true,
    );
    return (data as List<dynamic>)
        .map((item) => FoodOption.fromJson(
            (item as Map).cast<String, dynamic>()))
        .toList();
  }
}
