import 'dart:io' show Platform;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/app_launcher.dart';
import '../core/page_transitions.dart';
import '../design/tokens.dart';
import '../features/folia/folia_web_page.dart';
import 'liquid_glass_container.dart';

/// 主页右下角：一键进入 Folia（应用内 WebView，无需安装 Folia）。
/// 点击 = 进入；长按 = 修改 Folia 地址（Windows 上改为选择本地程序）。
class FoliaButton extends StatefulWidget {
  const FoliaButton({super.key});

  @override
  State<FoliaButton> createState() => _FoliaButtonState();
}

class _FoliaButtonState extends State<FoliaButton> {
  bool _busy = false;

  Future<void> _onTap() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();

    if (Platform.isWindows) {
      final bool opened = await FoliaLauncher.openWindowsFolia();
      if (!mounted) return;
      setState(() => _busy = false);
      if (opened) return;

      final String url = await FoliaLauncher.webUrl();
      if (!mounted) return;
      final bool ok = await FoliaLauncher.openExternal(url);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开 Folia，请检查网络或默认浏览器')),
        );
      }
      return;
    }

    final String url = await FoliaLauncher.webUrl();
    if (!mounted) return;
    setState(() => _busy = false);

    if (Platform.isAndroid || Platform.isIOS) {
      Navigator.of(context).push<void>(
        tideRoute<void>(FoliaWebPage(url: url)),
      );
      return;
    }

    final bool ok = await FoliaLauncher.openExternal(url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开 Folia，请检查网络或默认浏览器')),
      );
    }
  }

  Future<void> _configure() async {
    if (Platform.isWindows) {
      await _pickWindowsExe();
      return;
    }
    await _editUrl();
  }

  Future<void> _pickWindowsExe() async {
    try {
      const XTypeGroup group = XTypeGroup(
        label: 'Folia 程序',
        extensions: <String>['exe'],
      );
      final XFile? file =
          await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
      if (file == null || !mounted) return;

      await FoliaLauncher.saveExe(file.path);
      final bool ok = await FoliaLauncher.startExe(file.path);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '已记住 Folia 程序' : '无法启动：${file.path}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择程序失败：$error')),
      );
    }
  }

  Future<void> _editUrl() async {
    final TextEditingController controller =
        TextEditingController(text: await FoliaLauncher.webUrl());
    if (!mounted) return;

    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Folia 地址'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '默认用公共实例：\nhttps://music.aikun-bili.top/\n\n'
                '如果你自己部署了 Folia（Docker），把地址填在这里，\n'
                '例如 http://192.168.1.10:3000 。',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'https://…',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (value == null) return;
    if (value.isEmpty) return;

    await FoliaLauncher.saveUrl(value);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存，下次点击按钮生效')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;

    return GestureDetector(
      onTap: _onTap,
      onLongPress: _configure,
      child: LiquidGlassContainer(
        radius: 28,
        sigma: 0,
        effect: LiquidEffectLevel.static,
        tint: colors.accent,
        padding: const EdgeInsets.all(13),
        child: _busy
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                ),
              )
            : Icon(
                Icons.music_note_rounded,
                size: 22,
                color: colors.accent,
              ),
      ),
    );
  }
}
