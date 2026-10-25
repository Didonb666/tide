import 'dart:io';

import 'package:flutter/material.dart';

import '../core/profile.dart';
import '../design/tokens.dart';
import 'common.dart';
import 'liquid_glass_container.dart';

class LiquidProfileCard extends StatelessWidget {
  const LiquidProfileCard({
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
          gaplessPlayback: true,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
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

    return StaggeredFadeIn(
      index: index,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TideSpace.page,
          vertical: 5,
        ),
        child: TiltCard(
          radius: 24,
          onTap: onTap,
          onLongPress: onLongPress,
          child: LiquidGlassContainer(
            radius: 24,
            sigma: 0,
            padding: const EdgeInsets.all(14),
            tint: active ? colors.accent : null,
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
