import 'package:flutter/material.dart';

import '../../core/settings_controller.dart';
import '../../design/app_theme.dart';
import '../../design/tokens.dart';
import '../../widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController s = SettingsScope.of(context);
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final bool dark = context.isDark;

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
                Text('主色调', style: text.titleSmall),
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
              ],
            ),
          ),
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
            child: Text(
              dark ? 'Fstool · 内核：mihomo' : 'Fstool · 内核：mihomo',
              style: text.labelSmall,
            ),
          ),
        ],
      ),
    );
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
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final bool dark = context.isDark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: TideSpace.page),
      padding: padding ?? const EdgeInsets.all(TideSpace.x4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TideRadii.xl),
        border: Border.all(color: colors.hairline),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.surface,
            Color.alphaBlend(colors.accent.withOpacity(0.035), colors.surface),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.40 : 0.05),
            blurRadius: 24,
            spreadRadius: -12,
            offset: const Offset(0, 12),
          ),
        ],
      ),
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
