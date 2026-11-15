import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../core/background_controller.dart';
import '../../core/display_mode_service.dart';
import '../../core/locale_controller.dart';
import '../../core/settings_controller.dart';
import '../../design/app_theme.dart';
import '../../design/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/liquid_glass_container.dart';
import 'liquid_effects_panel.dart';
import '../../widgets/tide_slider.dart';
import '../../core/app_text.dart';

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
        return tr('跟随系统');
      case ThemeMode.light:
        return tr('浅色');
      case ThemeMode.dark:
        return tr('深色');
    }
  }

  String _shortPath(String? path) {
    if (path == null || path.isEmpty) return tr('默认极光');
    final List<String> parts = path.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? path : parts.last;
  }

  String _slotLabel(BackgroundSlot slot) {
    switch (slot) {
      case BackgroundSlot.shared:
        return tr('统一背景');
      case BackgroundSlot.portrait:
        return tr('竖屏背景');
      case BackgroundSlot.landscape:
        return tr('横屏背景');
    }
  }

  Future<void> _pickImage(
    BuildContext context, {
    BackgroundSlot slot = BackgroundSlot.shared,
  }) async {
    final BackgroundController bg = BackgroundScope.of(context);
    try {
      await bg.pickImage(slot: slot);
      if (context.mounted) _toast(context, '${_slotLabel(slot)}${tr('已更新')}');
    } catch (error) {
      if (context.mounted) _toast(context, '${tr('选择图片失败：')}${error}');
    }
  }

  Future<void> _pickVideo(
    BuildContext context, {
    BackgroundSlot slot = BackgroundSlot.shared,
  }) async {
    final BackgroundController bg = BackgroundScope.of(context);
    try {
      await bg.pickVideo(slot: slot);
      if (context.mounted) _toast(context, '${_slotLabel(slot)}${tr('已更新')}');
    } catch (error) {
      if (context.mounted) _toast(context, '${tr('选择视频失败：')}${error}');
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
            child: Text(tr('设置'), style: text.displaySmall),
          ),

          // ---------------------------------------------------------------- 外观
          // ---------------------------------------------------------------- 语言
          SectionHeader(title: AppText.t(context, 'settings.general')),
          _GlassCard(
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.translate_rounded,
                  size: 16,
                  color: colors.accent,
                ),
                const SizedBox(width: 8),
                Text(
                  AppText.t(context, 'settings.language'),
                  style: text.bodyMedium,
                ),
                const Spacer(),
                DropdownButton<AppLanguage>(
                  value: LocaleScope.of(context).language,
                  underline: const SizedBox.shrink(),
                  dropdownColor: colors.surface,
                  borderRadius: BorderRadius.circular(TideRadii.md),
                  items: AppLanguage.values
                      .map<DropdownMenuItem<AppLanguage>>(
                        (AppLanguage item) => DropdownMenuItem<AppLanguage>(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (AppLanguage? value) {
                    if (value != null) {
                      LocaleScope.of(context).setLanguage(value);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: TideSpace.x4),

          // ---------------------------------------------------------------- 外观
          SectionHeader(title: AppText.t(context, 'settings.appearance')),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(tr('主题模式'), style: text.titleSmall),
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
                Text(tr('快捷预设'), style: text.titleSmall),
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
          SectionHeader(title: AppText.t(context, 'settings.performance')),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const LiquidEffectsPanel(),
                const SizedBox(height: TideSpace.x3),
                ValueListenableBuilder<double>(
                  valueListenable: FpsMonitor.instance.fps,
                  builder: (BuildContext context, double fps, Widget? child) {
                    return Text(
                      fps <= 0
                          ? tr('实测帧率：采集中…')
                          : '${tr('实测帧率：')}${fps.toStringAsFixed(1)}${tr(' fps')}',
                      style: TideType.mono.copyWith(color: colors.accent),
                    );
                  },
                ),
                const SizedBox(height: TideSpace.x2),
                Text(tr('Android 会挑选与目标最接近的屏幕模式，桌面端没有该能力时自动忽略。'),
                  style: text.labelSmall,
                ),
              ],
            ),
          ),

          // ---------------------------------------------------------------- 背景
          SectionHeader(title: AppText.t(context, 'settings.background')),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _BackgroundSlotRow(
                  title: tr('统一背景'),
                  subtitle: tr('横竖屏通用；方向专用未设置时用它'),
                  path: bg.pathForSlot(BackgroundSlot.shared),
                  isVideo: bg.isVideoForSlot(BackgroundSlot.shared),
                  onPickImage: () => _pickImage(context),
                  onPickVideo: () => _pickVideo(context),
                  onClear: () => bg.clearSlot(BackgroundSlot.shared),
                ),
                const SizedBox(height: TideSpace.x3),
                _BackgroundSlotRow(
                  title: tr('竖屏背景'),
                  subtitle: tr('手机竖着拿时显示'),
                  path: bg.pathForSlot(BackgroundSlot.portrait),
                  isVideo: bg.isVideoForSlot(BackgroundSlot.portrait),
                  onPickImage: () =>
                      _pickImage(context, slot: BackgroundSlot.portrait),
                  onPickVideo: () =>
                      _pickVideo(context, slot: BackgroundSlot.portrait),
                  onClear: () => bg.clearSlot(BackgroundSlot.portrait),
                ),
                const SizedBox(height: TideSpace.x3),
                _BackgroundSlotRow(
                  title: tr('横屏背景'),
                  subtitle: tr('平板或横屏时显示'),
                  path: bg.pathForSlot(BackgroundSlot.landscape),
                  isVideo: bg.isVideoForSlot(BackgroundSlot.landscape),
                  onPickImage: () =>
                      _pickImage(context, slot: BackgroundSlot.landscape),
                  onPickVideo: () =>
                      _pickVideo(context, slot: BackgroundSlot.landscape),
                  onClear: () => bg.clearSlot(BackgroundSlot.landscape),
                ),
                const SizedBox(height: TideSpace.x1),
                if (bg.hasCustom)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: bg.clearMedia,
                      child: Text(tr('全部恢复默认')),
                    ),
                  ),
                const SizedBox(height: TideSpace.x4),
                _SliderRow(
                  label: tr('背景透明度'),
                  value: bg.opacity,
                  max: 1,
                  divisions: 20,
                  display: (double v) => '${(v * 100).round()}%',
                  onChanged: (double v) => bg.setOpacity(v),
                ),
                _SliderRow(
                  label: tr('背景模糊度'),
                  value: bg.blur,
                  max: 30,
                  divisions: 30,
                  display: (double v) => '${v.round()}',
                  onChanged: (double v) => bg.setBlur(v),
                ),
                const SizedBox(height: TideSpace.x2),
                Text(tr('视频会自动循环、静音播放，切到后台自动暂停；模糊度过高会占用较多 GPU。'),
                  style: text.labelSmall,
                ),
              ],
            ),
          ),

          // ---------------------------------------------------------------- 行为
          SectionHeader(title: AppText.t(context, 'settings.behavior')),
          _GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                SwitchListTile.adaptive(
                  value: s.autoConnect,
                  onChanged: s.setAutoConnect,
                  activeColor: colors.accent,
                  title: Text(tr('启动时自动连接')),
                  subtitle: Text(tr('打开 App 后自动连接当前配置（暂未接入内核逻辑）')),
                ),
                Divider(color: colors.hairline, height: 1),
                SwitchListTile.adaptive(
                  value: s.verboseLogs,
                  onChanged: s.setVerboseLogs,
                  activeColor: colors.accent,
                  title: Text(tr('开启详细日志')),
                  subtitle: Text(tr('记录更多内核日志（暂未接入内核逻辑）')),
                ),
              ],
            ),
          ),

          // ---------------------------------------------------------------- 关于
          SectionHeader(title: AppText.t(context, 'settings.about')),
          _GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                ListTile(
                  title: Text(tr('版本')),
                  trailing: Text('0.1.0 (1)', style: TideType.mono),
                ),
                Divider(color: colors.hairline, height: 1),
                ListTile(
                  title: Text(tr('开源许可')),
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
            child: Text(tr('Fstool · 内核：mihomo'), style: text.labelSmall),
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
          color: selected ? colors.accent.withValues(alpha: 0.16) : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(TideRadii.md),
          border: Border.all(
            color: selected ? colors.accent.withValues(alpha: 0.55) : colors.hairline,
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
                colors: <Color>[base, base.withValues(alpha: 0.62)],
              ),
              border: Border.all(
                color: selected ? colors.ink : Colors.transparent,
                width: 2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: base.withValues(alpha: selected ? 0.55 : 0.28),
                  blurRadius: selected ? 16 : 10,
                  spreadRadius: selected ? 2 : 0,
                ),
              ],
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 20, color: Colors.black87)
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
        side: BorderSide(color: colors.accent.withValues(alpha: 0.5)),
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
    return TideSlider(
      label: label,
      value: value,
      max: max,
      divisions: divisions,
      format: display,
      onCommit: onChanged,
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
      barrierColor: Colors.black.withValues(alpha: 0.55),
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
      title: Text(tr('自定义主色调')),
      subtitle: Text(tr('HSV 调色板 / Hue 滑条 / Hex 输入'), style: text.labelSmall),
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
                  color: settings.accentColor.withValues(alpha: 0.45),
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
              color: colors.surface.withValues(alpha: 0.93),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.hairline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(tr('自定义主色调'), style: text.titleMedium),
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
                        child: Text(tr('取消')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(_color),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: onAccent(colors.accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(TideRadii.md),
                          ),
                        ),
                        child: Text(tr('确定')),
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


class _BackgroundSlotRow extends StatelessWidget {
  const _BackgroundSlotRow({
    required this.title,
    required this.subtitle,
    required this.path,
    required this.isVideo,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onClear,
  });

  final String title;
  final String subtitle;
  final String? path;
  final bool isVideo;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final VoidCallback onClear;

  bool get _has => path != null && path!.isNotEmpty;

  String get _fileName {
    if (!_has) return tr('未设置');
    final List<String> parts = path!.split(RegExp(r'[/\\]'));
    return parts.isEmpty ? path! : parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              isVideo ? Icons.movie_rounded : Icons.image_rounded,
              size: 15,
              color: _has ? colors.accent : colors.inkTertiary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: text.bodyMedium?.copyWith(
                  color: _has ? colors.ink : colors.inkSecondary,
                ),
              ),
            ),
            if (_has)
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(tr('清除')),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 21, top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _has ? _fileName : subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(color: colors.inkTertiary),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.image_outlined,
                      label: tr('图片'),
                      onTap: onPickImage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.movie_outlined,
                      label: tr('视频'),
                      onTap: onPickVideo,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}