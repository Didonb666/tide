import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetManifest, rootBundle;

/// 把打包进 APK 的 Folia 静态资源用本地 HTTP 服务暴露出来。
class FoliaBundleServer {
  static const String _prefix = 'assets/folia/';

  static HttpServer? _server;
  static int _port = 0;
  static final Map<String, String> _assets = <String, String>{};

  static bool get isRunning => _server != null;
  static int get port => _port;

  static Future<int> start() async {
    if (_server != null) return _port;

    final AssetManifest manifest =
        await AssetManifest.loadFromAssetBundle(rootBundle);
    _assets.clear();
    for (final String key in manifest.listAssets()) {
      if (key.startsWith(_prefix)) {
        _assets[key.substring(_prefix.length)] = key;
      }
    }

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    _server!.listen(_handle);
    return _port;
  }

  static Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = 0;
  }

  static bool get hasBundle => _assets.isNotEmpty;

  static Future<void> _handle(HttpRequest request) async {
    final HttpResponse response = request.response;
    try {
      String path = Uri.decodeComponent(request.uri.path);
      if (path.startsWith('/')) path = path.substring(1);
      if (path.isEmpty) path = 'index.html';

      String? key = _assets[path];

      // 目录请求 / SPA 路由回退
      if (key == null && (path.endsWith('/') || !path.contains('.'))) {
        key = _assets['index.html'];
      }
      key ??= _assets['index.html'];

      if (key == null) {
        response.statusCode = 404;
        await response.close();
        return;
      }

      final ByteData data = await rootBundle.load(key);
      response.headers.contentType = _mime(path);
      response.headers.set('Cache-Control', 'no-store');
      response.add(data.buffer.asUint8List());
      await response.close();
    } catch (_) {
      response.statusCode = 500;
      await response.close();
    }
  }

  static ContentType _mime(String path) {
    final String p = path.toLowerCase();
    if (p.endsWith('.html')) return ContentType.html;
    if (p.endsWith('.js') || p.endsWith('.mjs')) {
      return ContentType('text', 'javascript', charset: 'utf-8');
    }
    if (p.endsWith('.css')) return ContentType('text', 'css', charset: 'utf-8');
    if (p.endsWith('.json') || p.endsWith('.webmanifest')) {
      return ContentType('application', 'json', charset: 'utf-8');
    }
    if (p.endsWith('.svg')) return ContentType('image', 'svg+xml');
    if (p.endsWith('.png')) return ContentType('image', 'png');
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) {
      return ContentType('image', 'jpeg');
    }
    if (p.endsWith('.webp')) return ContentType('image', 'webp');
    if (p.endsWith('.gif')) return ContentType('image', 'gif');
    if (p.endsWith('.ico')) return ContentType('image', 'x-icon');
    if (p.endsWith('.woff')) return ContentType('font', 'woff');
    if (p.endsWith('.woff2')) return ContentType('font', 'woff2');
    if (p.endsWith('.ttf')) return ContentType('font', 'ttf');
    if (p.endsWith('.mp3')) return ContentType('audio', 'mpeg');
    if (p.endsWith('.wasm')) return ContentType('application', 'wasm');
    return ContentType.binary;
  }
}
