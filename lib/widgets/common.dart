import 'package:flutter/material.dart';

import '../core/profile.dart';
import '../core/tunnel/tunnel_state.dart';
import '../design/tokens.dart';

/// 26 字节/秒 -> "1.2 MB/s"
String formatRate(int bytesPerSecond) {
  if (bytesPerSecond <= 0) return '—';
  const List<String> units = <String>['B/s', 'KB/s', 'MB/s', 'GB/s'];
  double value = bytesPerSecond.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}

String relativeTime(DateTime time) {
  final Duration delta = DateTime.now().difference(time);
  if (delta.inSeconds < 60) return '刚刚';
  if (delta.inMinutes < 60) return '${delta.inMinutes} 分钟前';
  if (delta.inHours < 24) return '${delta.inHours} 小时前';
  return '${delta.inDays} 天前';
}

/// 1px 分隔线，左缩进对齐头像右侧。
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.inset = TideSpace.dividerInset});

  final double inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: inset),
      child: Container(height: 1, color: context.colors.hairline),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TideSpace.page,
        TideSpace.x5,
        TideSpace.page,
        TideSpace.x2,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 状态点：根据 phase 取语义色；忙碌时低频脉冲（受"减少动态效果"控制）。
class PresenceDot extends StatefulWidget {
  const PresenceDot({
    super.key,
    required this.phase,
    this.size = 8,
  });

  final TunnelPhase phase;
  final double size;

  @override
  State<PresenceDot> createState() => _PresenceDotState();
}

class _PresenceDotState extends State<PresenceDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TideMotion.pulse,
  );

  bool get _pulsing =>
      !context.reduceMotion &&
      (widget.phase == TunnelPhase.connecting ||
          widget.phase == TunnelPhase.disconnecting ||
          widget.phase == TunnelPhase.connected);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pulsing) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant PresenceDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) didChangeDependencies();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final Color dot = colors.status(
      connected: widget.phase == TunnelPhase.connected,
      busy: widget.phase == TunnelPhase.connecting ||
          widget.phase == TunnelPhase.disconnecting,
      failed: widget.phase == TunnelPhase.failed,
    );

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size * 1.8,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              final double t = _controller.value;
              return Opacity(
                opacity: 0.6 + 0.4 * t,
                child: Transform.scale(
                  scale: 1 + 0.1 * t,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.phase});

  final TunnelPhase phase;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final bool failed = phase == TunnelPhase.failed;
    final bool connected = phase == TunnelPhase.connected;
    final bool busy =
        phase == TunnelPhase.connecting || phase == TunnelPhase.disconnecting;

    final Color fg = colors.status(
      connected: connected,
      busy: busy,
      failed: failed,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(TideRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PresenceDot(phase: phase, size: 7),
          const SizedBox(width: 6),
          Text(
            _label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String get _label {
    switch (phase) {
      case TunnelPhase.idle:
        return '未连接';
      case TunnelPhase.connecting:
        return '连接中';
      case TunnelPhase.connected:
        return '已连接';
      case TunnelPhase.disconnecting:
        return '断开中';
      case TunnelPhase.failed:
        return '失败';
    }
  }
}

/// 圆形头像。用名字派生渐变色，避免为每个配置配图。
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.name, this.size = 46});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final int hash = name.runes.fold<int>(0, (int sum, int rune) => sum + rune);
    final List<Color> palette = <Color>[
      colors.accent,
      colors.info,
      colors.warning,
      colors.success,
    ];
    final Color base = palette[hash % palette.length];

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            base.withOpacity(0.95),
            base.withOpacity(0.62),
          ],
        ),
      ),
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class TideBadge extends StatelessWidget {
  const TideBadge({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final Color fg = color ?? colors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(TideRadii.xs),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 会话流中的一行。点击进入详情（头像做共享元素过渡）。
class ProfileStreamTile extends StatelessWidget {
  const ProfileStreamTile({
    super.key,
    required this.profile,
    required this.active,
    required this.onTap,
    this.heroTag,
  });

  final Profile profile;
  final bool active;
  final VoidCallback onTap;

  /// 共享元素 tag。**每个页面必须传不同的前缀**，否则两个页面同时存在于树上时
  /// （例如底部导航切换的 200ms 内）会出现 "multiple heroes share the same tag"。
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: TideSpace.row,
        child: Row(
          children: <Widget>[
            const SizedBox(width: TideSpace.page),
            Hero(
              tag: heroTag ?? 'avatar-${profile.id}',
              child: ProfileAvatar(name: profile.name, size: TideSpace.avatar),
            ),
            const SizedBox(width: TideSpace.x3),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          profile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium,
                        ),
                      ),
                      if (active) ...<Widget>[
                        const SizedBox(width: 6),
                        const TideBadge(text: '当前'),
                      ],
                      if (!profile.valid) ...<Widget>[
                        const SizedBox(width: 6),
                        TideBadge(text: '校验失败', color: colors.danger),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${relativeTime(profile.updatedAt)} · ${profile.ruleCount} 条规则 · ${profile.groupSummary}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.inkTertiary),
            const SizedBox(width: TideSpace.x3),
          ],
        ),
      ),
    );
  }
}

class StatCell extends StatelessWidget {
  const StatCell({
    super.key,
    required this.label,
    required this.value,
    this.mono = true,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: text.labelSmall),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: mono
              ? TideType.mono.copyWith(color: context.colors.ink)
              : text.titleSmall,
        ),
      ],
    );
  }
}
