import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../core/background_controller.dart';
import '../../core/display_mode_service.dart';
import '../../core/settings_controller.dart';
import '../../design/app_theme.dart';
import '../../design/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/liquid_glass_container.dart';
import 'liquid_effects_panel.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    FpsMonitor.instance.start();
  }

  @override
  void dispose() {
    FpsMonitor.instance.stop();
    super.dispose();
  }

  String _modeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
    }
  }

  String _shortPath(String? path) {
    if (path == null || path.isEmpty) return '默认极光';
    final List<String> parts = path.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? path : parts.last;
  }

  Future<void> _pickImage(BuildContext context) async {
    final BackgroundController bg = BackgroundScope.of(context);
    try {
      await bg.pickImage();
      if (context.mounted) _toast(context, '背景已更换');
    } catch (error) {
      if (context.mounted) _toast(context, '选择图片失败：$error');
    }
  }

  Future<void> _pickVideo(BuildContext context) async {
    final BackgroundController bg = BackgroundScope.of(context);
    try {
      await bg.pickVideo();
      if (context.mounted) _toast(context, '视频背景已更换');
    } catch (error) {
      if (context.mounted) _toast(context, '选择视频失败：$error');
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController s = SettingsScope.of(context);
    final BackgroundController bg = BackgroundScope.of(context);
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TideSpace.page,
              TideSpace.x2,
              TideSpace.page,
              TideSpace.x1,
            ),
            child: Text('设置', style: text.displaySmall),
          ),

          // ---------------------------------------------------------------- 外观
          const SectionHeader(title: '外观'),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('主题模式', style: text.titleSmall),
                const SizedBox(height: TideSpace.x2),
                Row(
                  children: <Widget>[
                    for (final ThemeMode mode in ThemeMode.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _ModeChip(
                            label: _modeLabel(mode),
                            selected: s.themeMode == mode,
                            onTap: () => s.setThemeMode(mode),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: TideSpace.x5),
                Text('快捷预设', style: text.titleSmall),
                const SizedBox(height: TideSpace.x3),
                Row(
                  children: <Widget>[
                    for (final TideAccent accent in TideAccent.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: _AccentDot(
                          accent: accent,
                          selected: s.accent == accent,
                          onTap: () => s.setAccent(accent),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: TideSpace.x2),
                Divider(color: colors.hairline, height: 1),
                _CustomAccentTile(),
              ],
            ),
          ),

          // ---------------------------------------------------------------- 性能
          const SectionHeader(title: '性能'),
          _GlassCard(
            const LiquidEffectsPanel(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<int>(
                  value: s.refreshRate,
                  decoration: const InputDecoration(
                    labelText: '屏幕刷新率',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const <DropdownMenuItem<int>>[
                    DropdownMenuItem<int>(value: 60, child: Text('60 Hz')),
                    DropdownMenuItem<int>(value: 90, child: Text('90 Hz')),
                    DropdownMenuItem<int>(value: 120, child: Text('120 Hz')),
                  ],
                  onChanged: (int? value) {
                    if (value != null) s.setRefreshRate(value);
                  },
                ),
                const SizedBox(height: TideSpace.x3),
                ValueListenableBuilder<double>(
                  valueListenable: FpsMonitor.instance.fps,
                  builder: (BuildContext context, double fps, Widget? child) {
                    return Text(
                      fps <= 0
                          ? '实测帧率：采集中…'
                          : '实测帧率：${fps.toStringAsFixed(1)} fps',
                      style: TideType.mono.copyWith(color: colors.accent),
                    );
                  },
                ),
                const SizedBox(height: TideSpace.x2),
                Text(
                  'Android 会挑选与目标最接近的屏幕模式，桌面端没有该能力时自动忽略。',
                  style: text.labelSmall,
                ),
              ],
            ),
          ),

          // ---------------------------------------------------------------- 背景
          const SectionHeader(title: '背景设置'),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      bg.isVideo ? Icons.movie_rounded : Icons.image_rounded,
                      size: 16,
                      color: colors.accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        bg.hasCustom
                            ? '自定义背景：${_shortPath(bg.mediaPath)}'
                            : '默认极光背景',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ),
                    if (bg.hasCustom)
                      TextButton(
                        onPressed: bg.clearMedia,
                        child: const Text('恢复默认'),
                      ),
                  ],
                ),
                const SizedBox(height: TideSpace.x3),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.image_outlined,
                        label: '选择图片',
                        onTap: () => _pickImage(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.movie_outlined,
                        label: '选择视频',
                        onTap: () => _pickVideo(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TideSpace.x4),
                _SliderRow(
                  label: '背景透明度',
                  value: bg.opacity,
                  max: 1,
                  divisions: 20,
                  display: (double v) => '${(v * 100).round()}%',
                  onChanged: (double v) => bg.setOpacity(v),
                ),
                _SliderRow(
                  label: '背景模糊度',
                  value: bg.blur,
                  max: 30,
                  divisions: 30,
                  display: (double v) => '${v.round()}',
                  onChanged: (double v) => bg.setBlur(v),
                ),
                const SizedBox(height: TideSpace.x2),
                Text(
                  '视频会自动循环、静音播放，切到后台自动暂停；模糊度过高会占用较多 GPU。',
                  style: text.labelSmall,
                ),
              ],
            ),
          ),

          // ---------------------------------------------------------------- 行为
          const SectionHeader(title: '行为'),
          _GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                SwitchListTile.adaptive(
                  value: s.autoConnect,
                  onChanged: s.setAutoConnect,
                  activeColor: colors.accent,
                  title: const Text('启动时自动连接'),
                  subtitle: const Text('打开 App 后自动连接当前配置（暂未接入内核逻辑）'),
                ),
                Divider(color: colors.hairline, height: 1),
                SwitchListTile.adaptive(
                  value: s.verboseLogs,
                  onChanged: s.setVerboseLogs,
                  activeColor: colors.accent,
                  title: const Text('开启详细日志'),
                  subtitle: const Text('记录更多内核日志（暂未接入内核逻辑）'),
                ),
              ],
            ),
          ),

          // ---------------------------------------------------------------- 关于
          const SectionHeader(title: '关于'),
          _GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                ListTile(
                  title: const Text('版本'),
                  trailing: Text('0.1.0 (1)', style: TideType.mono),
                ),
                Divider(color: colors.hairline, height: 1),
                ListTile(
                  title: const Text('开源许可'),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.inkTertiary,
                  ),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Fstool',
                    applicationVersion: '0.1.0',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: TideSpace.x6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TideSpace.page),
            child: Text('Fstool · 内核：mihomo', style: text.labelSmall),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 卡片与小组件
