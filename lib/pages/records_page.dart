import 'package:flutter/material.dart';

import '../models/meal_record.dart';
import '../services/api_client.dart';
import '../services/meal_service.dart';
import '../theme.dart';

typedef MealRecordsLoader = Future<List<MealRecord>> Function(String recordDate);

/// 按日期查看自己的饮食记录，支持删除。
class RecordsPage extends StatefulWidget {
  final MealRecordsLoader? recordsLoader;

  const RecordsPage({super.key, this.recordsLoader});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  DateTime _day = DateTime.now();
  late Future<List<MealRecord>> _recordsFuture;
  final Set<int> _deleting = <int>{};

  @override
  void initState() {
    super.initState();
    _recordsFuture = _loadRecords();
  }

  Future<List<MealRecord>> _loadRecords() {
    final loader = widget.recordsLoader;
    return loader?.call(_dateString()) ?? MealService.listRecords(_dateString());
  }

  void _reload() {
    setState(() {
      _recordsFuture = _loadRecords();
    });
  }

  Future<void> _refresh() async {
    final next = _loadRecords();
    setState(() => _recordsFuture = next);
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day = picked;
      _recordsFuture = _loadRecords();
    });
  }

  String _dateString() {
    return '${_day.year}-'
        '${_day.month.toString().padLeft(2, '0')}-'
        '${_day.day.toString().padLeft(2, '0')}';
  }

  String _mealLabel(String type) {
    const labels = {
      'breakfast': '早餐',
      'lunch': '午餐',
      'dinner': '晚餐',
      'snack': '加餐',
    };
    return labels[type] ?? type;
  }

  Future<void> _confirmDelete(MealRecord record) async {
    if (_deleting.contains(record.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除饮食记录'),
        content: Text('确定删除「${record.foodName} ${record.grams.round()}g」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFC62828))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting.add(record.id));
    try {
      await MealService.deleteRecord(record.id);
      if (!mounted) return;
      _deleting.remove(record.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('记录已删除，首页数据会在返回后更新')),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting.remove(record.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiException ? error.message : '删除失败，请稍后重试'),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('饮食记录'),
        actions: [
          IconButton(
            onPressed: _pickDate,
            tooltip: '选择日期',
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<MealRecord>>(
          future: _recordsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (!snapshot.hasData) {
              return _errorView(snapshot.error);
            }
            return _recordsView(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _errorView(Object? error) {
    final message = error is ApiException
        ? error.message
        : '无法读取饮食记录，请检查后端后重试。';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        AppCard(
          child: Column(
            children: [
              const Icon(Icons.cloud_off, size: 40, color: AppColors.accent),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _reload, child: const Text('重新加载')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _recordsView(List<MealRecord> records) {
    final totalCalories = records.fold<double>(
      0,
      (sum, record) => sum + record.calories,
    );
    final children = <Widget>[
      AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_day.month}月${_day.day}日',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${records.length} 条记录 · 点击右上角可切换日期',
                    style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${totalCalories.round()}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
                const Text(
                  '总摄入 kcal',
                  style: TextStyle(fontSize: 10, color: AppColors.textLight),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
    ];

    if (records.isEmpty) {
      children.add(
        const AppCard(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                '这一天还没有饮食记录\n可去食物库或拍照识别页打卡',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight, height: 1.6),
              ),
            ),
          ),
        ),
      );
    } else {
      const mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];
      for (final mealType in mealOrder) {
        final group = records.where((record) => record.mealType == mealType).toList();
        if (group.isEmpty) continue;
        children.add(SectionTitle(_mealLabel(mealType), trailing: '${group.length} 条'));
        children.add(const SizedBox(height: 10));
        for (final record in group) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _recordCard(record),
            ),
          );
        }
        children.add(const SizedBox(height: 10));
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: children,
    );
  }

  Widget _recordCard(MealRecord record) {
    final deleting = _deleting.contains(record.id);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.foodName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              if (deleting)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  onPressed: () => _confirmDelete(record),
                  tooltip: '删除',
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${record.grams.round()}g · '
                  '蛋白质 ${record.protein.toStringAsFixed(1)}g · '
                  '碳水 ${record.carbs.toStringAsFixed(1)}g · '
                  '脂肪 ${record.fat.toStringAsFixed(1)}g',
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${record.calories.round()} kcal',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
