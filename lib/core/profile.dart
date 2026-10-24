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

  /// select / url-test / fallback / load-balance
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

  /// 用户导入的原始 Clash.Meta YAML（内置配置也放这里）。
  /// 连接时原样交给 mihomo 解析，不落盘、不改写。
  final String rawYaml;

  /// 规则条数。展示用；真实值由内核解析给出。
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

/// 粗略估算 YAML 里的规则条数，**仅用于导入后的 UI 反馈**。
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

/// 内置「专线」配置：VLESS + Reality。
///
/// 关键点：
///   - find-process-mode: off —— 避免内核读取 /data/system/packages.xml（无权限）；
///   - dns.enable: true —— TUN 的 DNS 劫持需要内核 DNS 模块开启，否则域名解析会失败；
///   - MATCH,PROXY —— 所有流量走这个节点，够用且可预测。
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
  - name: "内置节点-Geto"
    type: vless
    server: 154.201.90.47
    port: 17434
    uuid: bbf62abe-4bb2-4105-b08d-4df6a5b844fd
    network: tcp
    udp: true
    tls: true
    flow: xtls-rprx-vision
    servername: www.amd.com
    client-fingerprint: chrome
    reality-opts:
      public-key: XrSuwj3iTnXIdfLGKnM9dH00b2nvt64x8ZCUPouwzi0
      short-id: e47fc3fc

proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - "内置节点-Geto"

rules:
  - MATCH,PROXY
''';

/// 内置的"直连测试"配置：不经过任何代理，用来验证 TUN / DNS 是否工作。
const String kSampleDirectConfig = '''
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

proxies: []
proxy-groups: []

rules:
  - MATCH,DIRECT
''';

List<Profile> buildMockProfiles() {
  final DateTime now = DateTime.now();

  return <Profile>[
    // 第一个就是默认激活项（AppController 会把 profiles.first 设为当前配置）
    Profile(
      id: 'p-builtin',
      name: '内置专线',
      source: ProfileSource.paste,
      rawYaml: kBuiltinVlessConfig,
      ruleCount: 1,
      updatedAt: now,
      groupSummary: 'PROXY · 内置节点-Geto',
      groups: const <GroupInfo>[
        GroupInfo(
          name: 'PROXY',
          kind: 'select',
          now: '内置节点-Geto',
          nodes: <String>['内置节点-Geto'],
        ),
      ],
      rules: const <String>['MATCH,PROXY'],
      providers: const <ProviderInfo>[],
    ),
    Profile(
      id: 'p-direct',
      name: '直连测试（内置）',
      source: ProfileSource.paste,
      rawYaml: kSampleDirectConfig,
      ruleCount: 1,
      updatedAt: now,
      groupSummary: 'MATCH · DIRECT（用于验证内核是否跑通）',
      groups: const <GroupInfo>[],
      rules: const <String>['MATCH,DIRECT'],
      providers: const <ProviderInfo>[],
    ),
    Profile(
      id: 'p-main',
      name: '主订阅 · 机场 A',
      source: ProfileSource.url,
      ruleCount: 2481,
      updatedAt: now.subtract(const Duration(minutes: 3)),
      groupSummary: '自动选择 · 香港 01',
      groups: const <GroupInfo>[
        GroupInfo(
          name: '自动选择',
          kind: 'url-test',
          now: '香港 01',
          nodes: <String>['香港 01', '香港 02', '日本 01', '新加坡 01'],
        ),
        GroupInfo(
          name: '手动选择',
          kind: 'select',
          now: '日本 01',
          nodes: <String>['香港 01', '日本 01', '新加坡 01', 'DIRECT'],
        ),
        GroupInfo(
          name: '故障转移',
          kind: 'fallback',
          now: '香港 02',
          nodes: <String>['香港 02', '日本 01'],
        ),
      ],
      rules: const <String>[
        'DOMAIN-SUFFIX,google.com,自动选择',
        'DOMAIN-KEYWORD,github,自动选择',
        'RULE-SET,cn-domain,手动选择',
        'GEOIP,CN,DIRECT',
        'MATCH,自动选择',
      ],
      providers: <ProviderInfo>[
        ProviderInfo(
          name: 'cn-domain',
          behavior: 'domain',
          count: 8421,
          updatedAt: now.subtract(const Duration(hours: 6)),
        ),
        ProviderInfo(
          name: 'telegram',
          behavior: 'domain',
          count: 812,
          updatedAt: now.subtract(const Duration(hours: 2)),
        ),
        ProviderInfo(
          name: 'cn-ip',
          behavior: 'ipcidr',
          count: 1302,
          updatedAt: now.subtract(const Duration(days: 1)),
        ),
      ],
    ),
    Profile(
      id: 'p-work',
      name: '公司专线（本地文件）',
      source: ProfileSource.file,
      ruleCount: 913,
      updatedAt: now.subtract(const Duration(hours: 5)),
      groupSummary: '手动选择 · 新加坡 01',
      groups: const <GroupInfo>[
        GroupInfo(
          name: '手动选择',
          kind: 'select',
          now: '新加坡 01',
          nodes: <String>['新加坡 01', '香港 01', 'DIRECT'],
        ),
      ],
      rules: const <String>[
        'DOMAIN-SUFFIX,internal.example.com,DIRECT',
        'RULE-SET,cn-ip,DIRECT',
        'MATCH,手动选择',
      ],
      providers: <ProviderInfo>[
        ProviderInfo(
          name: 'cn-ip',
          behavior: 'ipcidr',
          count: 1302,
          updatedAt: now.subtract(const Duration(days: 2)),
        ),
      ],
    ),
    Profile(
      id: 'p-draft',
      name: '测试用 · 粘贴片段',
      source: ProfileSource.paste,
      ruleCount: 12,
      updatedAt: now.subtract(const Duration(days: 1)),
      groupSummary: '校验未通过：MATCH 不在最后一行',
      groups: const <GroupInfo>[],
      rules: const <String>[
        'MATCH,DIRECT',
        'DOMAIN-SUFFIX,example.com,自动选择',
      ],
      providers: const <ProviderInfo>[],
      valid: false,
    ),
  ];
}
