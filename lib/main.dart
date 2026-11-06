import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/profile_form_page.dart';
import 'pages/profile_page.dart';
import 'models/user_profile.dart';
import 'pages/scan_page.dart';
import 'pages/search_page.dart';
import 'services/api_client.dart';
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
  bool _loggedIn = SessionStore.hasToken;
  bool _needsProfile = SessionStore.needsProfile;

  @override
  void initState() {
    super.initState();
    ApiClient.onUnauthorized = _onLogout;
  }

  @override
  void dispose() {
    ApiClient.onUnauthorized = null;
    super.dispose();
  }

  void _onLoginSuccess(bool needsProfile) {
    SessionStore.setNeedsProfile(needsProfile);
    setState(() {
      _loggedIn = true;
      _needsProfile = needsProfile;
    });
  }

  Future<void> _onProfileSaved(UserProfile profile) async {
    await SessionStore.setNeedsProfile(false);
    if (mounted) setState(() => _needsProfile = false);
  }

  Future<void> _onLogout() async {
    await SessionStore.clear();
    if (mounted) {
      setState(() {
        _loggedIn = false;
        _needsProfile = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智能饮食搭配推荐系统',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: !_loggedIn
          ? LoginPage(onSuccess: _onLoginSuccess)
          : _needsProfile
              ? ProfileFormPage(
                  onSaved: _onProfileSaved,
                  onLogout: _onLogout,
                )
              : MainShell(onLogout: _onLogout),
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
      ProfilePage(
        onLogout: widget.onLogout,
        onProfileUpdated: () {
          _homeKey.currentState?.refresh();
        },
      ),
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
