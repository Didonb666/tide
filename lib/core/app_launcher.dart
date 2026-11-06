import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Folia 相关能力：
///   · 移动端：用应用内 WebView 打开（不需要安装 Folia）
///   · Windows：优先启动本地桌面版，没有就用浏览器打开网页
class FoliaLauncher {
  static const MethodChannel _channel = MethodChannel('fstool/apps');

  static const String _urlKey = 'folia.url';
  static const String _exeKey = 'folia.exe';

  /// 公共 Folia Web 实例（第三方部署，开箱即用）。
  static const String defaultUrl = 'https://music.aikun-bili.top/';

  // ---------------------------------------------------------------------------
  // 网址
  // ---------------------------------------------------------------------------

  static Future<String> webUrl() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString(_urlKey);
      if (saved != null && saved.trim().isNotEmpty) return saved.trim();
    } catch (_) {}
    return defaultUrl;
  }

  static Future<void> saveUrl(String url) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String value = url.trim();
      if (value.isEmpty) {
        await prefs.remove(_urlKey);
      } else {
        await prefs.setString(_urlKey, value);
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Windows 桌面版
  // ---------------------------------------------------------------------------

  static Future<String?> savedExe() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? value = prefs.getString(_exeKey);
      return (value == null || value.isEmpty) ? null : value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveExe(String path) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_exeKey, path);
    } catch (_) {}
  }

  /// 先试记住的路径，再扫描常见安装目录。
  static Future<bool> openWindowsFolia() async {
    final String? saved = await savedExe();
    if (saved != null && File(saved).existsSync() && await startExe(saved)) {
      return true;
    }

    final String? found = await detectWindowsExe();
    if (found != null) {
      await saveExe(found);
      return startExe(found);
    }
    return false;
  }

  static Future<String?> detectWindowsExe() async {
    final List<String> roots = <String>[
      if (Platform.environment['LOCALAPPDATA'] != null)
        '${Platform.environment['LOCALAPPDATA']}\\Programs',
      if (Platform.environment['ProgramFiles'] != null)
        Platform.environment['ProgramFiles']!,
      if (Platform.environment['ProgramFiles(x86)'] != null)
        Platform.environment['ProgramFiles(x86)']!,
    ];

    for (final String root in roots) {
      final Directory dir = Directory(root);
      if (!dir.existsSync()) continue;
      try {
        for (final FileSystemEntity entity in dir.listSync(followLinks: false)) {
          if (entity is! Directory) continue;
          final String folder =
              entity.path.split(Platform.pathSeparator).last.toLowerCase();
          if (!folder.contains('folia')) continue;
          for (final FileSystemEntity child
              in entity.listSync(followLinks: false)) {
            if (child is File && child.path.toLowerCase().endsWith('.exe')) {
              return child.path;
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  static Future<bool> startExe(String path) async {
    try {
      await Process.start(
        path,
        const <String>[],
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 外部浏览器
  // ---------------------------------------------------------------------------

  static Future<bool> openExternal(String url) async {
    final String target = url.trim();
    if (target.isEmpty) return false;

    if (Platform.isAndroid) {
      try {
        final bool? ok = await _channel.invokeMethod<bool>(
          'openUrl',
          <String, Object?>{'url': target},
        );
        return ok ?? false;
      } catch (_) {
        return false;
      }
    }

    try {
      if (Platform.isWindows) {
        await Process.start(
          'cmd',
          <String>['/c', 'start', '', target],
          runInShell: true,
        );
        return true;
      }
      if (Platform.isMacOS) {
        await Process.start('open', <String>[target]);
        return true;
      }
      if (Platform.isLinux) {
        await Process.start('xdg-open', <String>[target]);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
