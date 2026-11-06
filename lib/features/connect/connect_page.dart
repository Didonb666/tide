import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/app_scope.dart';
import '../../core/page_transitions.dart';
import '../../core/profile.dart';
import '../../core/tunnel/tunnel_state.dart';
import '../../design/tokens.dart';
import '../../widgets/common.dart' hide AnimatedNumber;
import '../../widgets/fx.dart' show AnimatedNumber;
import '../../widgets/liquid_glass_container.dart';
import '../profiles/profile_detail_page.dart';

class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final bool wide = MediaQuery.sizeOf(context).width >= 760;

    final Widget mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _TitleRow(state: c.tunnelState),
        const SizedBox(height: 14),
        _AnnouncementCard(controller: c),
        const SizedBox(height: 18),
        const _SectionLabel(text: '连接状态'),
        const SizedBox(height: 8),
        _InfoCard(controller: c),
      ],
    );

    final Widget nodeCard = _NodeQuickCard(
      controller: c,
      onPick: () => _showNodePicker(context, c),
    );

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 150),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: TideSpace.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 10),
              const Center(child: _KernelBanner()),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: mainColumn),
                    const SizedBox(width: 20),
                    SizedBox(width: 320, child: nodeCard),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    mainColumn,
                    const SizedBox(height: 12),
                    nodeCard,
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNodePicker(BuildContext context, AppController c) async {
    final Profile? picked = await showModalBottomSheet<Profile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (BuildContext sheetContext) {
        final TideColors colors = sheetContext.colors;
        final TextTheme text = Theme.of(sheetContext).textTheme;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: LiquidGlassContainer(
              radius: 28,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.inkTertiary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('选择节点', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '切换后立即使用新节点连接',
                    style: text.labelSmall,
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 380),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (final Profile p in c.profiles)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: _NodeAvatar(profile: p, size: 40),
                              title: Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleMedium,
                              ),
                              subtitle: Text(
                                p.groupSummary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall,
                              ),
                              trailing: p.id == c.activeProfileId
                                  ? Icon(
                                      Icons.check_circle_rounded,
                                      color: colors.accent,
                                    )
                                  : Icon(
                                      Icons.circle_outlined,
                                      color: colors.inkTertiary,
                                    ),
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(p),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '提示：更多配置可在「配置」页导入或更换头像',
                    style: text.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (picked != null) {
      c.selectProfile(picked.id);
    }
  }
}

// ---------------------------------------------------------------------------
// 顶部
// ---------------------------------------------------------------------------

class _KernelBanner extends StatelessWidget {
  const _KernelBanner();

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return LiquidGlassContainer(
      radius: 26,
      sigma: 0,
      effect: LiquidEffectLevel.static,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.system_update_alt_rounded,
            size: 16,
            color: colors.accent,
          ),
          const SizedBox(width: 8),
          Text('内核 mihomo v1.19.33', style: text.labelSmall),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: colors.success.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.success.withOpacity(0.35)),
            ),
            child: Text(
              '已是最新',
              style: text.labelSmall?.copyWith(
                color: colors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.state});

  final TunnelState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text('Fstool', style: Theme.of(context).textTheme.displaySmall),
        ),
        StatusPill(phase: state.phase),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 公告卡
