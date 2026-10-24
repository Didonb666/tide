import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/profile.dart';
import '../core/tunnel/tunnel_state.dart';
import '../design/tokens.dart';

// ---------------------------------------------------------------------------
// 格式化
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// 基础元素
// ---------------------------------------------------------------------------

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
            child: Text(title, style: Theme.of(context).textTheme.labelMedium),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class PresenceDot extends StatefulWidget {
  const PresenceDot({super.key, required this.phase, this.size = 8});

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
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: dot.withOpacity(0.55),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
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
        color: colors.surfaceMuted.withOpacity(0.8),
        borderRadius: BorderRadius.circular(TideRadii.full),
        border: Border.all(color: colors.hairline),
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
          colors: <Color>[base.withOpacity(0.95), base.withOpacity(0.58)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: base.withOpacity(0.35),
            blurRadius: 14,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
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
        color: fg.withOpacity(0.14),
        borderRadius: BorderRadius.circular(TideRadii.xs),
        border: Border.all(color: fg.withOpacity(0.25)),
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
        const SizedBox(height: 3),
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

// ---------------------------------------------------------------------------
// 数字滚动
// ---------------------------------------------------------------------------

class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
  });

  final int value;
  final String Function(int) formatter;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final TextStyle effective = style ??
        TideType.mono.copyWith(color: context.colors.ink);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double v, Widget? child) {
        return Text(
          formatter(v.round()),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: effective,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 玻璃导航栏
// ---------------------------------------------------------------------------

@immutable
class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onTap;
  final List<GlassNavItem> items;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: TideBlur.nav, sigmaY: TideBlur.nav),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface.withOpacity(0.72),
            border: Border(
              top: BorderSide(color: colors.hairline.withOpacity(0.65)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: TideSpace.navBar,
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavButton(
                        item: items[i],
                        selected: i == index,
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final Color fg = selected ? colors.accent : colors.inkTertiary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: TideMotion.standard,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color:
                  selected ? colors.accent.withOpacity(0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(TideRadii.full),
            ),
            child: Icon(
              selected ? item.activeIcon : item.icon,
              size: 22,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TideType.caption.copyWith(
              color: fg,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 动画辅助
// ---------------------------------------------------------------------------

class StaggeredFadeIn extends StatefulWidget {
  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.slide = 0.08,
  });

  final int index;
  final Widget child;
  final double slide;

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TideMotion.stagger,
  );

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final bool reduce = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;

    if (reduce) {
      _controller.value = 1;
      return;
    }

    final int delayMs = TideMotion.staggerStepMs * widget.index;
    if (delayMs <= 0) {
      _controller.forward();
    } else {
      _timer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, widget.slide),
          end: Offset.zero,
        ).animate(curved),
        child: widget.child,
      ),
    );
  }
}

