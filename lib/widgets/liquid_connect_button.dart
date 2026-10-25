import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'liquid_glass_container.dart';

/// 液态玻璃连接按钮：未连接呼吸微光，连接后主题色流光 + 点击涟漪。
class LiquidConnectButton extends StatefulWidget {
  const LiquidConnectButton({
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
  State<LiquidConnectButton> createState() => _LiquidConnectButtonState();
}

class _LiquidConnectButtonState extends State<LiquidConnectButton>
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
  void didUpdateWidget(covariant LiquidConnectButton oldWidget) {
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

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_breath, _flow]),
      builder: (BuildContext context, Widget? child) {
        final double breath = Curves.easeInOut.transform(_breath.value);
        final double flow = _flow.value;

        final List<Color> fill;
        final Color glow;
        final double glowOpacity;
        final double glowBlur;

        if (widget.busy) {
          fill = <Color>[const Color(0x33000000), const Color(0x1A000000)];
          glow = colors.inkTertiary;
          glowOpacity = 0.06;
          glowBlur = 8;
        } else if (widget.connected) {
          fill = <Color>[
            colors.accent.withOpacity(0.72),
            colors.info.withOpacity(0.48),
            colors.accent.withOpacity(0.72),
          ];
          glow = colors.accent;
          glowOpacity = 0.42;
          glowBlur = 28;
        } else {
          fill = <Color>[const Color(0x73000000), const Color(0x3D000000)];
          glow = colors.accent;
          glowOpacity = 0.14 + 0.18 * breath;
          glowBlur = 12 + 14 * breath;
        }

        return GestureDetector(
          onTapDown: widget.busy
              ? null
              : (_) {
                  setState(() => _down = true);
                  _spawnRipple();
                },
          onTapCancel:
              widget.busy ? null : () => setState(() => _down = false),
          onTapUp: widget.busy ? null : (_) => setState(() => _down = false),
          onTap: widget.busy ? null : widget.onTap,
          child: AnimatedScale(
            scale: _down ? 0.97 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: glow.withOpacity(glowOpacity),
                    blurRadius: glowBlur,
                    spreadRadius: widget.connected ? 1.5 : 0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: const ColorFilter.mode(
                    Colors.transparent,
                    BlendMode.srcOver,
                  ).let(),
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0x8CFFFFFF),
                          Color(0x14FFFFFF),
                          Color(0x33000000),
                        ],
                        stops: <double>[0.0, 0.5, 1.0],
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19),
                        gradient: LinearGradient(
                          begin: Alignment(-2 + 4 * flow, -0.6),
                          end: Alignment(2 + 4 * flow, 0.6),
                          colors: fill,
                          stops: fill.length == 3
                              ? const <double>[0.0, 0.5, 1.0]
                              : null,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
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
                                        scale: 0.5 + t * 1.6,
                                        child: Container(
                                          width: 110,
                                          height: 110,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white
                                                  .withOpacity(0.6),
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
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.white70,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          widget.label,
                                          style: TideType.headline.copyWith(
                                            color: Colors.white70,
                                            shadows: glassTextShadow,
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
                                          shadows: glassTextShadow,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          widget.label,
                                          style: TideType.headline.copyWith(
                                            color: Colors.white,
                                            letterSpacing: 0.3,
                                            shadows: glassTextShadow,
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
