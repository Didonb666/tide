import 'package:flutter/material.dart';

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

/// 悬浮式液态玻璃导航栏：大圆角、独立滑动药丸、渐变反光。
class LiquidNavBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: LiquidGlassContainer(
          radius: 36,
          sigma: 18,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 72,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double itemWidth =
                    constraints.maxWidth / items.length;

                return Stack(
                  children: <Widget>[
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      left: index * itemWidth + 6,
                      top: 8,
                      width: itemWidth - 12,
                      height: 56,
                      child: const RepaintBoundary(
                        child: _GlassPill(),
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        for (int i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavTab(
                              item: items[i],
                              selected: i == index,
                              accent: colors.accent,
                              onTap: () => onTap(i),
                            ),
                          ),
                      ],
                    ),
                  ],
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
  const _GlassPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0x8CFFFFFF),
            Color(0x1AFFFFFF),
            Color(0x33000000),
          ],
          stops: <double>[0.0, 0.55, 1.0],
        ),
      ),
      padding: const EdgeInsets.all(1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(27),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0x2EFFFFFF),
              Color(0x0DFFFFFF),
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