// ---------------------------------------------------------------------------

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final Profile? p = controller.activeProfile;

    return LiquidGlassContainer(
      radius: 24,
      sigma: 0,
      effect: LiquidEffectLevel.static,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent.withOpacity(0.14),
                  border: Border.all(color: colors.accent.withOpacity(0.25)),
                ),
                child: Icon(
                  Icons.campaign_rounded,
                  size: 22,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('官方公告', style: text.labelSmall),
                    const SizedBox(height: 2),
                    Text('公告', style: text.titleMedium),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: p == null
                    ? null
                    : () => Navigator.of(context).push<void>(
                          tideRoute<void>(ProfileDetailPage(profile: p)),
                        ),
                child: Row(
                  children: <Widget>[
                    Text(
                      '查看',
                      style: text.labelMedium?.copyWith(color: colors.accent),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '欢迎使用 Fstool。当前内核 mihomo v1.19.33，支持 VMess / VLESS / Trojan / Shadowsocks。',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 连接详情卡
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.colors.inkTertiary,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final Profile? p = controller.activeProfile;
    final TunnelState state = controller.tunnelState;

    return LiquidGlassContainer(
      radius: 24,
      sigma: 0,
      effect: LiquidEffectLevel.static,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: <Widget>[
          _InfoRow(
            label: '配置',
            value: Text(
              p?.name ?? '未选择',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium,
            ),
          ),
          const _RowDivider(),
          _InfoRow(
            label: '协议',
            value: Text(_protocolOf(p), style: text.bodyMedium),
          ),
          const _RowDivider(),
          _InfoRow(
            label: '地址',
            value: Text(
              _serverOf(p),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TideType.mono.copyWith(color: colors.inkSecondary),
            ),
          ),
          const _RowDivider(),
          _InfoRow(
            label: '上行',
            value: AnimatedNumber(
              value: state.upBytesPerSec,
              formatter: formatRate,
              style: TideType.mono.copyWith(color: colors.inkSecondary),
            ),
          ),
          const _RowDivider(),
          _InfoRow(
            label: '下行',
            value: AnimatedNumber(
              value: state.downBytesPerSec,
              formatter: formatRate,
              style: TideType.mono.copyWith(color: colors.inkSecondary),
            ),
          ),
          const _RowDivider(),
          _InfoRow(
            label: '规则',
            value: Text(
              '${p?.ruleCount ?? 0}',
              style: TideType.mono.copyWith(color: colors.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }

  static String _protocolOf(Profile? p) {
    if (p == null) return '—';
    final String yaml = p.rawYaml;
    if (yaml.contains('reality-opts')) return 'VLESS · Reality';
    if (yaml.contains('type: vless')) return 'VLESS';
    if (yaml.contains('type: vmess')) return 'VMess';
    if (yaml.contains('type: trojan')) return 'Trojan';
    if (yaml.contains('type: ss')) return 'Shadowsocks';
    return 'Clash.Meta';
  }

  static String _serverOf(Profile? p) {
    if (p == null) return '—';
    final RegExpMatch? host =
        RegExp(r'server:\s*([^\s]+)').firstMatch(p.rawYaml);
    if (host == null) return '—';
    final String hostValue = host.group(1)!.replaceAll('"', '');
    final RegExpMatch? port = RegExp(r'port:\s*(\d+)').firstMatch(p.rawYaml);
    return port == null ? hostValue : '$hostValue:${port.group(1)}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: <Widget>[
          Text(label, style: text.bodyMedium?.copyWith(color: context.colors.inkSecondary)),
          const Spacer(),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: context.colors.hairline);
  }
}

// ---------------------------------------------------------------------------
// 当前节点 + 启动 VPN
// ---------------------------------------------------------------------------

class _NodeAvatar extends StatelessWidget {
  const _NodeAvatar({required this.profile, this.size = 44});

  final Profile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String? path = profile.avatarPath;

    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.3),
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return ProfileAvatar(name: profile.name, size: size);
          },
        ),
      );
    }

    return ProfileAvatar(name: profile.name, size: size);
  }
}

class _NodeQuickCard extends StatelessWidget {
  const _NodeQuickCard({required this.controller, required this.onPick});

  final AppController controller;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final Profile? p = controller.activeProfile;
    final TunnelState state = controller.tunnelState;

    return LiquidGlassContainer(
      radius: 26,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPick,
            child: Row(
              children: <Widget>[
                if (p != null)
                  _NodeAvatar(profile: p, size: 46)
                else
                  Icon(Icons.layers_rounded, color: colors.inkTertiary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        p?.name ?? '未选择节点',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text('当前节点 · 点击切换', style: text.labelSmall),
                    ],
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 22,
                  color: colors.inkTertiary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _VpnButton(state: state, onTap: controller.toggleConnection),
        ],
      ),
    );
  }
}

class _VpnButton extends StatelessWidget {
  const _VpnButton({required this.state, required this.onTap});

  final TunnelState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final bool busy = state.isBusy;
    final bool connected = state.isConnected;

    final String label;
    if (state.phase == TunnelPhase.connecting) {
      label = '连接中…';
    } else if (state.phase == TunnelPhase.disconnecting) {
      label = '断开中…';
    } else if (connected) {
      label = '断开 VPN';
    } else {
      label = '启动 VPN';
    }

    final List<Color> gradient = busy
        ? <Color>[colors.surfaceMuted, colors.surfaceMuted]
        : connected
            ? <Color>[
                colors.danger.withOpacity(0.85),
                colors.danger.withOpacity(0.62),
              ]
            : <Color>[colors.accent, colors.accent.withOpacity(0.72)];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (connected ? colors.danger : colors.accent)
                  .withOpacity(busy ? 0.08 : 0.34),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (busy)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                  ),
                )
              else
                Icon(
                  connected
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_fill_rounded,
                  size: 19,
                  color: Colors.white,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TideType.headline.copyWith(
                  color: Colors.white,
                  letterSpacing: 0.3,
                  shadows: glassTextShadow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
