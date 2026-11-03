import '../models/recognition.dart';
import 'api_client.dart';

/// 图片上传、识别、食物库查询和识别确认接口。
class RecognitionService {
  static Future<RecognitionResult> recognize({
    required List<int> imageBytes,
    required String filename,
    required bool allowExternalProcessing,
  }) async {
    final uploaded = await ApiClient.uploadBytes(
      '/api/uploads/images',
      imageBytes,
      filename,
      auth: true,
    );
    final imageId = (uploaded as Map)['id']?.toString() ?? '';
    if (imageId.isEmpty) {
      throw ApiException(500, '后端未返回图片编号');
    }

    final data = await ApiClient.post(
      '/api/recognitions',
      {
        'image_id': imageId,
        'allow_external_processing': allowExternalProcessing,
      },
      auth: true,
      // 外部视觉服务本身可能耗时 20 秒，不能使用默认的 10 秒超时。
      timeout: const Duration(seconds: 40),
    );
    return RecognitionResult.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  static Future<List<FoodOption>> loadFoods() async {
    final data = await ApiClient.get('/api/foods?offset=0&limit=100', auth: true);
    return (data as List<dynamic>)
        .map((item) => FoodOption.fromJson(
            (item as Map).cast<String, dynamic>()))
        .toList();
  }

  /// 用户核对后原子保存全部食物，返回写入的饮食记录数。
  static Future<int> confirm({
    required String recognitionId,
    required String mealType,
    required String recordDate,
    required List<Map<String, dynamic>> items,
  }) async {
    final data = await ApiClient.post(
      '/api/recognitions/$recognitionId/confirm',
      {
        'meal_type': mealType,
        'record_date': recordDate,
        'items': items,
      },
      auth: true,
    );
    return (data as List<dynamic>).length;
  }
}
