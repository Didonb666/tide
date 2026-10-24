import 'package:flutter/material.dart';

import 'core/app_controller.dart';
import 'core/app_scope.dart';
import 'core/background_controller.dart';
import 'core/settings_controller.dart';
import 'design/app_theme.dart';
import 'design/tokens.dart';
import 'features/connect/connect_page.dart';
import 'features/logs/logs_page.dart';
import 'features/profiles/profiles_page.dart';
import 'features/settings/settings_page.dart';
import 'widgets/aurora_background.dart';
import 'widgets/common.dart';

class TideApp extends StatelessWidget {
  const TideApp({
    super.key,
    required this.controller,
    required this.settings,
    required this.background,
  });

  final AppController controller;
  final SettingsController settings;
  final BackgroundController background;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: SettingsScope(
        controller: settings,
        child: BackgroundScope(
          controller: background,
          child: AnimatedBuilder(
            animation: settings,
            builder: (BuildContext context, Widget? child) {
              return MaterialApp(
                title: 'Fstool',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(settings.accent),
                darkTheme: AppTheme.dark(settings.accent),
                themeMode: settings.themeMode,
                builder: (BuildContext context, Widget? child) {
                  return Stack(
                    children: <Widget>[
                      const AppBackgroundHost(),
                      if (child != null) child,
                    ],
                  );
                },
                home: const HomeShell(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const List<Widget> _pages = <Widget>[
    ConnectPage(),
    ProfilesPage(),
    LogsPage(),
    SettingsPage(),
  ];

  static const List<GlassNavItem> _navItems = <GlassNavItem>[
    GlassNavItem(
      icon: Icons.power_settings_new_outlined,
      activeIcon: Icons.power_settings_new_rounded,
      label: '连接',
    ),
    GlassNavItem(
      icon: Icons.layers_outlined,
      activeIcon: Icons.layers_rounded,
      label: '配置',
    ),
    GlassNavItem(
      icon: Icons.article_outlined,
      activeIcon: Icons.article_rounded,
      label: '日志',
    ),
    GlassNavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: '设置',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final Duration duration = context.motion(TideMotion.base);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: AnimatedSwitcher(
        duration: duration,
        switchInCurve: TideMotion.standard,
        switchOutCurve: TideMotion.standard,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_index),
          child: _pages[_index],
        ),
      ),
      bottomNavigationBar: GlassNavBar(
        index: _index,
        onTap: (int value) => setState(() => _index = value),
        items: _navItems,
      ),
    );
  }
}
