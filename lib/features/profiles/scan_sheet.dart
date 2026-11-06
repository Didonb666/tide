import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/app_controller.dart';
import '../../core/profile.dart';
import '../../design/tokens.dart';
import '../../widgets/liquid_glass_container.dart';

Future<Profile?> showScanSheet(BuildContext context, AppController controller) {
  return showModalBottomSheet<Profile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (BuildContext sheetContext) =>
        ScanSheet(controller: controller),
  );
}

class ScanSheet extends StatefulWidget {
  const ScanSheet({super.key, required this.controller});

  final AppController controller;

  @override
  State<ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<ScanSheet> {
  final MobileScannerController _scanner = MobileScannerController();

  bool _busy = false;
  String? _error;

  bool get _supported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _handle(String raw) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _scanner.stop();
    } catch (_) {}

    try {
      final String text = raw.trim();
      String yaml;
      String name = '扫码导入';

      if (text.startsWith('vless://')) {
        final Map<String, String> parsed = _parseVless(text);
        name = parsed['name'] ?? name;
        yaml = parsed['yaml']!;
      } else if (text.startsWith('http://') || text.startsWith('https://')) {
        yaml = await _download(text);
        name = '订阅 ${DateTime.now().month}-${DateTime.now().day}';
      } else {
        yaml = text;
      }

      if (!yaml.contains('proxies:') &&
          !yaml.contains('proxy-groups:') &&
          !yaml.contains('rules:')) {
        throw const FormatException('二维码内容不是 Clash / VLESS 配置');
      }

      final Profile profile =
          widget.controller.importProfile(yaml, name: name);
      if (!mounted) return;
      Navigator.of(context).pop(profile);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$error';
      });
      try {
        await _scanner.start();
      } catch (_) {}
    }
  }

  Future<String> _download(String url) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final HttpClientRequest request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'clash.meta');
      final HttpClientResponse response = await request.close();
      final StringBuffer buffer = StringBuffer();
      int size = 0;
      await for (final List<int> chunk in response) {
        size += chunk.length;
        if (size > 5 * 1024 * 1024) {
          throw const FormatException('文件超过 5MB，已中止');
        }
        buffer.write(utf8.decode(chunk, allowMalformed: true));
      }
      return buffer.toString();
    } finally {
      client.close(force: true);
    }
  }

  Map<String, String> _parseVless(String uri) {
    final Uri u = Uri.parse(uri);
    final Map<String, String> q = u.queryParameters;
    final String name =
        u.fragment.isEmpty ? '扫码节点' : Uri.decodeComponent(u.fragment);
    final String flow = q['flow'] ?? '';
    final String sni = q['sni'] ?? '';
    final String fp = q['fp'] ?? 'chrome';
    final String pbk = q['pbk'] ?? '';
    final String sid = q['sid'] ?? '';
    final String network = q['type'] ?? 'tcp';
    final String security = q['security'] ?? 'none';

    final StringBuffer b = StringBuffer()
      ..writeln('mixed-port: 7890')
      ..writeln('allow-lan: false')
      ..writeln('mode: rule')
      ..writeln('log-level: info')
      ..writeln('ipv6: true')
      ..writeln('find-process-mode: off')
      ..writeln('')
      ..writeln('dns:')
      ..writeln('  enable: true')
      ..writeln('  ipv6: false')
      ..writeln('  enhanced-mode: normal')
      ..writeln('  nameserver:')
      ..writeln('    - 223.5.5.5')
      ..writeln('    - 119.29.29.29')
      ..writeln('')
      ..writeln('proxies:')
      ..writeln('  - name: "$name"')
      ..writeln('    type: vless')
      ..writeln('    server: ${u.host}')
      ..writeln('    port: ${u.port}')
      ..writeln('    uuid: ${u.userInfo}')
      ..writeln('    network: $network')
      ..writeln('    udp: true');

    if (security == 'reality' || security == 'tls') {
      b.writeln('    tls: true');
    }
    if (flow.isNotEmpty) b.writeln('    flow: $flow');
    if (sni.isNotEmpty) b.writeln('    servername: $sni');
    if (fp.isNotEmpty) b.writeln('    client-fingerprint: $fp');
    if (pbk.isNotEmpty) {
      b.writeln('    reality-opts:');
      b.writeln('      public-key: $pbk');
      if (sid.isNotEmpty) b.writeln('      short-id: $sid');
    }

    b
      ..writeln('')
      ..writeln('proxy-groups:')
      ..writeln('  - name: "PROXY"')
      ..writeln('    type: select')
      ..writeln('    proxies:')
      ..writeln('      - "$name"')
      ..writeln('')
      ..writeln('rules:')
      ..writeln('  - MATCH,PROXY');

    return <String, String>{'name': name, 'yaml': b.toString()};
  }

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: LiquidGlassContainer(
          radius: 28,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text('扫码导入', style: text.titleMedium)),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (!_supported)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    '当前平台不支持摄像头扫码，请用「粘贴」或「URL」导入。',
                    textAlign: TextAlign.center,
                    style: text.bodySmall,
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: <Widget>[
                        MobileScanner(
                          controller: _scanner,
                          onDetect: (BarcodeCapture capture) {
                            for (final Barcode barcode in capture.barcodes) {
                              final String? value = barcode.rawValue;
                              if (value != null && value.trim().isNotEmpty) {
                                _handle(value);
                                break;
                              }
                            }
                          },
                        ),
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colors.accent.withOpacity(0.75),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: IconButton.filledTonal(
                            onPressed: () => _scanner.toggleTorch(),
                            icon: const Icon(Icons.flashlight_on_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                '支持：vless:// 链接、订阅 URL、Clash YAML 文本',
                style: text.labelSmall,
              ),
              if (_busy) ...<Widget>[
                const SizedBox(height: 10),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: text.labelSmall?.copyWith(color: colors.danger),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
