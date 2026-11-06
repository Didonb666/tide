import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/settings_controller.dart';
import '../design/tokens.dart';
import 'liquid_glass_container.dart';

@immutable
class LiquidNavItem {
  const LiquidNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class LiquidNavBar extends StatefulWidget {
  const LiquidNavBar({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onTap;
  final List<LiquidNavItem> items;

  @override
  State<LiquidNavBar> createState() => _LiquidNavBarState();
}

class _LiquidNavBarState extends State<LiquidNavBar> {
  double _dx = 0;
  bool _dragging = false;

  int _indexAt(double itemWidth) {
    final int n = widget.items.length;
    if (n == 0) return 0;
    final double baseWidth = itemWidth - 12;
    final double center = widget.index * itemWidth + 6 + baseWidth / 2 + _dx;
    return (center / itemWidth).round().clamp(0, n - 1);
  }

  void _move(double totalDx, double itemWidth) {
    final int n = widget.items.length;
    final double maxRight = (n - 1 - widget.index) * itemWidth;
    final double maxLeft = widget.index * itemWidth;
    final double clamped = totalDx.clamp(-maxLeft, maxRight);

    if (clamped == _dx) return;

    final int before = _indexAt(itemWidth);
    setState(() => _dx = clamped);
    if (_indexAt(itemWidth) != before) HapticFeedback.selectionClick();
  }

  void _endDrag(double itemWidth) {
    final int target = _indexAt(itemWidth);
    setState(() {
      _dragging = false;
      _dx = 0;
    });

    if (target != widget.index) {
      HapticFeedback.selectionClick();
      widget.onTap(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final SettingsController? settings = SettingsScope.maybeOf(context);
    final double bottom = (settings?.navBottomOffset ?? 16).clamp(0.0, 48.0);
    final double inset = (settings?.navSideInset ?? 20).clamp(8.0, 40.0);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(inset, 0, inset, bottom),
        child: LiquidGlassContainer(
          radius: 36,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 72,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double itemWidth =
                    constraints.maxWidth / widget.items.length;
                final double baseWidth = itemWidth - 12;
                final double stretch = (_dx.abs() / itemWidth).clamp(0.0, 1.0);
                final double pillWidth = baseWidth * (1 + 0.55 * stretch);
                final double center =
                    widget.index * itemWidth + 6 + baseWidth / 2 + _dx;
                final double pillLeft = center - pillWidth / 2;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPressStart: (LongPressStartDetails details) {
                    HapticFeedback.mediumImpact();
                    setState(() => _dragging = true);
                  },
                  onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
                    _move(details.offsetFromOrigin.dx, itemWidth);
                  },
                  onLongPressEnd: (LongPressEndDetails details) =>
                      _endDrag(itemWidth),
                  onLongPressCancel: () {
                    if (!_dragging) return;
                    setState(() {
                      _dragging = false;
                      _dx = 0;
                    });
                  },
                  child: Stack(
                    children: <Widget>[
                      AnimatedPositioned(
                        duration: _dragging
                            ? Duration.zero
                            : const Duration(milliseconds: 520),
                        curve: Curves.elasticOut,
                        left: pillLeft,
                        top: 8 - 2 * stretch,
                        width: pillWidth,
                        height: 56 + 4 * stretch,
                        child: RepaintBoundary(
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..scale(1.0, 1 - 0.10 * stretch)
                              ..skewX(_dx / itemWidth * 0.06),
                            child: _GlassPill(dragging: _dragging),
                          ),
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          for (int i = 0; i < widget.items.length; i++)
                            Expanded(
                              child: _NavTab(
                                item: widget.items[i],
                                selected: i == widget.index,
                                accent: colors.accent,
                                onTap: () => widget.onTap(i),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.dragging});

  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0x8CFFFFFF),
            dragging ? const Color(0x33FFFFFF) : const Color(0x1AFFFFFF),
            const Color(0x33000000),
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              dragging ? const Color(0x40FFFFFF) : const Color(0x2EFFFFFF),
              const Color(0x0DFFFFFF),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final LiquidNavItem item;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final Color fg = selected
        ? accent
        : (dark ? Colors.white60 : const Color(0xFF5A6B7B));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AnimatedScale(
            scale: selected ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: Icon(
              selected ? item.activeIcon : item.icon,
              size: 22,
              color: fg,
              shadows: glassTextShadow,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TideType.caption.copyWith(
              color: fg,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              shadows: glassTextShadow,
            ),
          ),
        ],
      ),
    );
  }
}
