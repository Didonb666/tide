import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 背景槽位：统一（横竖屏共用）/ 竖屏专用 / 横屏专用。
enum BackgroundSlot { shared, portrait, landscape }

/// 全局背景状态：三个槽位的媒体路径、透明度、模糊度，全部持久化。
class BackgroundController extends ChangeNotifier {
  static const String _kPath = 'bg.path';
  static const String _kVideo = 'bg.isVideo';
  static const String _kPortraitPath = 'bg.portrait.path';
  static const String _kPortraitVideo = 'bg.portrait.isVideo';
  static const String _kLandscapePath = 'bg.landscape.path';
  static const String _kLandscapeVideo = 'bg.landscape.isVideo';
  static const String _kOpacity = 'bg.opacity';
  static const String _kBlur = 'bg.blur';

  final Map<BackgroundSlot, String?> _paths = <BackgroundSlot, String?>{
    BackgroundSlot.shared: null,
    BackgroundSlot.portrait: null,
    BackgroundSlot.landscape: null,
  };

  final Map<BackgroundSlot, bool> _videos = <BackgroundSlot, bool>{
    BackgroundSlot.shared: false,
    BackgroundSlot.portrait: false,
    BackgroundSlot.landscape: false,
  };

  double _opacity = 0.5;
  double _blur = 0;
  bool _loaded = false;

  double get opacity => _opacity;
  double get blur => _blur;

  /// 统一背景（旧接口，等同于 shared 槽位）。
  String? get mediaPath => _paths[BackgroundSlot.shared];
  bool get isVideo => _videos[BackgroundSlot.shared] ?? false;

  String? get portraitPath => _paths[BackgroundSlot.portrait];
  String? get landscapePath => _paths[BackgroundSlot.landscape];

  String? pathForSlot(BackgroundSlot slot) => _paths[slot];
  bool isVideoForSlot(BackgroundSlot slot) => _videos[slot] ?? false;

  bool hasCustomSlot(BackgroundSlot slot) {
    final String? path = _paths[slot];
    return path != null && path.isNotEmpty;
  }

  bool get hasCustom =>
      _paths.values.any((String? path) => path != null && path.isNotEmpty);

  /// 按屏幕方向取生效背景：优先该方向专用，其次统一背景，都没有则 null。
  String? pathFor(Orientation orientation) {
    final BackgroundSlot slot = orientation == Orientation.portrait
        ? BackgroundSlot.portrait
        : BackgroundSlot.landscape;
    final String? specific = _paths[slot];
    if (specific != null && specific.isNotEmpty) return specific;
    return _paths[BackgroundSlot.shared];
  }

  bool isVideoFor(Orientation orientation) {
    final BackgroundSlot slot = orientation == Orientation.portrait
        ? BackgroundSlot.portrait
        : BackgroundSlot.landscape;
    if (hasCustomSlot(slot)) return _videos[slot] ?? false;
    return _videos[BackgroundSlot.shared] ?? false;
  }

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _paths[BackgroundSlot.shared] = prefs.getString(_kPath);
      _paths[BackgroundSlot.portrait] = prefs.getString(_kPortraitPath);
      _paths[BackgroundSlot.landscape] = prefs.getString(_kLandscapePath);

      _videos[BackgroundSlot.shared] = prefs.getBool(_kVideo) ?? false;
      _videos[BackgroundSlot.portrait] =
          prefs.getBool(_kPortraitVideo) ?? false;
      _videos[BackgroundSlot.landscape] =
          prefs.getBool(_kLandscapeVideo) ?? false;

      _opacity = (prefs.getDouble(_kOpacity) ?? 0.5).clamp(0.0, 1.0);
      _blur = (prefs.getDouble(_kBlur) ?? 0).clamp(0.0, 30.0);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> pickImage({BackgroundSlot slot = BackgroundSlot.shared}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 2400);
    if (file == null) return;
    final String path = await _persistFile(file, slot);
    await _setMedia(slot, path, isVideo: false);
  }

  Future<void> pickVideo({BackgroundSlot slot = BackgroundSlot.shared}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    final String path = await _persistFile(file, slot);
    await _setMedia(slot, path, isVideo: true);
  }

  Future<void> clearSlot(BackgroundSlot slot) async {
    _paths[slot] = null;
    _videos[slot] = false;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pathKey(slot));
      await prefs.remove(_videoKey(slot));
    } catch (_) {}
  }

  /// 恢复默认：三个槽位一起清空。
  Future<void> clearMedia() async {
    for (final BackgroundSlot slot in BackgroundSlot.values) {
      _paths[slot] = null;
      _videos[slot] = false;
    }
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      for (final BackgroundSlot slot in BackgroundSlot.values) {
        await prefs.remove(_pathKey(slot));
        await prefs.remove(_videoKey(slot));
      }
    } catch (_) {}
  }

  Future<void> setOpacity(double value, {bool save = true}) async {
    final double v = value.clamp(0.0, 1.0);
    if (v == _opacity) return;
    _opacity = v;
    notifyListeners();
    if (save) await _persistDouble(_kOpacity, v);
  }

  Future<void> setBlur(double value, {bool save = true}) async {
    final double v = value.clamp(0.0, 30.0);
    if (v == _blur) return;
    _blur = v;
    notifyListeners();
    if (save) await _persistDouble(_kBlur, v);
  }

  String _pathKey(BackgroundSlot slot) {
    switch (slot) {
      case BackgroundSlot.shared:
        return _kPath;
      case BackgroundSlot.portrait:
        return _kPortraitPath;
      case BackgroundSlot.landscape:
        return _kLandscapePath;
    }
  }

  String _videoKey(BackgroundSlot slot) {
    switch (slot) {
      case BackgroundSlot.shared:
        return _kVideo;
      case BackgroundSlot.portrait:
        return _kPortraitVideo;
      case BackgroundSlot.landscape:
        return _kLandscapeVideo;
    }
  }

  Future<String> _persistFile(XFile file, BackgroundSlot slot) async {
    final Directory dir = await getApplicationSupportDirectory();
    final Directory folder = Directory('${dir.path}/backgrounds');
    await folder.create(recursive: true);

    String ext = 'jpg';
    final int dot = file.path.lastIndexOf('.');
    if (dot >= 0 && dot < file.path.length - 1) {
      ext = file.path.substring(dot + 1).toLowerCase();
    }

    final String slotName = slot.name;
    final String dest =
        '${folder.path}/${slotName}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(file.path).copy(dest);
    return dest;
  }

  Future<void> _setMedia(
    BackgroundSlot slot,
    String path, {
    required bool isVideo,
  }) async {
    _paths[slot] = path;
    _videos[slot] = isVideo;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pathKey(slot), path);
      await prefs.setBool(_videoKey(slot), isVideo);
    } catch (_) {}
  }

  Future<void> _persistDouble(String key, double value) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (_) {}
  }
}

class BackgroundScope extends InheritedNotifier<BackgroundController> {
  const BackgroundScope({
    super.key,
    required BackgroundController controller,
    required super.child,
  }) : super(notifier: controller);

  static BackgroundController of(BuildContext context) {
    final BackgroundScope? scope =
        context.dependOnInheritedWidgetOfExactType<BackgroundScope>();
    assert(scope != null, '找不到 BackgroundScope');
    return scope!.notifier!;
  }
}
