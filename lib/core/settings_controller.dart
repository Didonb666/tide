import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/app_theme.dart';

class SettingsController extends ChangeNotifier {
  static const String _kTheme = 'settings.themeMode';
  static const String _kAccent = 'settings.accent';
  static const String _kAutoConnect = 'settings.autoConnect';
  static const String _kVerbose = 'settings.verboseLogs';

  ThemeMode _themeMode = ThemeMode.system;
  TideAccent _accent = TideAccent.green;
  bool _autoConnect = false;
  bool _verboseLogs = false;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  TideAccent get accent => _accent;
  bool get autoConnect => _autoConnect;
  bool get verboseLogs => _verboseLogs;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int themeIndex = (prefs.getInt(_kTheme) ?? 0).clamp(0, ThemeMode.values.length - 1);
      final int accentIndex = (prefs.getInt(_kAccent) ?? 0).clamp(0, TideAccent.values.length - 1);
      _themeMode = ThemeMode.values[themeIndex];
      _accent = TideAccent.values[accentIndex];
      _autoConnect = prefs.getBool(_kAutoConnect) ?? false;
      _verboseLogs = prefs.getBool(_kVerbose) ?? false;
      notifyListeners();
    } catch (_) {
      // 首次启动或平台不支持时保持默认值。
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    _persistInt(_kTheme, mode.index);
  }

  void setAccent(TideAccent accent) {
    if (accent == _accent) return;
    _accent = accent;
    notifyListeners();
    _persistInt(_kAccent, accent.index);
  }

  void setAutoConnect(bool value) {
    if (value == _autoConnect) return;
    _autoConnect = value;
    notifyListeners();
    _persistBool(_kAutoConnect, value);
  }

  void setVerboseLogs(bool value) {
    if (value == _verboseLogs) return;
    _verboseLogs = value;
    notifyListeners();
    _persistBool(_kVerbose, value);
  }

  Future<void> _persistInt(String key, int value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (_) {}
  }

  Future<void> _persistBool(String key, bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }
}

class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SettingsController of(BuildContext context) {
    final SettingsScope? scope =
        context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, '找不到 SettingsScope');
    return scope!.notifier!;
  }
}
