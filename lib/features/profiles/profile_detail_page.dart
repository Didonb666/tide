import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/profile.dart';
import '../../design/tokens.dart';
import '../../widgets/common.dart';

class ProfileDetailPage extends StatelessWidget {
  const ProfileDetailPage({
    super.key,
    required this.profile,
    this.heroTag,
  });

  final Profile profile;

  /// 必须与来源页面的 Hero tag 完全一致，共享元素才会飞起来。
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('配置详情'),
        ),
        body: Column(
          children: <Widget>[
            _DetailHeader(profile: profile, heroTag: heroTag),
            Container(
              color: colors.surface,
              child: TabBar(
                labelColor: colors.accent,
                unselectedLabelColor: colors.inkSecondary,
                indicatorColor: colors.accent,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: colors.hairline,
                tabs: const <Widget>[
                  Tab(text: '策略组'),
                  Tab(text: '规则'),
                  Tab(text: '规则集'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _GroupsTab(profile: profile),
                  _RulesTab(profile: profile),
                  _ProvidersTab(profile: profile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 详情页头像：与列表、首页一致，优先读 avatarPath。
class _DetailAvatar extends StatelessWidget {
  const _DetailAvatar({required this.profile, this.size = 64});

  final Profile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String? path = profile.avatarPath;

    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipOval(
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

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.profile, this.heroTag});

  final Profile profile;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TideSpace.page,
        TideSpace.x2,
        TideSpace.page,
        TideSpace.x4,
      ),
      child: Row(
        children: <Widget>[
          Hero(
            tag: heroTag ?? 'avatar-${profile.id}',
            child: _DetailAvatar(profile: profile, size: 64),
          ),
          const SizedBox(width: TideSpace.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile.sourceLabel} · ${profile.ruleCount} 条规则 · ${relativeTime(profile.updatedAt)}',
                  style: text.bodySmall,
                ),
                if (!profile.valid) ...<Widget>[
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Icon(Icons.error_outline, size: 14, color: colors.danger),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '校验未通过：${profile.groupSummary}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(color: colors.danger),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (profile.groups.isEmpty) {
      return const _EmptyTab(
        icon: Icons.hub_outlined,
        title: '还没有策略组数据',
        subtitle: '接入内核后，这里会从 GET /proxies 读取真实的组与当前选中节点。',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: TideSpace.x2),
      itemCount: profile.groups.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Hairline(inset: TideSpace.page),
      itemBuilder: (BuildContext context, int index) {
        final GroupInfo group = profile.groups[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: TideSpace.page),
          title: Text(group.name, style: text.titleMedium),
          subtitle: Text(
            '${group.kind} · ${group.nodes.length} 个节点',
            style: text.bodySmall,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                group.now,
                style: text.bodySmall?.copyWith(color: context.colors.accent),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.colors.inkTertiary,
              ),
            ],
          ),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('演示模式：接入内核后才能切换「${group.name}」的节点')),
            );
          },
        );
      },
    );
  }
}

class _RulesTab extends StatelessWidget {
  const _RulesTab({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (profile.rules.isEmpty) {
      return const _EmptyTab(
        icon: Icons.rule_folder_outlined,
        title: '还没有解析出的规则',
        subtitle: '导入的原文已保存。接入内核后，这里会按 index 展示 GET /rules 的顺序。',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: TideSpace.x2),
      itemCount: profile.rules.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Hairline(inset: TideSpace.x4 + 28),
      itemBuilder: (BuildContext context, int index) {
        final String rule = profile.rules[index];
        final int comma = rule.indexOf(',');
        final String type = comma < 0 ? rule : rule.substring(0, comma);
        final String rest = comma < 0 ? '' : rule.substring(comma + 1);

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TideSpace.page,
            vertical: TideSpace.x3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 28,
                child: Text(
                  '${index + 1}',
                  style: TideType.mono.copyWith(color: context.colors.inkTertiary),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        TideBadge(text: type, color: context.colors.info),
                        const SizedBox(width: 6),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(rest, style: TideType.mono),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProvidersTab extends StatelessWidget {
  const _ProvidersTab({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (profile.providers.isEmpty) {
      return const _EmptyTab(
        icon: Icons.cloud_download_outlined,
        title: '还没有规则集',
        subtitle: '接入内核后，这里会展示每个 rule-provider 的条目数与最后更新时间。',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: TideSpace.x2),
      itemCount: profile.providers.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Hairline(inset: TideSpace.page),
      itemBuilder: (BuildContext context, int index) {
        final ProviderInfo p = profile.providers[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: TideSpace.page),
          title: Text(p.name, style: text.titleMedium),
          subtitle: Text(
            '${p.behavior} · ${p.count} 条 · ${relativeTime(p.updatedAt)}更新',
            style: text.bodySmall,
          ),
          trailing:
              Icon(Icons.refresh, size: 18, color: context.colors.inkTertiary),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('演示模式：真实更新会调用 PUT /providers/rules/${p.name}')),
            );
          },
        );
      },
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: colors.inkTertiary),
            const SizedBox(height: TideSpace.x3),
            Text(title, style: text.titleMedium),
            const SizedBox(height: TideSpace.x2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
