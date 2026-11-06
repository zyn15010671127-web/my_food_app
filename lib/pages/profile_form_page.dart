import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/profile_service.dart';
import '../theme.dart';

/// 注册后的首次档案设置，也用于“我的”页面编辑档案。
class ProfileFormPage extends StatefulWidget {
  final UserProfile? initialProfile;
  final Future<void> Function(UserProfile)? onSaved;
  final Future<void> Function()? onLogout;

  const ProfileFormPage({
    super.key,
    this.initialProfile,
    this.onSaved,
    this.onLogout,
  });

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();

  String _sex = 'female';
  String _goal = 'maintain';
  String _activityLevel = 'moderate';
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.initialProfile != null;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    if (profile != null) {
      _ageController.text = profile.age.toString();
      _heightController.text = _plainNumber(profile.heightCm);
      _weightController.text = _plainNumber(profile.weightKg);
      if (profile.bodyFatPercent != null) {
        _bodyFatController.text = _plainNumber(profile.bodyFatPercent!);
      }
      _sex = profile.sex;
      _goal = profile.goal;
      _activityLevel = profile.activityLevel;
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bodyFatController.dispose();
    super.dispose();
  }

  String _plainNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请检查标红的档案字段后再保存')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final height = double.parse(_heightController.text.trim());
    final weight = double.parse(_weightController.text.trim());
    final bodyFatText = _bodyFatController.text.trim();
    final draft = UserProfile(
      sex: _sex,
      age: int.parse(_ageController.text.trim()),
      heightCm: height,
      weightKg: weight,
      goal: _goal,
      activityLevel: _activityLevel,
      bodyFatPercent:
          bodyFatText.isEmpty ? null : double.parse(bodyFatText),
      bmi: weight / ((height / 100) * (height / 100)),
      updatedAt: widget.initialProfile?.updatedAt ?? '',
    );

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // 后端保存档案时会同步重算今日目标，不再依赖第二次请求。
      final saved = await ProfileService.saveProfile(draft);
      if (!mounted) return;
      if (widget.onSaved != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('档案保存成功，今日营养目标已生成')),
        );
        // 必须等本地状态保存并进入主框架后再结束，避免按钮一直停在保存中。
        await widget.onSaved!(saved);
      } else {
        // 编辑模式把“后端已保存的档案 + 已重算的目标”一起带回上一页。
        final target = await ProfileService.getTarget();
        if (!mounted) return;
        Navigator.pop(
          context,
          ProfileOverview(profile: saved, target: target),
        );
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : '保存失败，请检查后端连接后重试。';
      setState(() {
        _saving = false;
        _error = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  String? _numberValidator(
    String? value,
    String label,
    double min,
    double max, {
    bool optional = false,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return optional ? null : '请填写$label';
    final number = double.tryParse(text);
    if (number == null) return '$label请输入数字';
    if (number < min || number > max) {
      return '$label应在 ${min.toStringAsFixed(0)}–${max.toStringAsFixed(0)} 之间';
    }
    return null;
  }

  String? _bodyFatValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = double.tryParse(text);
    if (number == null) return '体脂率请输入数字';
    if (number <= 0 || number >= 100) return '体脂率应大于 0 且小于 100';
    return null;
  }

  String? _ageValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '请填写年龄';
    final age = int.tryParse(text);
    if (age == null) return '年龄请输入整数';
    if (age < 18 || age > 120) return '年龄应在 18–120 岁之间';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑个人档案' : '完善个人档案'),
        actions: [
          if (widget.onLogout != null)
            TextButton(
              onPressed: _saving ? null : widget.onLogout,
              child: const Text('退出登录'),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_ind_outlined,
                          size: 34, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isEditing
                              ? '修改后会重新计算今日营养目标，历史目标快照保持不变。'
                              : '请先完成身体档案，系统才能计算适合你的热量和三大营养素目标。',
                          style: const TextStyle(fontSize: 12, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle('性别'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: [
                    _choice('男', _sex == 'male', () => _sex = 'male'),
                    _choice('女', _sex == 'female', () => _sex = 'female'),
                  ],
                ),
                const SizedBox(height: 18),
                _numberField(
                  controller: _ageController,
                  label: '年龄',
                  hint: '例如 21',
                  unit: '岁',
                  validator: _ageValidator,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _numberField(
                        controller: _heightController,
                        label: '身高',
                        hint: '例如 165',
                        unit: 'cm',
                        validator: (value) =>
                            _numberValidator(value, '身高', 50, 260),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberField(
                        controller: _weightController,
                        label: '体重',
                        hint: '例如 55',
                        unit: 'kg',
                        validator: (value) =>
                            _numberValidator(value, '体重', 10, 500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _numberField(
                  controller: _bodyFatController,
                  label: '体脂率（选填）',
                  hint: '没有数据可留空',
                  unit: '%',
                  validator: _bodyFatValidator,
                ),
                const SizedBox(height: 8),
                const Text(
                  '估算引导：可填写体脂秤读数，或结合腰围公式与参照图估算。'
                  '不知道时直接留空，当前使用基础营养模型，不影响记录和推荐。',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle('健身目标'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _choice('减脂', _goal == 'lose_fat',
                        () => _goal = 'lose_fat'),
                    _choice('增肌', _goal == 'gain_muscle',
                        () => _goal = 'gain_muscle'),
                    _choice('塑形', _goal == 'shape', () => _goal = 'shape'),
                    _choice('维持', _goal == 'maintain',
                        () => _goal = 'maintain'),
                  ],
                ),
                const SizedBox(height: 20),
                const SectionTitle('活动强度'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _activityLevel,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '日常与训练活动量',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    'sedentary',
                    'light',
                    'moderate',
                    'high',
                    'very_high',
                  ]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(profileActivityLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _activityLevel = value ?? 'moderate'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFC62828)),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _saving
                          ? '正在保存并重算目标…'
                          : _isEditing
                              ? '保存并重新计算目标'
                              : '保存档案并进入系统',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    '营养目标为一般成人估算，仅供参考，不构成医疗建议',
                    style: TextStyle(fontSize: 10, color: AppColors.textLight),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textDark),
      showCheckmark: false,
      onSelected: _saving ? null : (_) => setState(onSelected),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String unit,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: unit,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
      enabled: !_saving,
    );
  }
}
