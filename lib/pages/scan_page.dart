import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../models/food.dart';
import '../theme.dart';

/// Tab 2 · 拍照识别页（D1 为模拟识别，后续接入百度菜品识别 API）
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _busy = false;
  Food? _result;
  double _grams = 150;

  Future<void> _fakeScan() async {
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = DemoData.foods.firstWhere((f) => f.name == '番茄炒蛋');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('拍照识别')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          // 取景框
          GestureDetector(
            onTap: _busy ? null : _fakeScan,
            child: Container(
              height: 240,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryLight, width: 2),
              ),
              child: Center(
                child: _busy
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(color: AppColors.primary),
                          SizedBox(height: 16),
                          Text('正在识别菜品…', style: TextStyle(color: AppColors.textLight)),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                            child: const Icon(Icons.photo_camera, size: 40, color: AppColors.primary),
                          ),
                          const SizedBox(height: 14),
                          const Text('点击拍照识别菜品', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          const Text('支持食堂 / 外卖菜品，自动估算热量',
                              style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                        ],
                      ),
              ),
            ),
          ),

          if (_result != null) ...[
            const SizedBox(height: 20),
            const SectionTitle('识别结果', trailing: '置信度 93%'),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_result!.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('如识别不准，可手动选择其他菜品', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                  const SizedBox(height: 16),

                  // 重量滑杆
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('预估重量', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${_grams.toInt()} g',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                    ],
                  ),
                  Slider(
                    value: _grams,
                    min: 50,
                    max: 400,
                    divisions: 35,
                    activeColor: AppColors.primary,
                    label: '${_grams.toInt()} g',
                    onChanged: (v) => setState(() => _grams = v),
                  ),
                  const Text('滑动调整重量，营养值会同步变化',
                      style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _nutrient('热量', (_result!.calories * _grams / 100).toStringAsFixed(0), 'kcal', AppColors.accent),
                      _nutrient('蛋白质', (_result!.protein * _grams / 100).toStringAsFixed(1), 'g', AppColors.protein),
                      _nutrient('碳水', (_result!.carbs * _grams / 100).toStringAsFixed(1), 'g', AppColors.carbs),
                      _nutrient('脂肪', (_result!.fat * _grams / 100).toStringAsFixed(1), 'g', AppColors.fat),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已记录：${_result!.name} ${_grams.toInt()}g'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('加入今日饮食记录', style: TextStyle(fontSize: 15)),
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
                Text('· 光线充足、菜品居中，识别更准确', style: TextStyle(fontSize: 12, height: 1.8)),
                Text('· 中餐油脂较多，营养值为区间估计', style: TextStyle(fontSize: 12, height: 1.8)),
                Text('· 重量可手动修正，识别后务必核对', style: TextStyle(fontSize: 12, height: 1.8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nutrient(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(unit, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
      ],
    );
  }
}
