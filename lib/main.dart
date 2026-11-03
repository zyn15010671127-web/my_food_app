import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/profile_page.dart';
import 'pages/scan_page.dart';
import 'pages/search_page.dart';
import 'services/session.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionStore.init(); // 读取本地保存的登录状态
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 有 token 就直接进主界面，否则先进登录页
  bool _loggedIn = SessionStore.hasToken;

  void _onLoginSuccess() => setState(() => _loggedIn = true);

  Future<void> _onLogout() async {
    await SessionStore.clear();
    if (mounted) setState(() => _loggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智能饮食搭配推荐系统',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: _loggedIn
          ? MainShell(onLogout: _onLogout)
          : LoginPage(onSuccess: _onLoginSuccess),
    );
  }
}

/// 主框架：四个 Tab 的底部导航
class MainShell extends StatefulWidget {
  final Future<void> Function() onLogout;
  const MainShell({super.key, required this.onLogout});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final GlobalKey<HomePageState> _homeKey = GlobalKey<HomePageState>();
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // IndexedStack 保留各 Tab 的滚动位置和状态，切换不丢失
    _pages = [
      HomePage(key: _homeKey),
      const ScanPage(),
      const SearchPage(),
      ProfilePage(onLogout: widget.onLogout),
    ];
  }

  void _onTabSelected(int index) {
    setState(() => _index = index);
    if (index == 0) {
      _homeKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_camera_outlined),
            selectedIcon: Icon(Icons.photo_camera, color: AppColors.primary),
            label: '识别',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search, color: AppColors.primary),
            label: '食物库',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
