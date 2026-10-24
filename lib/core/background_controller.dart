import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局背景状态：媒体路径 / 类型 / 透明度 / 模糊度，全部持久化。
class BackgroundController extends ChangeNotifier {
  static const String _kPath = 'bg.path';
  static const String _kVideo = 'bg.isVideo';
  static const String _kOpacity = 'bg.opacity';
  static const String _kBlur = 'bg.blur';

  String? _mediaPath;
  bool _isVideo = false;
  double _opacity = 0.5;
  double _blur = 0;
  bool _loaded = false;

  String? get mediaPath => _mediaPath;
  bool get isVideo => _isVideo;
  double get opacity => _opacity;
  double get blur => _blur;
  bool get hasCustom => _mediaPath != null && _mediaPath!.isNotEmpty;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _mediaPath = prefs.getString(_kPath);
      _isVideo = prefs.getBool(_kVideo) ?? false;
      _opacity = (prefs.getDouble(_kOpacity) ?? 0.5).clamp(0.0, 1.0);
      _blur = (prefs.getDouble(_kBlur) ?? 0).clamp(0.0, 30.0);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 2400);
    if (file == null) return;
    final String path = await _persistFile(file);
    await _setMedia(path, isVideo: false);
  }

  Future<void> pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    final String path = await _persistFile(file);
    await _setMedia(path, isVideo: true);
  }

  Future<void> clearMedia() async {
    _mediaPath = null;
    _isVideo = false;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPath);
      await prefs.remove(_kVideo);
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

  Future<String> _persistFile(XFile file) async {
    final Directory dir = await getApplicationSupportDirectory();
    final Directory folder = Directory('${dir.path}/backgrounds');
    await folder.create(recursive: true);

    String ext = 'jpg';
    final int dot = file.path.lastIndexOf('.');
    if (dot >= 0 && dot < file.path.length - 1) {
      ext = file.path.substring(dot + 1).toLowerCase();
    }

    final String dest =
        '${folder.path}/bg_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(file.path).copy(dest);
    return dest;
  }

  Future<void> _setMedia(String path, {required bool isVideo}) async {
    _mediaPath = path;
    _isVideo = isVideo;
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPath, path);
      await prefs.setBool(_kVideo, isVideo);
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
