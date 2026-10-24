import 'package:flutter/material.dart';

import '../../core/display_mode_service.dart';
import '../../core/settings_controller.dart';
import '../../design/app_theme.dart';
import '../../design/tokens.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({super.key});

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  final TextEditingController _hexCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final SettingsController settings = SettingsScope.of(context);
    _hexCtrl.text = settings.accentHex;
    FpsMonitor.instance.start();
  }

  @override
  void dispose() {
    FpsMonitor.instance.stop();
    _hexCtrl.dispose();
    super.dispose();
  }

  void _applyHex(SettingsController settings) {
    final String raw = _hexCtrl.text.trim().replaceAll('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(raw)) {
      setState(() => _error = '请输入 6 位 Hex，例如 #FF5722');
      return;
    }
    setState(() => _error = null);
    settings.setAccentColor(Color(int.parse('FF$raw', radix: 16)));
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = SettingsScope.of(context);
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('高级设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: <Widget>[
          const SizedBox(height: 8),
          const _SectionTitle(title: '主色调'),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: <Widget>[
                    for (final TideAccent preset in TideAccent.values)
                      _PresetDot(
                        preset: preset,
                        selected: settings.accent == preset,
                        onTap: () {
                          settings.setAccent(preset);
                          _hexCtrl.text = settings.accentHex;
                          setState(() => _error = null);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('自定义 Hex', style: text.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: settings.accentColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.hairline),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _hexCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: '#FF5722',
                          isDense: true,
                          errorText: _error,
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _applyHex(settings),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => _applyHex(settings),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('应用'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const _SectionTitle(title: '屏幕刷新率'),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<int>(
                  value: settings.refreshRate,
                  decoration: const InputDecoration(
                    labelText: '目标帧率',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const <DropdownMenuItem<int>>[
                    DropdownMenuItem<int>(value: 60, child: Text('60 Hz')),
                    DropdownMenuItem<int>(value: 90, child: Text('90 Hz')),
                    DropdownMenuItem<int>(value: 120, child: Text('120 Hz')),
                  ],
                  onChanged: (int? value) {
                    if (value != null) settings.setRefreshRate(value);
                  },
                ),
                const SizedBox(height: 14),
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
                const SizedBox(height: 8),
                Text(
                  '说明：Android 会挑选与目标最接近的屏幕模式；桌面端没有该能力时自动忽略。',
                  style: text.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(title, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.hairline),
        color: colors.surface,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(context.isDark ? 0.35 : 0.05),
            blurRadius: 22,
            spreadRadius: -12,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PresetDot extends StatelessWidget {
  const _PresetDot({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final TideAccent preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final Color base = preset.accentFor(Theme.of(context).brightness);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[base, base.withOpacity(0.6)],
              ),
              border: Border.all(
                color: selected ? colors.ink : Colors.transparent,
                width: 2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: base.withOpacity(selected ? 0.55 : 0.25),
                  blurRadius: selected ? 16 : 8,
                  spreadRadius: selected ? 2 : 0,
                ),
              ],
            ),
            child: selected
                ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 6),
          Text(
            preset.label,
            style: TideType.caption.copyWith(
              color: selected ? colors.ink : colors.inkTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