class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setDown(true),
      onTapCancel: () => _setDown(false),
      onTapUp: (_) => _setDown(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 3D 倾斜卡片：随手指/鼠标位置倾斜，并带高光扫过。
class TiltCard extends StatefulWidget {
  const TiltCard({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.radius = 24,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final double radius;

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> {
  Matrix4 _matrix = Matrix4.identity();
  Offset _pointer = Offset.zero;
  bool _pressed = false;

  void _update(Offset local, Size size) {
    if (size.isEmpty) return;
    final double dx = (local.dx / size.width) * 2 - 1;
    final double dy = (local.dy / size.height) * 2 - 1;
    setState(() {
      _pointer = Offset(dx, dy);
      _pressed = true;
      _matrix = Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateX(-dy * 0.10)
        ..rotateY(dx * 0.10)
        ..scale(_pressed ? 0.985 : 1.0);
    });
  }

  void _reset() {
    if (!_pressed && _pointer == Offset.zero) return;
    setState(() {
      _pressed = false;
      _pointer = Offset.zero;
      _matrix = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) => _update(d.localPosition, size),
          onPanUpdate: (DragUpdateDetails d) => _update(d.localPosition, size),
          onTapCancel: _reset,
          onTapUp: (TapUpDetails d) {
            widget.onTap();
            _reset();
          },
          onLongPress: widget.onLongPress,
          child: Transform(
            alignment: Alignment.center,
            transform: _matrix,
            child: Stack(
              children: <Widget>[
                widget.child,
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.radius),
                        gradient: _pointer == Offset.zero
                            ? null
                            : LinearGradient(
                                begin: Alignment(-_pointer.dx, -_pointer.dy),
                                end: Alignment(_pointer.dx, _pointer.dy),
                                colors: <Color>[
                                  Colors.white.withOpacity(0.12),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.05),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 配置卡片
// ---------------------------------------------------------------------------

class ProfileStreamTile extends StatelessWidget {
  const ProfileStreamTile({
    super.key,
    required this.profile,
    required this.active,
    required this.onTap,
    this.heroTag,
    this.index = 0,
    this.onLongPress,
  });

  final Profile profile;
  final bool active;
  final VoidCallback onTap;
  final String? heroTag;
  final int index;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final bool dark = context.isDark;

    return StaggeredFadeIn(
      index: index,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TideSpace.page,
          vertical: TideSpace.x1 + 1,
        ),
        child: TiltCard(
          radius: 24,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(TideSpace.x3 + 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.hairline),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  colors.surface,
                  Color.alphaBlend(
                    colors.accent.withOpacity(0.04),
                    colors.surface,
                  ),
                ],
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withOpacity(dark ? 0.42 : 0.06),
                  blurRadius: 22,
                  spreadRadius: -10,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Hero(
                  tag: heroTag ?? 'avatar-${profile.id}',
                  child: ProfileAvatar(name: profile.name, size: 44),
                ),
                const SizedBox(width: TideSpace.x3),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(height: 3),
                      Text(
                        '${relativeTime(profile.updatedAt)} · ${profile.ruleCount} 条规则 · ${profile.groupSummary}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: TideSpace.x1),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: colors.inkTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 呼吸 / 流光 / 波纹 连接按钮
// ---------------------------------------------------------------------------

class ConnectButton extends StatefulWidget {
  const ConnectButton({
    super.key,
    required this.connected,
    required this.busy,
    required this.label,
    required this.onTap,
  });

  final bool connected;
  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: TideMotion.pulse,
  );
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: TideMotion.flow,
  );

  final List<AnimationController> _ripples = <AnimationController>[];
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ConnectButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connected != widget.connected ||
        oldWidget.busy != widget.busy) {
      _sync();
    }
  }

  void _sync() {
    if (widget.busy) {
      _breath.stop();
      _flow.stop();
      return;
    }
    if (widget.connected) {
      _breath.stop();
      if (!_flow.isAnimating) _flow.repeat();
    } else {
      _flow.stop();
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    }
  }

  void _spawnRipple() {
    final AnimationController ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    ripple.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _ripples.remove(ripple));
        ripple.dispose();
      }
    });
    setState(() => _ripples.add(ripple));
    ripple.forward();
  }

  @override
  void dispose() {
    _breath.dispose();
    _flow.dispose();
    for (final AnimationController ripple in _ripples) {
      ripple.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final bool dark = context.isDark;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_breath, _flow]),
      builder: (BuildContext context, Widget? child) {
        final double breath = Curves.easeInOut.transform(_breath.value);
        final double flow = _flow.value;

        final LinearGradient gradient;
        final Color glowColor;
        final double glowOpacity;
        final double glowBlur;

        if (widget.connected) {
          gradient = LinearGradient(
            begin: Alignment(-2 + 4 * flow, -0.6),
            end: Alignment(2 + 4 * flow, 0.6),
            colors: <Color>[colors.accent, colors.info, colors.accent],
            stops: const <double>[0.0, 0.5, 1.0],
          );
          glowColor = colors.info;
          glowOpacity = 0.34;
          glowBlur = 26;
        } else if (widget.busy) {
          gradient = LinearGradient(
            colors: <Color>[colors.surfaceMuted, colors.surfaceMuted],
          );
          glowColor = colors.inkTertiary;
          glowOpacity = 0.08;
          glowBlur = 10;
        } else {
          gradient = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[colors.accent, colors.accent.withOpacity(0.82)],
          );
          glowColor = colors.accent;
          glowOpacity = 0.18 + 0.16 * breath;
          glowBlur = 14 + 12 * breath;
        }

        return GestureDetector(
          onTapDown: widget.busy
              ? null
              : (_) {
                  setState(() => _down = true);
                  _spawnRipple();
                },
          onTapCancel: widget.busy ? null : () => setState(() => _down = false),
          onTapUp: widget.busy ? null : (_) => setState(() => _down = false),
          onTap: widget.busy ? null : widget.onTap,
          child: AnimatedScale(
            scale: _down ? 0.97 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TideRadii.lg + 2),
                gradient: gradient,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: glowColor.withOpacity(
                      dark ? glowOpacity : glowOpacity * 0.75,
                    ),
                    blurRadius: glowBlur,
                    spreadRadius: widget.connected ? 1.5 : 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(TideRadii.lg + 2),
                child: Stack(
                  children: <Widget>[
                    for (final AnimationController ripple in _ripples)
                      AnimatedBuilder(
                        animation: ripple,
                        builder: (BuildContext context, Widget? child) {
                          final double t = Curves.easeOut.transform(
                            ripple.value,
                          );
                          return Center(
                            child: Opacity(
                              opacity: 1 - t,
                              child: Transform.scale(
                                scale: 0.5 + t * 1.5,
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.65),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    Center(
                      child: widget.busy
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colors.inkSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  widget.label,
                                  style: TideType.headline.copyWith(
                                    color: colors.inkSecondary,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  widget.connected
                                      ? Icons.power_settings_new_rounded
                                      : Icons.bolt_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.label,
                                  style: TideType.headline.copyWith(
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
