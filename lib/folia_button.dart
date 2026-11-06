import 'dart:io' show Platform;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/app_launcher.dart';
import '../design/tokens.dart';
import 'liquid_glass_container.dart';

/// 主页右下角：一键进入 Folia。
/// 点击 = 打开；长按 = 重新指定程序/网址。
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

    final bool ok = await FoliaLauncher.open();
    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      await _configure();
    }
  }

  Future<void> _configure() async {
    if (Platform.isWindows) {
      await _pickWindowsExe();
    } else {
      await _askTarget();
    }
  }

  Future<void> _pickWindowsExe() async {
    try {
      const XTypeGroup group = XTypeGroup(
        label: 'Folia 程序',
        extensions: <String>['exe'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
      if (file == null || !mounted) return;

      await FoliaLauncher.saveExe(file.path);
      final bool ok = await FoliaLauncher.startExe(file.path);
      if (!mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法启动：${file.path}')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择程序失败：$error')),
      );
    }
  }

  Future<void> _askTarget() async {
    final TextEditingController controller = TextEditingController(
      text: await FoliaLauncher.savedUrl() ??
          (await FoliaLauncher.savedPackage()) ??
          '',
    );
    if (!mounted) return;

    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('指定 Folia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '两种填法都支持：\n'
                '· 网址：你部署的 Folia Web 版，或官方文档站；\n'
                '· 包名：安卓套壳 App 的包名，填一次就记住。\n\n'
                '安卓查包名：设置 → 应用 → Folia → 应用信息，页面最下方；'
                '或 adb shell pm list packages | grep -i folia',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'https://… 或 com.folia.music',
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
              child: const Text('保存并打开'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (value == null || value.isEmpty || !mounted) return;

    bool ok;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      await FoliaLauncher.saveUrl(value);
      ok = await FoliaLauncher.openUrl(value);
    } else {
      await FoliaLauncher.savePackage(value);
      ok = await FoliaLauncher.openPackage(value);
    }

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打不开：$value')),
      );
    }
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
