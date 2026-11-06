import 'dart:async';

import 'package:flutter/material.dart';

import '../models/recognition.dart';
import '../services/api_client.dart';
import '../services/food_service.dart';
import '../services/meal_service.dart';
import '../theme.dart';

typedef FoodSearchLoader = Future<List<FoodOption>> Function({
  required String query,
  required int offset,
  required int limit,
});

/// Tab 3 · 后端食物库搜索与食物打卡。
class SearchPage extends StatefulWidget {
  final FoodSearchLoader? foodLoader;

  const SearchPage({super.key, this.foodLoader});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const int _pageSize = 20;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<FoodOption> _foods = [];
  String _query = '';
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _load(reset: true),
    );
  }

  Future<void> _load({bool reset = false}) async {
    final generation = ++_requestGeneration;
    final offset = reset ? 0 : _foods.length;
    setState(() {
      _error = null;
      if (reset) {
        _foods = [];
        _hasMore = false;
        _loading = true;
        _loadingMore = false;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final loader = widget.foodLoader;
      final result = await (loader?.call(
            query: _query.trim(),
            offset: offset,
            limit: _pageSize,
          ) ??
          FoodService.search(
            query: _query.trim(),
            offset: offset,
            limit: _pageSize,
          ));
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _foods = reset ? result : [..._foods, ...result];
        _hasMore = result.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _error = _errorMessage(error);
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  String _errorMessage(Object error) {
    if (error is ApiException) return error.message;
    return '无法连接后端，请确认 backend/run.ps1 已启动后重试。';
  }

  Future<void> _openFood(FoodOption food) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FoodRecordSheet(food: food),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已记录：${food.name}，切回首页可查看更新'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('食物库')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '搜索食物名称，如「鸡胸肉」',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onQueryChanged('');
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onQueryChanged,
              onSubmitted: (_) {
                _debounce?.cancel();
                _load(reset: true);
              },
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '营养值按每 100 克可食部分 · 点击食物可打卡',
                style: const TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _foods.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _foods.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 40, color: AppColors.accent),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _load(reset: true),
                child: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }
    if (_foods.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Center(
              child: Text(
                '没有找到相关食物，请换个关键词',
                style: TextStyle(color: AppColors.textLight),
              ),
            ),
          ],
        ),
      );
    }

    final extraRow = _hasMore || _error != null ? 1 : 0;
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _foods.length + extraRow,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= _foods.length) {
            if (_error != null) {
              return AppCard(
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () => _load(reset: _foods.isEmpty),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            }
            return Center(
              child: TextButton.icon(
                onPressed: _loadingMore ? null : () => _load(),
                icon: _loadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(_loadingMore ? '正在加载…' : '加载更多'),
              ),
            );
          }

          final food = _foods[index];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openFood(food),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '蛋白质 ${food.protein.toStringAsFixed(1)}g · '
                          '碳水 ${food.carbs.toStringAsFixed(1)}g · '
                          '脂肪 ${food.fat.toStringAsFixed(1)}g',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${food.calories.round()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                        ),
                      ),
                      const Text(
                        'kcal/100g',
                        style: TextStyle(fontSize: 10, color: AppColors.textLight),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 食物详情与打卡底部弹窗。
class FoodRecordSheet extends StatefulWidget {
  final FoodOption food;

  const FoodRecordSheet({super.key, required this.food});

  @override
  State<FoodRecordSheet> createState() => _FoodRecordSheetState();
}

class _FoodRecordSheetState extends State<FoodRecordSheet> {
  double _grams = 150;
  String _mealType = 'lunch';
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MealService.addRecord(
        foodId: widget.food.id,
        grams: _grams,
        mealType: _mealType,
        recordDate: _today(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is ApiException ? error.message : '保存失败，请检查后端后重试。';
      });
    }
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    food.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              '每 100 克可食部分的营养值',
              style: TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
            const SizedBox(height: 16),
            _NutritionValues(
              calories: food.calories,
              protein: food.protein,
              carbs: food.carbs,
              fat: food.fat,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
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
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _mealType = value ?? 'lunch'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('食用重量', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${_grams.round()} g',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            Slider(
              value: _grams,
              min: 50,
              max: 500,
              divisions: 45,
              activeColor: AppColors.primary,
              label: '${_grams.round()} g',
              onChanged: _saving ? null : (value) => setState(() => _grams = value),
            ),
            const SizedBox(height: 4),
            const Text(
              '本次摄入',
              style: TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
            const SizedBox(height: 10),
            _NutritionValues(
              calories: food.calories * _grams / 100,
              protein: food.protein * _grams / 100,
              carbs: food.carbs * _grams / 100,
              fat: food.fat * _grams / 100,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFC62828))),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: Text(_saving ? '正在保存…' : '确认加入今日饮食记录'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionValues extends StatelessWidget {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const _NutritionValues({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 12,
      children: [
        _item('热量', calories.toStringAsFixed(0), 'kcal', AppColors.accent),
        _item('蛋白质', protein.toStringAsFixed(1), 'g', AppColors.protein),
        _item('碳水', carbs.toStringAsFixed(1), 'g', AppColors.carbs),
        _item('脂肪', fat.toStringAsFixed(1), 'g', AppColors.fat),
      ],
    );
  }

  Widget _item(String label, String value, String unit, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
        ),
        Text(unit, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
      ],
    );
  }
}
