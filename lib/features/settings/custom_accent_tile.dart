import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../core/settings_controller.dart';
import '../../design/tokens.dart';

/// 「设置 → 外观」里的自定义主色调入口：右侧色块 + HSV 调色弹窗。
class CustomAccentTile extends StatelessWidget {
  const CustomAccentTile({super.key});

  Future<void> _openPicker(BuildContext context) async {
    final SettingsController settings = SettingsScope.of(context);

    final Color? picked = await showDialog<Color>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (BuildContext dialogContext) {
        return _ColorPickerDialog(initial: settings.accentColor);
      },
    );

    if (picked != null) {
      settings.setAccentColor(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = SettingsScope.of(context);
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('自定义主色调'),
      subtitle: Text(
        'HSV 调色板 / Hex 输入',
        style: text.labelSmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: settings.accentColor,
              shape: BoxShape.circle,
              border: Border.all(color: colors.hairline),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: settings.accentColor.withOpacity(0.45),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: colors.inkTertiary,
          ),
        ],
      ),
      onTap: () => _openPicker(context),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});

  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _color = widget.initial;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              color: colors.surface.withOpacity(0.93),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.hairline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text('自定义主色调', style: text.titleMedium),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 430),
                  child: SingleChildScrollView(
                    child: ColorPicker(
                      pickerColor: _color,
                      onColorChanged: (Color color) {
                        setState(() => _color = color);
                      },
                      enableAlpha: false,
                      displayThumbColor: true,
                      hexInputBar: true,
                      paletteType: PaletteType.hsvWithHue,
                      pickerAreaHeightPercent: 0.62,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.inkSecondary,
                          side: BorderSide(color: colors.hairline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(TideRadii.md),
                          ),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(_color),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(TideRadii.md),
                          ),
                        ),
                        child: const Text('确定'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
