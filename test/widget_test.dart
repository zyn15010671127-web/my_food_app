import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_food_app/main.dart';

void main() {
  testWidgets('主界面与四个 Tab 正常渲染', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // 首页默认展示
    expect(find.text('今日饮食'), findsOneWidget);
    expect(find.text('三大营养素'), findsOneWidget);

    // 底部导航存在
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);

    // 切换到食物库
    await tester.tap(find.text('食物库').last);
    await tester.pumpAndSettle();
    expect(find.text('米饭（熟）'), findsWidgets);
  });
}
