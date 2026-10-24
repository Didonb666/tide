import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_controller.dart';
import '../../core/profile.dart';
import '../../design/tokens.dart';

enum _ImportMode { choose, paste, url }

Future<Profile?> showImportSheet(
  BuildContext context,
  AppController controller,
) {
  return showModalBottomSheet<Profile>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return ImportSheet(controller: controller);
    },
  );
}

class ImportSheet extends StatefulWidget {
  const ImportSheet({super.key, required this.controller});

  final AppController controller;

  @override
  State<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<ImportSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _yamlCtrl = TextEditingController();
  final TextEditingController _urlCtrl = TextEditingController();

  _ImportMode _mode = _ImportMode.choose;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _yamlCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _fromClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String text = data?.text ?? '';
    setState(() {
      _mode = _ImportMode.paste;
      _yamlCtrl.text = text;
      _error = text.trim().isEmpty ? '剪贴板里没有文本，请先复制 YAML' : null;
    });
  }

  Future<void> _fromFile() async {
    try {
      const XTypeGroup group = XTypeGroup(
        label: 'Clash 配置',
        extensions: <String>['yaml', 'yml', 'txt', 'conf'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
      if (file == null) return;
      final String text = await file.readAsString();
      final String name = file.name.replaceAll(
        RegExp(r'\.(yaml|yml|txt|conf)$', caseSensitive: false),
        '',
      );
      _submit(text, fallbackName: name);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '读取文件失败：$error');
    }
  }

  Future<void> _download() async {
    final String url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '请输入订阅地址');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final String text = await _fetch(url);
      if (!mounted) return;
      _submit(text, fallbackName: Uri.parse(url).host);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '下载失败：$error';
      });
    }
  }

  Future<String> _fetch(String url) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);

    try {
      final HttpClientRequest request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'clash.meta');
      final HttpClientResponse response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final List<int> bytes = await response.fold<List<int>>(
        <int>[],
        (List<int> previous, List<int> chunk) => previous..addAll(chunk),
      );

      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('内容超过 5MB');
      }

      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      client.close(force: true);
    }
  }

  String? _validate(String yaml) {
    final String text = yaml.trim();
    if (text.isEmpty) return '内容为空';
    final bool looksLikeClash = text.contains('proxies:') ||
        text.contains('proxy-groups:') ||
        text.contains('rules:');
    if (!looksLikeClash) {
      return '这不像 Clash.Meta 配置（缺少 proxies / proxy-groups / rules）';
    }
    return null;
  }

  void _submit(String yaml, {String? fallbackName}) {
    final String? error = _validate(yaml);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final String typed = _nameCtrl.text.trim();
    final String name = typed.isNotEmpty
        ? typed
        : (fallbackName != null && fallbackName.trim().isNotEmpty
            ? fallbackName.trim()
            : '导入配置 ${widget.controller.profiles.length + 1}');

    final Profile profile = widget.controller.importProfile(yaml, name: name);
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (_mode != _ImportMode.choose)
                    IconButton(
                      onPressed: () => setState(() {
                        _mode = _ImportMode.choose;
                        _error = null;
                      }),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  Expanded(
                    child: Text(
                      _mode == _ImportMode.choose
                          ? '导入配置'
                          : (_mode == _ImportMode.paste
                              ? '粘贴 / 编辑 YAML'
                              : '订阅地址'),
                      style: text.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TideSpace.x3),
              if (_mode == _ImportMode.choose)
                ..._buildChooser(colors, text)
              else
                ..._buildEditor(colors, text),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChooser(TideColors colors, TextTheme text) {
    return <Widget>[
      _OptionTile(
        icon: Icons.content_paste_rounded,
        title: '从剪贴板粘贴',
        subtitle: '读取剪贴板里的 Clash.Meta YAML',
        onTap: _fromClipboard,
      ),
      const SizedBox(height: 10),
      _OptionTile(
        icon: Icons.link_rounded,
        title: '订阅地址',
        subtitle: '输入 URL，下载后导入',
        onTap: () => setState(() {
          _mode = _ImportMode.url;
          _error = null;
        }),
      ),
      const SizedBox(height: 10),
      _OptionTile(
        icon: Icons.folder_open_rounded,
        title: '本地文件',
        subtitle: '选择 .yaml / .yml / .txt 文件',
        onTap: _fromFile,
      ),
      const SizedBox(height: TideSpace.x4),
      Text(
        '导入后配置会出现在列表里，连接时交给 mihomo 解析。',
        style: text.labelSmall,
      ),
    ];
  }

  List<Widget> _buildEditor(TideColors colors, TextTheme text) {
    return <Widget>[
      TextField(
        controller: _nameCtrl,
        decoration: const InputDecoration(
          labelText: '配置名称（可选）',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      const SizedBox(height: TideSpace.x3),
      if (_mode == _ImportMode.paste)
        TextField(
          controller: _yamlCtrl,
          minLines: 8,
          maxLines: 14,
          style: TideType.mono,
          decoration: const InputDecoration(
            labelText: 'YAML 内容',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        )
      else
        TextField(
          controller: _urlCtrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: '订阅 URL',
            hintText: 'https://example.com/sub.yaml',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      if (_error != null) ...<Widget>[
        const SizedBox(height: TideSpace.x3),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.danger.withOpacity(0.10),
            borderRadius: BorderRadius.circular(TideRadii.sm),
            border: Border.all(color: colors.danger.withOpacity(0.28)),
          ),
          child: Text(
            _error!,
            style: text.labelSmall?.copyWith(color: colors.danger),
          ),
        ),
      ],
      const SizedBox(height: TideSpace.x4),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: _busy
              ? null
              : (_mode == _ImportMode.url
                  ? _download
                  : () => _submit(_yamlCtrl.text)),
          style: FilledButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: TideRadii.rMd),
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_mode == _ImportMode.url ? '下载并导入' : '导入'),
        ),
      ),
      const SizedBox(height: TideSpace.x2),
      if (_mode == _ImportMode.url)
        Text(
          '会用 clash.meta UA 下载，超过 5MB 会被拒绝。',
          style: text.labelSmall,
        ),
    ];
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(TideSpace.x4),
        decoration: BoxDecoration(
          color: colors.surfaceMuted.withOpacity(0.6),
          borderRadius: BorderRadius.circular(TideRadii.lg),
          border: Border.all(color: colors.hairline),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.accent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(TideRadii.md),
              ),
              child: Icon(icon, size: 22, color: colors.accent),
            ),
            const SizedBox(width: TideSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: text.bodySmall),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.inkTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
