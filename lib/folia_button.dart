import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/app_launcher.dart';
import '../design/tokens.dart';
import 'liquid_glass_container.dart';

/// 主页右下角：一键跳转 Folia 音乐播放器。
/// 点击 = 打开；长按 = 重新填写包名。
class FoliaButton extends StatefulWidget {
  const FoliaButton({super.key});

  @override
  State<FoliaButton> createState() => _FoliaButtonState();
}

class _FoliaButtonState extends State<FoliaButton> {
  bool _busy = false;

  Future<void> _onTap() async {
    if (_busy) return;

    if (defaultTargetPlatform != TargetPlatform.android) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('仅 Android 支持跳转 Folia')),
      );
      return;
    }

    setState(() => _busy = true);
    HapticFeedback.selectionClick();

    final bool ok = await AppLauncher.openFolia();
    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      await _askPackage();
    }
  }

  Future<void> _askPackage() async {
    final String? saved = await AppLauncher.savedPackage();
    if (!mounted) return;

    final TextEditingController controller =
        TextEditingController(text: saved ?? '');

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('找不到 Folia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '请填写 Folia 的包名，填一次就会记住。\n\n'
                '查看方法：设置 → 应用 → Folia → 应用信息，'
                '页面最下方可以看到包名；'
                '或者 adb shell pm list packages | grep folia',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'com.example.folia',
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

    if (result == null || result.isEmpty || !mounted) return;

    final bool ok = await AppLauncher.open(result);
    if (!mounted) return;

    if (ok) {
      await AppLauncher.savePackage(result);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('无法打开 $result：包名不对或未安装')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;

    return GestureDetector(
      onTap: _onTap,
      onLongPress: _askPackage,
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
