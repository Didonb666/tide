import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/app_theme.dart';
import 'display_mode_service.dart';

class SettingsController extends ChangeNotifier {
  static const String _kTheme = 'settings.themeMode';
  static const String _kAccent = 'settings.accentColor';
  static const String _kPreset = 'settings.accentPreset';
  static const String _kFps = 'settings.refreshRate';
  static const String _kAutoConnect = 'settings.autoConnect';
  static const String _kVerbose = 'settings.verboseLogs';

  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = TideAccent.green.seed;
  TideAccent _preset = TideAccent.green;
  int _refreshRate = 60;
  bool _autoConnect = false;
  bool _verboseLogs = false;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  TideAccent get accent => _preset;
  int get refreshRate => _refreshRate;
  bool get autoConnect => _autoConnect;
  bool get verboseLogs => _verboseLogs;

  String get accentHex =>
      '#${_accentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      _themeMode = ThemeMode.values[
          (prefs.getInt(_kTheme) ?? 0).clamp(0, ThemeMode.values.length - 1)];
      _preset = TideAccent.values[
          (prefs.getInt(_kPreset) ?? 0).clamp(0, TideAccent.values.length - 1)];
      _accentColor = Color(prefs.getInt(_kAccent) ?? _preset.seed.toARGB32());
      _refreshRate = prefs.getInt(_kFps) ?? 60;
      _autoConnect = prefs.getBool(_kAutoConnect) ?? false;
      _verboseLogs = prefs.getBool(_kVerbose) ?? false;

      notifyListeners();
      await DisplayModeService.applyRefreshRate(_refreshRate);
    } catch (_) {}
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    _persistInt(_kTheme, mode.index);
  }

  void setAccent(TideAccent accent) {
    _preset = accent;
    _accentColor = accent.seed;
    notifyListeners();
    _persistInt(_kPreset, accent.index);
    _persistInt(_kAccent, accent.seed.toARGB32());
  }

  void setAccentColor(Color color, {TideAccent? preset}) {
    _accentColor = color;
    if (preset != null) _preset = preset;
    notifyListeners();
    _persistInt(_kAccent, color.toARGB32());
    if (preset != null) _persistInt(_kPreset, preset.index);
  }

  void setRefreshRate(int hz) {
    if (hz == _refreshRate) return;
    _refreshRate = hz;
    notifyListeners();
    _persistInt(_kFps, hz);
    DisplayModeService.applyRefreshRate(hz);
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
