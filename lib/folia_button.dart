import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/page_transitions.dart';
import '../design/tokens.dart';
import '../features/folia/folia_web_page.dart';
import 'liquid_glass_container.dart';

/// 首页右下角：应用内打开 Folia（资源已打包进 APK）。
class FoliaButton extends StatefulWidget {
  const FoliaButton({super.key});

  @override
  State<FoliaButton> createState() => _FoliaButtonState();
}

class _FoliaButtonState extends State<FoliaButton> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();

    await Navigator.of(context).push<void>(
      tideRoute<void>(const FoliaWebPage()),
    );

    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;

    return GestureDetector(
      onTap: _open,
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
