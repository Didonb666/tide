import 'package:flutter/foundation.dart';

enum ProfileSource { paste, file, url }

enum LogVerdict { proxied, direct, rejected }

@immutable
class GroupInfo {
  const GroupInfo({
    required this.name,
    required this.kind,
    required this.now,
    required this.nodes,
  });

  final String name;
  final String kind;
  final String now;
  final List<String> nodes;
}

@immutable
class ProviderInfo {
  const ProviderInfo({
    required this.name,
    required this.behavior,
    required this.count,
    required this.updatedAt,
  });

  final String name;
  final String behavior;
  final int count;
  final DateTime updatedAt;
}

@immutable
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.source,
    this.rawYaml = '',
    this.avatarPath,
    required this.ruleCount,
    required this.updatedAt,
    required this.groupSummary,
    required this.groups,
    required this.rules,
    required this.providers,
    this.valid = true,
  });

  final String id;
  final String name;
  final ProfileSource source;
  final String rawYaml;

  /// 用户自定义的节点头像（本地文件绝对路径），为空时回落到默认头像图。
  final String? avatarPath;

  final int ruleCount;
  final DateTime updatedAt;
  final String groupSummary;
  final List<GroupInfo> groups;
  final List<String> rules;
  final List<ProviderInfo> providers;
  final bool valid;

  String get sourceLabel {
    switch (source) {
      case ProfileSource.paste:
        return '粘贴';
      case ProfileSource.file:
        return '文件';
      case ProfileSource.url:
        return '订阅';
    }
  }

  Profile copyWith({
    String? name,
    String? rawYaml,
    String? avatarPath,
    int? ruleCount,
    DateTime? updatedAt,
    String? groupSummary,
    List<GroupInfo>? groups,
    List<String>? rules,
    List<ProviderInfo>? providers,
    bool? valid,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      source: source,
      rawYaml: rawYaml ?? this.rawYaml,
      avatarPath: avatarPath ?? this.avatarPath,
      ruleCount: ruleCount ?? this.ruleCount,
      updatedAt: updatedAt ?? this.updatedAt,
      groupSummary: groupSummary ?? this.groupSummary,
      groups: groups ?? this.groups,
      rules: rules ?? this.rules,
      providers: providers ?? this.providers,
      valid: valid ?? this.valid,
    );
  }
}

@immutable
class LogEntry {
  const LogEntry({
    required this.id,
    required this.host,
    required this.outbound,
    required this.rule,
    required this.bytes,
    required this.time,
    required this.verdict,
  });

  final int id;
  final String host;
  final String outbound;
  final String rule;
  final int bytes;
  final DateTime time;
  final LogVerdict verdict;
}

int estimateRuleCount(String yaml) {
  var count = 0;
  var inRules = false;

  for (final String raw in yaml.split('\n')) {
    final String line = raw.replaceAll('\r', '');
    final String trimmed = line.trimLeft();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    final bool topLevel = !line.startsWith(' ') && !line.startsWith('\t');
    if (topLevel) {
      inRules = trimmed.startsWith('rules:');
      if (inRules && trimmed.contains('[')) {
        count += ','.allMatches(trimmed).length + 1;
      }
      continue;
    }

    if (inRules && trimmed.startsWith('- ')) count += 1;
  }

  return count;
}

const String kBuiltinVlessConfig = '''
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
ipv6: true
find-process-mode: off

dns:
  enable: true
  ipv6: false
  enhanced-mode: normal
  nameserver:
    - 223.5.5.5
    - 119.29.29.29

proxies:
  - name: "Geto-Reality-61494"
    type: vless
    server: 64.83.14.86
    port: 61494
    uuid: efc6fdd0-8f7f-48f1-b5c5-88034df99aac
    network: tcp
    udp: true
    tls: true
    flow: xtls-rprx-vision
    servername: www.samsung.com
    client-fingerprint: chrome
    reality-opts:
      public-key: SU7pSsRZGubzrFFmEFwFAeWfQfirjwJnaN5JXPrl_Us
      short-id: 56281cd5

proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - "Geto-Reality-61494"

rules:
  - MATCH,PROXY
''';

List<Profile> buildMockProfiles() {
  final DateTime now = DateTime.now();

  return <Profile>[
    Profile(
      id: 'p-builtin',
      name: '内置专线',
      source: ProfileSource.paste,
      rawYaml: kBuiltinVlessConfig,
      ruleCount: 1,
      updatedAt: now,
      groupSummary: 'PROXY · Geto-Reality-61494',
      groups: const <GroupInfo>[
        GroupInfo(
          name: 'PROXY',
          kind: 'select',
          now: 'Geto-Reality-61494',
          nodes: <String>['Geto-Reality-61494'],
        ),
      ],
      rules: const <String>['MATCH,PROXY'],
      providers: const <ProviderInfo>[],
    ),
  ];
}
