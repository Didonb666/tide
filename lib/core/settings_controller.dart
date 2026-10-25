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
  static const String _kGlassBlur = 'settings.glassBlur';
  static const String _kGlassHighlight = 'settings.glassHighlight';
  static const String _kNavBottom = 'settings.navBottom';
  static const String _kNavInset = 'settings.navInset';
  static const String _kSnowImage = 'settings.snowImage';
  static const String _kSnowCount = 'settings.snowCount';
  static const String _kSnowSize = 'settings.snowSize';
  static const String _kSnowSpeed = 'settings.snowSpeed';

  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = TideAccent.green.seed;
  TideAccent _preset = TideAccent.green;
  int _refreshRate = 60;
  bool _autoConnect = false;
  bool _verboseLogs = false;

  double _glassBlur = 18;
  double _glassHighlight = 1.0;
  double _navBottom = 16;
  double _navInset = 20;
  String? _snowImage;
  int _snowCount = 26;
  double _snowSize = 10;
  double _snowSpeed = 1.0;

  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;
  TideAccent get accent => _preset;
  int get refreshRate => _refreshRate;
  bool get autoConnect => _autoConnect;
  bool get verboseLogs => _verboseLogs;

  double get glassBlur => _glassBlur;
  double get glassHighlight => _glassHighlight;
  double get navBottomOffset => _navBottom;
  double get navSideInset => _navInset;
  String? get snowImagePath => _snowImage;
  int get snowCount => _snowCount;
  double get snowSize => _snowSize;
  double get snowSpeed => _snowSpeed;

  String get accentHex =>
      '#${_accentColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      _themeMode = ThemeMode
          .values[(prefs.getInt(_kTheme) ?? 0).clamp(0, ThemeMode.values.length - 1)];
      _preset = TideAccent
          .values[(prefs.getInt(_kPreset) ?? 0).clamp(0, TideAccent.values.length - 1)];
      _accentColor = Color(prefs.getInt(_kAccent) ?? _preset.seed.value);
      _refreshRate = prefs.getInt(_kFps) ?? 60;
      _autoConnect = prefs.getBool(_kAutoConnect) ?? false;
      _verboseLogs = prefs.getBool(_kVerbose) ?? false;

      _glassBlur = (prefs.getDouble(_kGlassBlur) ?? 18).clamp(0.0, 30.0);
      _glassHighlight = (prefs.getDouble(_kGlassHighlight) ?? 1.0).clamp(0.0, 1.0);
      _navBottom = (prefs.getDouble(_kNavBottom) ?? 16).clamp(0.0, 48.0);
      _navInset = (prefs.getDouble(_kNavInset) ?? 20).clamp(8.0, 40.0);
      _snowImage = prefs.getString(_kSnowImage);
      _snowCount = (prefs.getInt(_kSnowCount) ?? 26).clamp(5, 100);
      _snowSize = (prefs.getDouble(_kSnowSize) ?? 10).clamp(4.0, 60.0);
      _snowSpeed = (prefs.getDouble(_kSnowSpeed) ?? 1.0).clamp(0.2, 3.0);

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
    _persistInt(_kAccent, accent.seed.value);
  }

  void setAccentColor(Color color, {TideAccent? preset}) {
    _accentColor = color;
    if (preset != null) _preset = preset;
    notifyListeners();
    _persistInt(_kAccent, color.value);
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

  void setGlassBlur(double value) {
    final double v = value.clamp(0.0, 30.0);
    if (v == _glassBlur) return;
    _glassBlur = v;
    notifyListeners();
    _persistDouble(_kGlassBlur, v);
  }

  void setGlassHighlight(double value) {
    final double v = value.clamp(0.0, 1.0);
    if (v == _glassHighlight) return;
    _glassHighlight = v;
    notifyListeners();
    _persistDouble(_kGlassHighlight, v);
  }

  void setNavBottomOffset(double value) {
    final double v = value.clamp(0.0, 48.0);
    if (v == _navBottom) return;
    _navBottom = v;
    notifyListeners();
    _persistDouble(_kNavBottom, v);
  }

  void setNavSideInset(double value) {
    final double v = value.clamp(8.0, 40.0);
    if (v == _navInset) return;
    _navInset = v;
    notifyListeners();
    _persistDouble(_kNavInset, v);
  }

  void setSnowImage(String? path) {
    _snowImage = path;
    notifyListeners();
    if (path == null || path.isEmpty) {
      _remove(_kSnowImage);
    } else {
      _persistString(_kSnowImage, path);
    }
  }

  void setSnowCount(int value) {
    final int v = value.clamp(5, 100);
    if (v == _snowCount) return;
    _snowCount = v;
    notifyListeners();
    _persistInt(_kSnowCount, v);
  }

  void setSnowSize(double value) {
    final double v = value.clamp(4.0, 60.0);
    if (v == _snowSize) return;
    _snowSize = v;
    notifyListeners();
    _persistDouble(_kSnowSize, v);
  }

  void setSnowSpeed(double value) {
    final double v = value.clamp(0.2, 3.0);
    if (v == _snowSpeed) return;
    _snowSpeed = v;
    notifyListeners();
    _persistDouble(_kSnowSpeed, v);
  }

  Future<void> _persistInt(String key, int value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (_) {}
  }

  Future<void> _persistDouble(String key, double value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (_) {}
  }

  Future<void> _persistBool(String key, bool value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  Future<void> _persistString(String key, String value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }

  Future<void> _remove(String key) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
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

  /// 找不到时返回 null（供 LiquidGlassContainer 等底层组件优雅降级）。
  static SettingsController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SettingsScope>()
        ?.notifier;
  }
}