// ---------------------------------------------------------------------------

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassContainer(
      radius: TideRadii.xl,
      sigma: 12,
      effect: LiquidEffectLevel.static,
      margin: const EdgeInsets.symmetric(
        horizontal: TideSpace.page,
        vertical: 2,
      ),
      padding: padding ?? const EdgeInsets.all(TideSpace.x4),
      child: child,
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: TideMotion.standard,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.accent.withOpacity(0.16) : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(TideRadii.md),
          border: Border.all(
            color: selected ? colors.accent.withOpacity(0.55) : colors.hairline,
          ),
        ),
        child: Text(
          label,
          style: TideType.caption.copyWith(
            color: selected ? colors.accent : colors.inkSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final TideAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final Color base = accent.accentFor(Theme.of(context).brightness);

    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[base, base.withOpacity(0.62)],
              ),
              border: Border.all(
                color: selected ? colors.ink : Colors.transparent,
                width: 2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: base.withOpacity(selected ? 0.55 : 0.28),
                  blurRadius: selected ? 16 : 10,
                  spreadRadius: selected ? 2 : 0,
                ),
              ],
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          accent.label,
          style: TideType.caption.copyWith(
            color: selected ? colors.ink : colors.inkTertiary,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.accent,
        side: BorderSide(color: colors.accent.withOpacity(0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TideRadii.md),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
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
          value: value.clamp(0.0, max),
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

// ---------------------------------------------------------------------------
// HSV 调色板
// ---------------------------------------------------------------------------

class _CustomAccentTile extends StatelessWidget {
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
      subtitle: Text('HSV 调色板 / Hue 滑条 / Hex 输入', style: text.labelSmall),
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
