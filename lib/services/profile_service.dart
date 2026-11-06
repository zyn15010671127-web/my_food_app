import '../models/nutrition.dart';
import '../models/user_profile.dart';
import 'api_client.dart';

/// 个人档案读取、保存与营养目标重算。
class ProfileService {
  static Future<UserProfile> getProfile() async {
    final data = await ApiClient.get('/api/profile/me', auth: true);
    return UserProfile.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<bool> hasProfile() async {
    try {
      await getProfile();
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 404) return false;
      // 登录已经成功时，临时网络问题不应把用户挡在登录页。
      return true;
    } catch (_) {
      return true;
    }
  }

  static Future<UserProfile> saveProfile(UserProfile profile) async {
    final data = await ApiClient.put(
      '/api/profile/me',
      profile.toSaveJson(),
      auth: true,
    );
    return UserProfile.fromJson((data as Map).cast<String, dynamic>());
  }

  static Future<NutritionValues> getTarget() async {
    // 与首页读取同一个接口、同一个 target 字段，避免两个页面口径不一致。
    final data = await ApiClient.get('/api/nutrition/progress', auth: true);
    final progress = (data as Map).cast<String, dynamic>();
    final target = (progress['target'] as Map).cast<String, dynamic>();
    return NutritionValues.fromJson(target);
  }

  static Future<void> recalculateTarget() async {
    await ApiClient.post('/api/nutrition/target/recalculate', {}, auth: true);
  }

  static Future<ProfileOverview> loadOverview() async {
    final responses = await Future.wait<dynamic>([
      getProfile(),
      getTarget(),
    ]);
    return ProfileOverview(
      profile: responses[0] as UserProfile,
      target: responses[1] as NutritionValues,
    );
  }
}
