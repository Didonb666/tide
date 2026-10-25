import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/settings_controller.dart';
import '../../design/tokens.dart';
import '../../widgets/liquid_glass_container.dart';

class LiquidEffectsPanel extends StatelessWidget {
  const LiquidEffectsPanel({super.key});

  Future<void> _pickSnow(BuildContext context) async {
    final SettingsController settings = SettingsScope.of(context);
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (file == null) return;

      final Directory dir = await getApplicationSupportDirectory();
      final Directory folder = Directory('${dir.path}/effects');
      await folder.create(recursive: true);

      String ext = 'png';
      final int dot = file.path.lastIndexOf('.');
      if (dot >= 0 && dot < file.path.length - 1) {
        ext = file.path.substring(dot + 1).toLowerCase();
      }
      final String dest =
          '${folder.path}/snow_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(file.path).copy(dest);

      settings.setSnowImage(dest);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择雪花图片失败：$error')),
      );
    }
  }

  String _shortPath(String? path) {
    if (path == null || path.isEmpty) return '默认圆点';
    final List<String> parts = path.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? path : parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = SettingsScope.of(context);
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: <Widget>[
              Expanded(child: Text('玻璃与雪花')),
            ],
          ),
        ),
        LiquidGlassContainer(
          radius: TideRadii.xl,
          sigma: 12,
          effect: LiquidEffectLevel.static,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _LabeledSlider(
                label: '玻璃模糊',
                value: settings.glassBlur,
                max: 30,
                divisions: 30,
                display: (double v) => '${v.round()}',
                onChanged: settings.setGlassBlur,
              ),
              _LabeledSlider(
                label: '玻璃高光',
                value: settings.glassHighlight,
                max: 1,
                divisions: 20,
                display: (double v) => '${(v * 100).round()}%',
                onChanged: settings.setGlassHighlight,
              ),
              _LabeledSlider(
                label: '底栏距底部',
                value: settings.navBottomOffset,
                max: 48,
                divisions: 48,
                display: (double v) => '${v.round()}',
                onChanged: settings.setNavBottomOffset,
              ),
              _LabeledSlider(
                label: '底栏左右缩进',
                value: settings.navSideInset,
                max: 40,
                min: 8,
                divisions: 32,
                display: (double v) => '${v.round()}',
                onChanged: settings.setNavSideInset,
              ),
              const SizedBox(height: 8),
              Divider(color: colors.hairline, height: 1),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '雪花图片：${_shortPath(settings.snowImagePath)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickSnow(context),
                    child: const Text('选择'),
                  ),
                  if (settings.snowImagePath != null)
                    TextButton(
                      onPressed: () => settings.setSnowImage(null),
                      child: const Text('清除'),
                    ),
                ],
              ),
              _LabeledSlider(
                label: '雪花数量',
                value: settings.snowCount.toDouble(),
                max: 100,
                min: 5,
                divisions: 95,
                display: (double v) => '${v.round()}',
                onChanged: (double v) => settings.setSnowCount(v.round()),
              ),
              _LabeledSlider(
                label: '雪花大小',
                value: settings.snowSize,
                max: 60,
                min: 4,
                divisions: 56,
                display: (double v) => '${v.round()}',
                onChanged: settings.setSnowSize,
              ),
              _LabeledSlider(
                label: '雪花速度',
                value: settings.snowSpeed,
                max: 3,
                min: 0.2,
                divisions: 28,
                display: (double v) => v.toStringAsFixed(1),
                onChanged: settings.setSnowSpeed,
              ),
              const SizedBox(height: 4),
              Text(
                '雪花图片建议用透明背景 PNG。模糊/高光立即作用于首页大卡片与底部导航栏。',
                style: text.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.max,
    this.min = 0,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final double min;
  final int divisions;
  final String Function(double) display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(label, style: text.bodySmall),
            const Spacer(),
            Text(
              display(value),
              style: TideType.mono.copyWith(color: colors.accent),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: colors.accent,
          inactiveColor: colors.surfaceMuted,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
