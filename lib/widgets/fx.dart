import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/profile.dart';
import '../design/tokens.dart';
import 'common.dart';

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
    final TextStyle effective =
        style ?? TideType.mono.copyWith(color: context.colors.ink);

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
        ..scale(0.985);
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

class ConnectButtonFx extends StatefulWidget {
  const ConnectButtonFx({
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
  State<ConnectButtonFx> createState() => _ConnectButtonFxState();
}

class _ConnectButtonFxState extends State<ConnectButtonFx>
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
  void didUpdateWidget(covariant ConnectButtonFx oldWidget) {
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
                          final double t =
                              Curves.easeOut.transform(ripple.value);
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

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.profile,
    required this.active,
    required this.onTap,
    required this.onAvatarTap,
    this.heroTag,
    this.index = 0,
    this.onLongPress,
  });

  final Profile profile;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onAvatarTap;
  final String? heroTag;
  final int index;
  final VoidCallback? onLongPress;

  Widget _avatar(BuildContext context) {
    final String? path = profile.avatarPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipOval(
        child: Image.file(
          File(path),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
            return ProfileAvatar(name: profile.name, size: 44);
          },
        ),
      );
    }
    return ProfileAvatar(name: profile.name, size: 44);
  }

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
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Hero(
                    tag: heroTag ?? 'avatar-${profile.id}',
                    child: _avatar(context),
                  ),
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
