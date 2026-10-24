import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/app_scope.dart';
import '../../core/page_transitions.dart';
import '../../core/profile.dart';
import '../../core/tunnel/tunnel_state.dart';
import '../../design/tokens.dart';
import '../../widgets/common.dart';
import '../profiles/profile_detail_page.dart';

class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _Header(state: c.tunnelState)),
          SliverToBoxAdapter(
            child: _HeroCard(controller: c, profile: c.activeProfile),
          ),
          const SliverToBoxAdapter(child: SectionHeader(title: '全部配置')),
          if (c.profiles.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('还没有配置，去「配置」页导入')),
              ),
            )
          else
            SliverList.builder(
              itemCount: c.profiles.length,
              itemBuilder: (BuildContext context, int index) {
                final Profile p = c.profiles[index];
                return ProfileStreamTile(
                  profile: p,
                  index: index,
                  active: p.id == c.activeProfileId,
                  heroTag: 'hero-connect-${p.id}',
                  onTap: () => _openDetail(context, p),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, Profile profile) {
    Navigator.of(context).push<void>(
      tideRoute<void>(
        ProfileDetailPage(
          profile: profile,
          heroTag: 'hero-connect-${profile.id}',
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final TunnelState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TideSpace.page,
        TideSpace.x2,
        TideSpace.page,
        TideSpace.x1,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text('连接', style: Theme.of(context).textTheme.displaySmall),
          ),
          StatusPill(phase: state.phase),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.controller, required this.profile});

  final AppController controller;
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final bool dark = context.isDark;
    final TunnelState state = controller.tunnelState;
    final Profile? p = profile;
    final String? message = state.message;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        TideSpace.page,
        TideSpace.x2,
        TideSpace.page,
        TideSpace.x1,
      ),
      padding: const EdgeInsets.all(TideSpace.x4 + 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TideRadii.xl + 2),
        border: Border.all(color: colors.hairline),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.surface,
            Color.alphaBlend(colors.accent.withOpacity(0.06), colors.surface),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.40 : 0.07),
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (p != null)
                ProfileAvatar(name: p.name, size: 54)
              else
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surfaceMuted,
                  ),
                  child: Icon(Icons.layers_rounded, color: colors.inkTertiary),
                ),
              const SizedBox(width: TideSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      p?.name ?? '尚未选择配置',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      p == null
                          ? '去「配置」页导入 Clash.Meta YAML'
                          : '${p.groupSummary} · ${p.ruleCount} 条规则',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TideSpace.x5),
          ConnectButton(
            connected: state.isConnected,
            busy: state.isBusy,
            label: _buttonLabel(state),
            onTap: controller.toggleConnection,
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: TideSpace.x3),
            Row(
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: colors.inkTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(message, style: text.labelSmall)),
              ],
            ),
          ],
          const SizedBox(height: TideSpace.x5),
          Row(
            children: <Widget>[
              Expanded(
                child: StatCell(
                  label: '下行',
                  value: formatRate(state.downBytesPerSec),
                ),
              ),
              Expanded(
                child: StatCell(
                  label: '上行',
                  value: formatRate(state.upBytesPerSec),
                ),
              ),
              Expanded(
                child: StatCell(label: '连接', value: '${state.connectionCount}'),
              ),
              Expanded(
                child: StatCell(label: '规则', value: '${p?.ruleCount ?? 0}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buttonLabel(TunnelState state) {
    switch (state.phase) {
      case TunnelPhase.idle:
        return '连接';
      case TunnelPhase.connecting:
        return '连接中…';
      case TunnelPhase.connected:
        return '断开连接';
      case TunnelPhase.disconnecting:
        return '正在断开…';
      case TunnelPhase.failed:
        return '重试';
    }
  }
}
