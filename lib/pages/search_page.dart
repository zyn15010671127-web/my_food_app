import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../models/food.dart';
import '../theme.dart';

/// Tab 3 · 食物库搜索
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _keyword = '';
  String _category = '全部';

  static const _categories = ['全部', '主食', '荤菜', '素菜', '汤'];

  List<Food> get _filtered {
    return DemoData.foods.where((f) {
      final matchKey = _keyword.isEmpty || f.name.contains(_keyword);
      final matchCat = _category == '全部' || f.category == _category;
      return matchKey && matchCat;
    }).toList();
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
              decoration: InputDecoration(
                hintText: '搜索菜品名称，如「鸡胸肉」',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _keyword = v.trim()),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = _categories[i];
                final selected = c == _category;
                return ChoiceChip(
                  label: Text(c, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textDark)),
                  selected: selected,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  side: BorderSide.none,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _category = c),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('没有找到相关菜品', style: TextStyle(color: AppColors.textLight)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final f = _filtered[i];
                      return GestureDetector(
                        onTap: () => _showDetail(f),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(f.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text('蛋白质 ${f.protein}g · 碳水 ${f.carbs}g · 脂肪 ${f.fat}g',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${f.calories}',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.accent)),
                                  const Text('kcal/100g', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showDetail(Food f) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${f.category} · 每 100 克可食部分', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
            const SizedBox(height: 20),
            _row('热量', '${f.calories} kcal'),
            _row('蛋白质', '${f.protein} g'),
            _row('碳水', '${f.carbs} g'),
            _row('脂肪', '${f.fat} g'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已记录：${f.name} 100g'), backgroundColor: AppColors.primary),
                  );
                },
                child: const Text('记录 100g'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontSize: 14, color: AppColors.textLight)),
          Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
