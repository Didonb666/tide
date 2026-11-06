import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/settings_controller.dart';
import '../../design/tokens.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../widgets/tide_slider.dart';

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
    if (path == null || path.isEmpty) return '默认 Fs 图标';
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
          sigma: 0,
          effect: LiquidEffectLevel.static,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TideSlider(
                label: '玻璃模糊',
                value: settings.glassBlur,
                max: 30,
                divisions: 30,
                format: (double v) => '${v.round()}',
                onCommit: settings.setGlassBlur,
              ),
              TideSlider(
                label: '玻璃高光',
                value: settings.glassHighlight,
                max: 1,
                divisions: 20,
                format: (double v) => '${(v * 100).round()}%',
                onCommit: settings.setGlassHighlight,
              ),
              TideSlider(
                label: '底栏距底部',
                value: settings.navBottomOffset,
                max: 48,
                divisions: 48,
                format: (double v) => '${v.round()}',
                onCommit: settings.setNavBottomOffset,
              ),
              TideSlider(
                label: '底栏左右缩进',
                value: settings.navSideInset,
                max: 40,
                min: 8,
                divisions: 32,
                format: (double v) => '${v.round()}',
                onCommit: settings.setNavSideInset,
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
                      child: const Text('重置'),
                    ),
                ],
              ),
              TideSlider(
                label: '雪花数量',
                value: settings.snowCount.toDouble(),
                max: 100,
                min: 5,
                divisions: 95,
                format: (double v) => '${v.round()}',
                onCommit: (double v) => settings.setSnowCount(v.round()),
              ),
              TideSlider(
                label: '雪花大小',
                value: settings.snowSize,
                max: 60,
                min: 4,
                divisions: 56,
                format: (double v) => '${v.round()}',
                onCommit: settings.setSnowSize,
              ),
              TideSlider(
                label: '雪花速度',
                value: settings.snowSpeed,
                max: 3,
                min: 0.2,
                divisions: 28,
                format: (double v) => v.toStringAsFixed(1),
                onCommit: settings.setSnowSpeed,
              ),
              const SizedBox(height: 4),
              Text(
                '拖动只预览，松手才保存；雪花图片建议用透明 PNG。',
                style: text.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
