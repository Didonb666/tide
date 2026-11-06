import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_launcher.dart';
import '../../design/tokens.dart';

/// 应用内全屏 Folia（Web 版），不需要安装 Folia APK。
class FoliaWebPage extends StatefulWidget {
  const FoliaWebPage({super.key, required this.url});

  final String url;

  @override
  State<FoliaWebPage> createState() => _FoliaWebPageState();
}

class _FoliaWebPageState extends State<FoliaWebPage> {
  late final WebViewController _controller;

  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
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
            setState(() {
              _progress = 100;
              _failed = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted) return;
            if (error.isForMainFrame ?? true) {
              setState(() => _failed = true);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
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
                      tooltip: '返回',
                    ),
                    Expanded(
                      child: Text(
                        'Folia',
                        style: text.titleMedium,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _controller.reload(),
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: '刷新',
                    ),
                    IconButton(
                      onPressed: () => FoliaLauncher.openExternal(widget.url),
                      icon: const Icon(Icons.open_in_browser_rounded),
                      tooltip: '用浏览器打开',
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
                    WebViewWidget(controller: _controller),
                    if (_failed)
                      Container(
                        color: const Color(0xFF09090B),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.wifi_off_rounded,
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
                              '检查网络后重试；也可以在首页长按音符按钮，换成你自己的 Folia 地址。',
                              textAlign: TextAlign.center,
                              style: text.bodySmall?.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () {
                                setState(() => _failed = false);
                                _controller.reload();
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
