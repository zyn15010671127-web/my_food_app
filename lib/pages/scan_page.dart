import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/recognition.dart';
import '../services/api_client.dart';
import '../services/recognition_service.dart';
import '../theme.dart';

/// Tab 2 · 图片上传、后端识别、用户核对并保存饮食记录。
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _DishDraft {
  final String recognizedName;
  final double confidence;
  int? foodId;
  double grams;

  _DishDraft({
    this.recognizedName = '',
    this.confidence = 0,
    this.foodId,
    this.grams = 150,
  });
}

class _ScanPageState extends State<ScanPage> {
  static const int _maxImageBytes = 8 * 1024 * 1024;

  final ImagePicker _picker = ImagePicker();
  Uint8List? _imageBytes;
  String _imageName = '';
  bool _allowExternal = false;
  bool _busy = false;
  bool _saving = false;
  bool _confirmed = false;
  String? _error;
  String _mealType = 'lunch';
  RecognitionResult? _result;
  List<FoodOption> _foods = [];
  List<_DishDraft> _drafts = [];
  int _savedCount = 0;

  Future<void> _pickAndRecognize(ImageSource source) async {
    if (_busy || _saving) return;
    FocusScope.of(context).unfocus();
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _error = '图片内容为空，请重新选择。');
        return;
      }
      if (bytes.lengthInBytes > _maxImageBytes) {
        setState(() => _error = '图片不能超过 8 MB，请压缩后重试。');
        return;
      }
      final name = file.name.isEmpty ? 'upload.jpg' : file.name;
      await _analyze(bytes, name);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _errorMessage(error));
    }
  }

  Future<void> _analyze(Uint8List bytes, String filename) async {
    setState(() {
      _imageBytes = bytes;
      _imageName = filename;
      _busy = true;
      _saving = false;
      _confirmed = false;
      _savedCount = 0;
      _error = null;
      _result = null;
      _foods = [];
      _drafts = [];
    });

    try {
      final result = await RecognitionService.recognize(
        imageBytes: bytes,
        filename: filename,
        allowExternalProcessing: _allowExternal,
      );
      final foods = await RecognitionService.loadFoods();
      if (!mounted) return;

      final validFoodIds = foods.map((food) => food.id).toSet();
      final drafts = result.dishes.isEmpty
          ? <_DishDraft>[_DishDraft()]
          : result.dishes.map((dish) {
              final matchedId = dish.foodId;
              return _DishDraft(
                recognizedName: dish.name,
                confidence: dish.confidence,
                foodId: validFoodIds.contains(matchedId) ? matchedId : null,
              );
            }).toList();

      setState(() {
        _busy = false;
        _result = result;
        _foods = foods;
        _drafts = drafts;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _errorMessage(error);
      });
    }
  }

  Future<void> _retry() async {
    final bytes = _imageBytes;
    if (bytes == null || _busy || _saving) return;
    await _analyze(bytes, _imageName);
  }

  Future<void> _saveRecords() async {
    final result = _result;
    if (result == null || _saving || _confirmed) return;
    if (_drafts.isEmpty || _drafts.any((draft) => draft.foodId == null)) {
      setState(() => _error = '请为每道菜选择对应的食物库条目后再保存。');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final count = await RecognitionService.confirm(
        recognitionId: result.id,
        mealType: _mealType,
        recordDate: _today(),
        items: _drafts
            .map((draft) => <String, dynamic>{
                  'food_id': draft.foodId,
                  'grams': draft.grams,
                })
            .toList(),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _confirmed = true;
        _savedCount = count;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已写入今日饮食记录，切回首页即可查看更新'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _errorMessage(error);
      });
    }
  }

  String _today() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  String _errorMessage(Object error) {
    if (error is ApiException) return error.message;
    return '图片操作失败，请检查所选图片、后端状态和浏览器权限后重试。';
  }

  FoodOption? _foodById(int? id) {
    if (id == null) return null;
    for (final food in _foods) {
      if (food.id == id) return food;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('拍照识别')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _imageFrame(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || _saving
                      ? null
                      : () => _pickAndRecognize(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('拍照'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || _saving
                      ? null
                      : () => _pickAndRecognize(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('从相册选择'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              value: _allowExternal,
              onChanged: _busy || _saving
                  ? null
                  : (value) => setState(() => _allowExternal = value),
              title: const Text(
                '允许使用外部视觉服务',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                '需后端已配置；未启用时会降级为手动核对',
                style: TextStyle(fontSize: 11),
              ),
              activeColor: AppColors.primary,
              dense: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _errorCard(),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            SectionTitle(
              _result!.dishes.isEmpty ? '请手动核对' : '核对识别结果',
              trailing: _result!.mode == 'baidu_dish'
                  ? '百度菜品识别'
                  : _result!.mode == 'external_vision'
                      ? '外部视觉服务'
                      : '手动核对模式',
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Text(
                _result!.message,
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
            ),
            const SizedBox(height: 12),
            ..._drafts.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _draftCard(entry.key, entry.value),
                  ),
                ),
            if (!_confirmed && _drafts.length < 30)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _drafts.add(_DishDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('添加一道菜'),
                ),
              ),
            const SizedBox(height: 4),
            _mealTypeCard(),
            const SizedBox(height: 16),
            if (_confirmed)
              AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '已保存 $_savedCount 条饮食记录，返回首页即可看到更新。',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveRecords,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline),
                  label: Text(_saving ? '正在保存…' : '确认并加入今日饮食记录'),
                ),
              ),
          ],
          const SizedBox(height: 24),
          const SectionTitle('识别小贴士'),
          const SizedBox(height: 10),
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '· 光线充足、菜品居中，有助于提高识别准确率',
                  style: TextStyle(fontSize: 12, height: 1.8),
                ),
                Text(
                  '· 识别只给出菜名，实际克数必须由你核对',
                  style: TextStyle(fontSize: 12, height: 1.8),
                ),
                Text(
                  '· 营养值按食物库每 100 克数据换算',
                  style: TextStyle(fontSize: 12, height: 1.8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageFrame() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _imageBytes == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(
                        Icons.photo_camera,
                        size: 36,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      '拍摄或选择菜品照片',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '支持 JPEG、PNG、WEBP，最大 8 MB',
                      style: TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_imageBytes!, fit: BoxFit.cover),
                  if (_busy)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              '正在上传并识别，请稍候…',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC62828)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFC62828), height: 1.4),
            ),
          ),
          if (_imageBytes != null && !_busy)
            TextButton(
              onPressed: _saving
                  ? null
                  : (_result == null ? _retry : _saveRecords),
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }

  Widget _draftCard(int index, _DishDraft draft) {
    final food = _foodById(draft.foodId);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  draft.recognizedName.isEmpty
                      ? '第 ${index + 1} 道菜'
                      : '识别：${draft.recognizedName}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              if (draft.confidence > 0)
                Text(
                  '${(draft.confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              if (_drafts.length > 1 && !_confirmed)
                IconButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _drafts.removeAt(index)),
                  tooltip: '移除',
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: draft.foodId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '选择食物库条目',
              border: OutlineInputBorder(),
            ),
            items: _foods
                .map(
                  (item) => DropdownMenuItem<int>(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _confirmed || _saving
                ? null
                : (value) => setState(() => draft.foodId = value),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('实际重量', style: TextStyle(fontSize: 13)),
              Text(
                '${draft.grams.round()} g',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          Slider(
            value: draft.grams,
            min: 50,
            max: 500,
            divisions: 45,
            label: '${draft.grams.round()} g',
            activeColor: AppColors.primary,
            onChanged: _confirmed || _saving
                ? null
                : (value) => setState(() => draft.grams = value),
          ),
          if (food != null) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                _nutrient(
                  '热量',
                  (food.calories * draft.grams / 100).toStringAsFixed(0),
                  'kcal',
                  AppColors.accent,
                ),
                _nutrient(
                  '蛋白质',
                  (food.protein * draft.grams / 100).toStringAsFixed(1),
                  'g',
                  AppColors.protein,
                ),
                _nutrient(
                  '碳水',
                  (food.carbs * draft.grams / 100).toStringAsFixed(1),
                  'g',
                  AppColors.carbs,
                ),
                _nutrient(
                  '脂肪',
                  (food.fat * draft.grams / 100).toStringAsFixed(1),
                  'g',
                  AppColors.fat,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _mealTypeCard() {
    return AppCard(
      child: DropdownButtonFormField<String>(
        value: _mealType,
        decoration: const InputDecoration(
          labelText: '计入餐次',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'breakfast', child: Text('早餐')),
          DropdownMenuItem(value: 'lunch', child: Text('午餐')),
          DropdownMenuItem(value: 'dinner', child: Text('晚餐')),
          DropdownMenuItem(value: 'snack', child: Text('加餐')),
        ],
        onChanged: _confirmed || _saving
            ? null
            : (value) => setState(() => _mealType = value ?? 'lunch'),
      ),
    );
  }

  Widget _nutrient(String label, String value, String unit, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
        ),
        Text(unit, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
      ],
    );
  }
}
