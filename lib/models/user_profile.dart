import 'nutrition.dart';

double _number(Map<String, dynamic> json, String key) {
  return (json[key] as num? ?? 0).toDouble();
}

/// 当前用户的身体档案与健身目标。
class UserProfile {
  final String sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final String goal;
  final String activityLevel;
  final double? bodyFatPercent;
  final double bmi;
  final String updatedAt;

  const UserProfile({
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
    required this.activityLevel,
    required this.bodyFatPercent,
    required this.bmi,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      sex: json['sex']?.toString() ?? 'female',
      age: (json['age'] as num? ?? 18).toInt(),
      heightCm: _number(json, 'height_cm'),
      weightKg: _number(json, 'weight_kg'),
      goal: json['goal']?.toString() ?? 'maintain',
      activityLevel: json['activity_level']?.toString() ?? 'sedentary',
      bodyFatPercent: (json['body_fat_percent'] as num?)?.toDouble(),
      bmi: _number(json, 'bmi'),
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toSaveJson() {
    return {
      'sex': sex,
      'age': age,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'goal': goal,
      'activity_level': activityLevel,
      'body_fat_percent': bodyFatPercent,
    };
  }
}

/// “我的”页面所需的档案和当日营养目标。
class ProfileOverview {
  final UserProfile profile;
  final NutritionValues target;

  const ProfileOverview({required this.profile, required this.target});
}

String profileSexLabel(String value) {
  return value == 'male' ? '男' : '女';
}

String profileGoalLabel(String value) {
  const labels = {
    'lose_fat': '减脂',
    'gain_muscle': '增肌',
    'shape': '塑形',
    'maintain': '维持',
  };
  return labels[value] ?? value;
}

String profileActivityLabel(String value) {
  const labels = {
    'sedentary': '久坐（几乎不运动）',
    'light': '轻度（每周 1–3 次）',
    'moderate': '中度（每周 3–5 次）',
    'high': '高度（每周 6–7 次）',
    'very_high': '极高（高强度训练或体力工作）',
  };
  return labels[value] ?? value;
}
