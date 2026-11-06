import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../design/tokens.dart';
import 'folia_bundle_server.dart';

/// 应用内 Folia：资源来自 APK 内打包的前端构建，不需要联网下载。
class FoliaWebPage extends StatefulWidget {
  const FoliaWebPage({super.key});

  @override
  State<FoliaWebPage> createState() => _FoliaWebPageState();
}

class _FoliaWebPageState extends State<FoliaWebPage> {
  WebViewController? _controller;
  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    FoliaBundleServer.stop();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final int port = await FoliaBundleServer.start();
      if (!FoliaBundleServer.hasBundle) {
        if (!mounted) return;
        setState(() => _error = 'APK 里没有找到 Folia 资源（构建步骤可能没跑成功）');
        return;
      }
      if (!mounted) return;

      final WebViewController controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF09090B))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int value) {
              if (!mounted) return;
              setState(() => _progress = value);
            },
            onPageFinished: (String url) {
              if (!mounted) return;
              setState(() => _progress = 100);
            },
            onWebResourceError: (WebResourceError error) {
              if (!mounted) return;
              if (error.isForMainFrame ?? true) {
                setState(() => _error = error.description);
              }
            },
          ),
        )
        ..loadRequest(Uri.parse('http://127.0.0.1:$port/index.html'));

      setState(() => _controller = controller);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '启动本地资源服务失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final WebViewController? controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final WebViewController? c = controller;
        if (c != null && await c.canGoBack()) {
          await c.goBack();
          return;
        }
        if (!mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF09090B),
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(child: Text('Folia', style: text.titleMedium)),
                    IconButton(
                      onPressed: () => controller?.reload(),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              if (_progress < 100)
                LinearProgressIndicator(
                  value: _progress <= 0 ? null : _progress / 100,
                  minHeight: 2,
                ),
              Expanded(
                child: Stack(
                  children: <Widget>[
                    if (controller != null)
                      WebViewWidget(controller: controller),
                    if (_error != null)
                      Container(
                        color: const Color(0xFF09090B),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 40,
                              color: Colors.white38,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Folia 加载失败',
                              style: text.titleMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: text.bodySmall?.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () {
                                setState(() {
                                  _error = null;
                                  _controller = null;
                                  _progress = 0;
                                });
                                _boot();
                              },
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
