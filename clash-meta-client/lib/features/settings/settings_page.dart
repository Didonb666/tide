import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/app_scope.dart';
import '../../design/tokens.dart';
import '../../widgets/common.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: TideSpace.x8),
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
          ValueListenableBuilder<ThemeMode>(
            valueListenable: c.themeMode,
            builder: (BuildContext context, ThemeMode mode, Widget? child) {
              return ListTile(
                title: const Text('主题'),
                subtitle: const Text('浅色 / 深色 / 跟随系统'),
                trailing: Text(c.themeLabel(mode), style: text.bodySmall),
                onTap: c.cycleThemeMode,
              );
            },
          ),
          const Hairline(inset: TideSpace.page),
          const SectionHeader(title: '隧道'),
          ListTile(
            title: const Text('内核状态'),
            subtitle: Text(
              c.usingSimulator ? '未接入内核，当前为界面演示模式' : '原生隧道已就绪',
            ),
            trailing: TideBadge(
              text: c.usingSimulator ? '未接入' : '就绪',
              color: c.usingSimulator ? colors.warning : colors.success,
            ),
          ),
          const Hairline(inset: TideSpace.page),
          ListTile(
            title: const Text('运行模式'),
            subtitle: const Text('规则模式（接入内核后可切换全局 / 直连）'),
            trailing: Text('rule', style: TideType.mono),
          ),
          const Hairline(inset: TideSpace.page),
          const SectionHeader(title: '关于'),
          const ListTile(
            title: Text('版本'),
            trailing: Text('0.1.0 (1)', style: TideType.mono),
          ),
          const Hairline(inset: TideSpace.page),
          ListTile(
            title: const Text('开源许可'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Tide',
              applicationVersion: '0.1.0',
            ),
          ),
          const SizedBox(height: TideSpace.x6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TideSpace.page),
            child: Container(
              padding: const EdgeInsets.all(TideSpace.x4),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: TideRadii.rMd,
              ),
              child: Text(
                '当前版本是「可编译的双端外壳」：UI、状态机、原生通道都已打通，'
                '但还没有把 mihomo 内核打包进来。下一步见 docs/PHASE2_CORE.md。',
                style: text.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
