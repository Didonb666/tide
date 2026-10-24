// packages/clash_schema/lib/models.dart
//
// 纯 Dart（不依赖 Flutter），因此可以在 CLI / 单测 / 未来桌面端复用。
// 所有实体都实现 toJson/fromJson，字段名与文档 §3 一一对应。
//
// 设计原则：
//   1. 全部不可变（final + const 构造），UI 侧 diff 便宜；
//   2. DateTime 一律 UTC 存储、ISO-8601 序列化，展示层再做本地化；
//   3. 枚举显式带 wire 值，避免 enum.name 随重构漂移破坏持久化数据；
//   4. 未知字段容忍（fromJson 只取已知键），便于跨版本读取旧档案。

// ---------------------------------------------------------------------------
// 枚举
// ---------------------------------------------------------------------------

enum ProfileSource {
  paste('paste'),
  file('file'),
  url('url');

  const ProfileSource(this.wire);
  final String wire;

  static ProfileSource fromWire(String? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => ProfileSource.paste,
      );
}

enum ValidationSeverity {
  error('error'),
  warning('warning'),
  info('info');

  const ValidationSeverity(this.wire);
  final String wire;

  static ValidationSeverity fromWire(String? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => ValidationSeverity.info,
      );
}

enum RuleProviderType {
  http('http'),
  file('file'),
  inline('inline');

  const RuleProviderType(this.wire);
  final String wire;

  static RuleProviderType fromWire(String? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => RuleProviderType.http,
      );
}

enum RuleProviderBehavior {
  domain('domain'),
  ipcidr('ipcidr'),
  classical('classical');

  const RuleProviderBehavior(this.wire);
  final String wire;

  static RuleProviderBehavior fromWire(String? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => RuleProviderBehavior.domain,
      );
}

enum RuleProviderFormat {
  yaml('yaml'),
  text('text'),
  mrs('mrs');

  const RuleProviderFormat(this.wire);
  final String wire;

  static RuleProviderFormat fromWire(String? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => RuleProviderFormat.yaml,
      );
}

enum ProviderCacheState {
  absent('absent'),
  fresh('fresh'),
  stale('stale'),
  error('error');

  const ProviderCacheState(this.wire);
  final String wire;

  static ProviderCacheState fromWire(String? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => ProviderCacheState.absent,
      );
}

enum ProxyGroupKind {
  select('select'),
  urlTest('url-test'),
  fallback('fallback'),
  loadBalance('load-balance'),
  relay('relay'),
  unknown('unknown');

  const ProxyGroupKind(this.wire);
  final String wire;

  /// 内核 `/proxies` 返回的是 Go 侧的展示名（Selector / URLTest / ...）。
  static ProxyGroupKind fromKernel(String? type) {
    switch (type) {
      case 'Selector':
        return ProxyGroupKind.select;
      case 'URLTest':
        return ProxyGroupKind.urlTest;
      case 'Fallback':
        return ProxyGroupKind.fallback;
      case 'LoadBalance':
        return ProxyGroupKind.loadBalance;
      case 'Relay':
        return ProxyGroupKind.relay;
      default:
        return ProxyGroupKind.unknown;
    }
  }

  static ProxyGroupKind fromWire(String? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => ProxyGroupKind.unknown,
      );

  /// LoadBalance 没有 `now` 字段，UI 要显示"自动"。
  bool get hasSelection => this != ProxyGroupKind.loadBalance;
}

enum TraceVerdict {
  proxied('proxied'),
  direct('direct'),
  rejected('rejected'),
  unknown('unknown');

  const TraceVerdict(this.wire);
  final String wire;

  static TraceVerdict fromWire(String? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => TraceVerdict.unknown,
      );
}

/// 与文档 §6.1 状态机严格一致，顺序即生命周期顺序。
enum TunnelPhase {
  idle('idle'),
  requestingPermission('requesting_permission'),
  permissionDenied('permission_denied'),
  startingService('starting_service'),
  establishingTun('establishing_tun'),
  handingOffFd('handing_off_fd'),
  coreStarting('core_starting'),
  verifying('verifying'),
  connected('connected'),
  reconfiguring('reconfiguring'),
  stopping('stopping'),
  revoked('revoked'),
  failed('failed');

  const TunnelPhase(this.wire);
  final String wire;

  static TunnelPhase fromWire(String? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => TunnelPhase.idle,
      );

  bool get isBusy =>
      this == TunnelPhase.startingService ||
      this == TunnelPhase.establishingTun ||
      this == TunnelPhase.handingOffFd ||
      this == TunnelPhase.coreStarting ||
      this == TunnelPhase.verifying ||
      this == TunnelPhase.reconfiguring ||
      this == TunnelPhase.stopping;

  bool get isEngaged => this == TunnelPhase.connected || isBusy;
}

enum PrepareState {
  notRequested('not_requested'),
  granted('granted'),
  denied('denied'),
  unsupported('unsupported');

  const PrepareState(this.wire);
  final String wire;

  static PrepareState fromWire(String? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => PrepareState.notRequested,
      );
}

enum ServiceState {
  stopped('stopped'),
  starting('starting'),
  running('running'),
  foreground('foreground');

  const ServiceState(this.wire);
  final String wire;

  static ServiceState fromWire(String? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => ServiceState.stopped,
      );
}

enum TunFdState {
  none('none'),
  established('established'),
  handedOff('handed_off'),
  invalid('invalid');

  const TunFdState(this.wire);
  final String wire;

  static TunFdState fromWire(String? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => TunFdState.none,
      );
}

enum CoreState {
  stopped('stopped'),
  starting('starting'),
  running('running'),
  unreachable('unreachable');

  const CoreState(this.wire);
  final String wire;

  static CoreState fromWire(String? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => CoreState.stopped,
      );
}

// ---------------------------------------------------------------------------
// 校验
// ---------------------------------------------------------------------------

/// 单条校验问题。`path` 用 JSON Pointer（`/rules/12`），`line` 为 1-based。
class ValidationIssue {
  const ValidationIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.path,
    this.line,
    this.column,
    this.hint,
    this.excerpt,
  });

  final String code;
  final ValidationSeverity severity;
  final String message;
  final String? path;
  final int? line;
  final int? column;
  final String? hint;

  /// 出问题的原文片段（单行，≤200 字符），用于行内展开。
  final String? excerpt;

  bool get isBlocking => severity == ValidationSeverity.error;

  Map<String, Object?> toJson() => {
        'code': code,
        'severity': severity.wire,
        'message': message,
        if (path != null) 'path': path,
        if (line != null) 'line': line,
        if (column != null) 'column': column,
        if (hint != null) 'hint': hint,
        if (excerpt != null) 'excerpt': excerpt,
      };

  factory ValidationIssue.fromJson(Map<String, Object?> j) => ValidationIssue(
        code: j['code'] as String? ?? 'E_UNKNOWN',
        severity: ValidationSeverity.fromWire(j['severity'] as String?),
        message: j['message'] as String? ?? '',
        path: j['path'] as String?,
        line: (j['line'] as num?)?.toInt(),
        column: (j['column'] as num?)?.toInt(),
        hint: j['hint'] as String?,
        excerpt: j['excerpt'] as String?,
      );
}

/// 静态 lint 与内核校验的合并结果。两项都通过才允许激活。
class ValidationReport {
  const ValidationReport({
    required this.issues,
    required this.staticElapsed,
    required this.kernelOk,
    this.kernelElapsed,
    this.kernelError,
    this.kernelVersion,
    required this.validatedAt,
  });

  final List<ValidationIssue> issues;
  final Duration staticElapsed;

  /// 内核 parser 是否接受（`S4`）。false 时 `kernelError` 必填。
  final bool kernelOk;
  final Duration? kernelElapsed;
  final String? kernelError;
  final String? kernelVersion;
  final DateTime validatedAt;

  bool get hasBlockingError => issues.any((i) => i.isBlocking) || !kernelOk;

  int get errorCount => issues.where((i) => i.isBlocking).length;
  int get warningCount =>
      issues.where((i) => i.severity == ValidationSeverity.warning).length;

  /// 展示用：错误优先，其次按行号。
  List<ValidationIssue> get sorted {
    final copy = [...issues];
    copy.sort((a, b) {
      final bySeverity = a.severity.index.compareTo(b.severity.index);
      if (bySeverity != 0) return bySeverity;
      return (a.line ?? 1 << 30).compareTo(b.line ?? 1 << 30);
    });
    return copy;
  }

  Map<String, Object?> toJson() => {
        'issues': issues.map((e) => e.toJson()).toList(growable: false),
        'staticMs': staticElapsed.inMilliseconds,
        'kernelOk': kernelOk,
        if (kernelElapsed != null) 'kernelMs': kernelElapsed!.inMilliseconds,
        if (kernelError != null) 'kernelError': kernelError,
        if (kernelVersion != null) 'kernelVersion': kernelVersion,
        'validatedAt': validatedAt.toUtc().toIso8601String(),
      };

  factory ValidationReport.fromJson(Map<String, Object?> j) => ValidationReport(
        issues: ((j['issues'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ValidationIssue.fromJson(e.cast<String, Object?>()))
            .toList(growable: false),
        staticElapsed: Duration(milliseconds: (j['staticMs'] as num?)?.toInt() ?? 0),
        kernelOk: j['kernelOk'] as bool? ?? false,
        kernelElapsed: j['kernelMs'] == null
            ? null
            : Duration(milliseconds: (j['kernelMs'] as num).toInt()),
        kernelError: j['kernelError'] as String?,
        kernelVersion: j['kernelVersion'] as String?,
        validatedAt: DateTime.parse(
          j['validatedAt'] as String? ?? DateTime.now().toUtc().toIso8601String(),
        ).toUtc(),
      );
}

// ---------------------------------------------------------------------------
// 配置摘要
// ---------------------------------------------------------------------------

/// 导入时算一次、之后只读。列表页只依赖它，绝不为渲染列表去解析原文。
class ConfigSummary {
  const ConfigSummary({
    required this.proxyCount,
    required this.proxyGroupCount,
    required this.ruleCount,
    required this.ruleProviderCount,
    required this.ruleTypeHistogram,
    required this.proxyGroupNames,
    required this.proxyNames,
    required this.ruleProviderNames,
    required this.hasDns,
    required this.hasTun,
    required this.mode,
    required this.matchTarget,
    required this.topLevelKeys,
  });

  final int proxyCount;
  final int proxyGroupCount;

  /// 顶层 `rules` 条数（RULE-SET 算 1 条）。
  final int ruleCount;
  final int ruleProviderCount;

  /// 例如 `{'DOMAIN-SUFFIX': 812, 'IP-CIDR': 96, 'MATCH': 1}`。
  final Map<String, int> ruleTypeHistogram;

  final List<String> proxyGroupNames;
  final List<String> proxyNames;
  final List<String> ruleProviderNames;

  final bool hasDns;
  final bool hasTun;
  final String? mode;

  /// `MATCH` 的目标（校验通过时必非空），用于列表页副行摘要。
  final String? matchTarget;

  final List<String> topLevelKeys;

  Map<String, Object?> toJson() => {
        'proxyCount': proxyCount,
        'proxyGroupCount': proxyGroupCount,
        'ruleCount': ruleCount,
        'ruleProviderCount': ruleProviderCount,
        'ruleTypeHistogram': ruleTypeHistogram,
        'proxyGroupNames': proxyGroupNames,
        'proxyNames': proxyNames,
        'ruleProviderNames': ruleProviderNames,
        'hasDns': hasDns,
        'hasTun': hasTun,
        if (mode != null) 'mode': mode,
        if (matchTarget != null) 'matchTarget': matchTarget,
        'topLevelKeys': topLevelKeys,
      };

  factory ConfigSummary.fromJson(Map<String, Object?> j) => ConfigSummary(
        proxyCount: (j['proxyCount'] as num?)?.toInt() ?? 0,
        proxyGroupCount: (j['proxyGroupCount'] as num?)?.toInt() ?? 0,
        ruleCount: (j['ruleCount'] as num?)?.toInt() ?? 0,
        ruleProviderCount: (j['ruleProviderCount'] as num?)?.toInt() ?? 0,
        ruleTypeHistogram: ((j['ruleTypeHistogram'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        proxyGroupNames:
            ((j['proxyGroupNames'] as List?) ?? const []).map((e) => e.toString()).toList(growable: false),
        proxyNames:
            ((j['proxyNames'] as List?) ?? const []).map((e) => e.toString()).toList(growable: false),
        ruleProviderNames:
            ((j['ruleProviderNames'] as List?) ?? const []).map((e) => e.toString()).toList(growable: false),
        hasDns: j['hasDns'] as bool? ?? false,
        hasTun: j['hasTun'] as bool? ?? false,
        mode: j['mode'] as String?,
        matchTarget: j['matchTarget'] as String?,
        topLevelKeys:
            ((j['topLevelKeys'] as List?) ?? const []).map((e) => e.toString()).toList(growable: false),
      );
}

// ---------------------------------------------------------------------------
// Overlay：用户改动与原始订阅分离（文档 §5.3）
// ---------------------------------------------------------------------------

enum RuleOpKind {
  insert('insert'),
  delete('delete'),
  move('move'),
  setTarget('set_target');

  const RuleOpKind(this.wire);
  final String wire;

  static RuleOpKind fromWire(String? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => RuleOpKind.insert,
      );
}

class RuleOp {
  const RuleOp({
    required this.kind,
    this.index,
    this.from,
    this.to,
    this.value,
    this.expectHash,
  });

  final RuleOpKind kind;
  final int? index;
  final int? from;
  final int? to;
  final String? value;

  /// 该行内容的 sha256 前缀，用于检测订阅更新后的行号漂移。
  final String? expectHash;

  Map<String, Object?> toJson() => {
        'op': kind.wire,
        if (index != null) 'index': index,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (value != null) 'value': value,
        if (expectHash != null) 'expectHash': expectHash,
      };

  factory RuleOp.fromJson(Map<String, Object?> j) => RuleOp(
        kind: RuleOpKind.fromWire(j['op'] as String?),
        index: (j['index'] as num?)?.toInt(),
        from: (j['from'] as num?)?.toInt(),
        to: (j['to'] as num?)?.toInt(),
        value: j['value'] as String?,
        expectHash: j['expectHash'] as String?,
      );
}

class ProfileOverlay {
  const ProfileOverlay({
    this.revision = 0,
    this.ruleOps = const [],
    this.groupPins = const {},
    this.bypassLanPreludeInjected = false,
  });

  final int revision;

  /// 应用顺序固定：delete → move → setTarget → insert。
  final List<RuleOp> ruleOps;

  /// 组名 → 节点名。与内核 `profile.store-selected` 双写，换设备可恢复。
  final Map<String, String> groupPins;

  /// 设备级 prelude（绕过局域网）是否已注入，用于 UI 区分"你的规则"与"App 注入"。
  final bool bypassLanPreludeInjected;

  bool get isEmpty =>
      ruleOps.isEmpty && groupPins.isEmpty && !bypassLanPreludeInjected;

  ProfileOverlay copyWith({
    int? revision,
    List<RuleOp>? ruleOps,
    Map<String, String>? groupPins,
    bool? bypassLanPreludeInjected,
  }) =>
      ProfileOverlay(
        revision: revision ?? this.revision,
        ruleOps: ruleOps ?? this.ruleOps,
        groupPins: groupPins ?? this.groupPins,
        bypassLanPreludeInjected:
            bypassLanPreludeInjected ?? this.bypassLanPreludeInjected,
      );

  Map<String, Object?> toJson() => {
        'revision': revision,
        'ruleOps': ruleOps.map((e) => e.toJson()).toList(growable: false),
        'groupPins': groupPins,
        'bypassLanPreludeInjected': bypassLanPreludeInjected,
      };

  factory ProfileOverlay.fromJson(Map<String, Object?> j) => ProfileOverlay(
        revision: (j['revision'] as num?)?.toInt() ?? 0,
        ruleOps: ((j['ruleOps'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => RuleOp.fromJson(e.cast<String, Object?>()))
            .toList(growable: false),
        groupPins: ((j['groupPins'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
        bypassLanPreludeInjected: j['bypassLanPreludeInjected'] as bool? ?? false,
      );
}

// ---------------------------------------------------------------------------
// 订阅流量信息（`subscription-userinfo` 响应头）
// ---------------------------------------------------------------------------

class SubscriptionInfo {
  const SubscriptionInfo({
    this.upload,
    this.download,
    this.total,
    this.expireAt,
  });

  final int? upload;
  final int? download;
  final int? total;
  final DateTime? expireAt;

  double? get usedRatio {
    final t = total;
    if (t == null || t <= 0) return null;
    final used = (upload ?? 0) + (download ?? 0);
    return (used / t).clamp(0, 1).toDouble();
  }

  /// `upload=1; download=2; total=3; expire=1700000000`
  static SubscriptionInfo? tryParse(String? header) {
    if (header == null || header.trim().isEmpty) return null;
    final map = <String, String>{};
    for (final part in header.split(';')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      map[part.substring(0, idx).trim()] = part.substring(idx + 1).trim();
    }
    int? asInt(String k) => int.tryParse(map[k] ?? '');
    final expire = asInt('expire');
    return SubscriptionInfo(
      upload: asInt('upload'),
      download: asInt('download'),
      total: asInt('total'),
      expireAt: expire == null || expire <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expire * 1000, isUtc: true),
    );
  }
}

// ---------------------------------------------------------------------------
// 1) ImportedProfile
// ---------------------------------------------------------------------------

class ImportedProfile {
  const ImportedProfile({
    required this.id,
    required this.displayName,
    required this.source,
    required this.rawYaml,
    required this.contentHash,
    required this.importedAt,
    required this.summary,
    required this.validation,
    required this.revision,
    this.sourceUrl,
    this.lastActivatedAt,
    this.isActive = false,
    this.subscriptionInfo,
    this.overlay = const ProfileOverlay(),
  });

  final String id;
  final String displayName;
  final ProfileSource source;

  /// 订阅地址（敏感）。持久化前用 Keystore 包裹，UI 只显示 host。
  final String? sourceUrl;

  /// 原文，永不修改。所有编辑进 [overlay]。
  final String rawYaml;

  /// 归一化后 sha256，用于去重与"订阅有没有更新"。
  final String contentHash;

  final DateTime importedAt;
  final DateTime? lastActivatedAt;
  final ConfigSummary summary;
  final ValidationReport validation;
  final bool isActive;
  final int revision;
  final SubscriptionInfo? subscriptionInfo;
  final ProfileOverlay overlay;

  /// 能否被激活：校验通过 + 无阻断错误。
  bool get activatable => !validation.hasBlockingError;

  ImportedProfile copyWith({
    String? displayName,
    String? sourceUrl,
    String? rawYaml,
    String? contentHash,
    DateTime? lastActivatedAt,
    ConfigSummary? summary,
    ValidationReport? validation,
    bool? isActive,
    int? revision,
    SubscriptionInfo? subscriptionInfo,
    ProfileOverlay? overlay,
  }) =>
      ImportedProfile(
        id: id,
        displayName: displayName ?? this.displayName,
        source: source,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        rawYaml: rawYaml ?? this.rawYaml,
        contentHash: contentHash ?? this.contentHash,
        importedAt: importedAt,
        lastActivatedAt: lastActivatedAt ?? this.lastActivatedAt,
        summary: summary ?? this.summary,
        validation: validation ?? this.validation,
        isActive: isActive ?? this.isActive,
        revision: revision ?? this.revision,
        subscriptionInfo: subscriptionInfo ?? this.subscriptionInfo,
        overlay: overlay ?? this.overlay,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'displayName': displayName,
        'source': source.wire,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        'rawYaml': rawYaml,
        'contentHash': contentHash,
        'importedAt': importedAt.toUtc().toIso8601String(),
        if (lastActivatedAt != null)
          'lastActivatedAt': lastActivatedAt!.toUtc().toIso8601String(),
        'summary': summary.toJson(),
        'validation': validation.toJson(),
        'isActive': isActive,
        'revision': revision,
        if (subscriptionInfo != null)
          'subscriptionInfo': {
            'upload': subscriptionInfo!.upload,
            'download': subscriptionInfo!.download,
            'total': subscriptionInfo!.total,
            'expireAt': subscriptionInfo!.expireAt?.toIso8601String(),
          },
        'overlay': overlay.toJson(),
      };

  factory ImportedProfile.fromJson(Map<String, Object?> j) {
    final sub = (j['subscriptionInfo'] as Map?)?.cast<String, Object?>();
    return ImportedProfile(
      id: j['id'] as String,
      displayName: j['displayName'] as String? ?? '未命名配置',
      source: ProfileSource.fromWire(j['source'] as String?),
      sourceUrl: j['sourceUrl'] as String?,
      rawYaml: j['rawYaml'] as String? ?? '',
      contentHash: j['contentHash'] as String? ?? '',
      importedAt: DateTime.parse(j['importedAt'] as String).toUtc(),
      lastActivatedAt: j['lastActivatedAt'] == null
          ? null
          : DateTime.parse(j['lastActivatedAt'] as String).toUtc(),
      summary: ConfigSummary.fromJson(
        ((j['summary'] as Map?) ?? const {}).cast<String, Object?>(),
      ),
      validation: ValidationReport.fromJson(
        ((j['validation'] as Map?) ?? const {}).cast<String, Object?>(),
      ),
      isActive: j['isActive'] as bool? ?? false,
      revision: (j['revision'] as num?)?.toInt() ?? 0,
      subscriptionInfo: sub == null
          ? null
          : SubscriptionInfo(
              upload: (sub['upload'] as num?)?.toInt(),
              download: (sub['download'] as num?)?.toInt(),
              total: (sub['total'] as num?)?.toInt(),
              expireAt: sub['expireAt'] == null
                  ? null
                  : DateTime.parse(sub['expireAt'] as String).toUtc(),
            ),
      overlay: ProfileOverlay.fromJson(
        ((j['overlay'] as Map?) ?? const {}).cast<String, Object?>(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2) RuleProviderRef
// ---------------------------------------------------------------------------

class RuleProviderRef {
  const RuleProviderRef({
    required this.name,
    required this.type,
    required this.behavior,
    required this.format,
    required this.cacheState,
    this.url,
    this.path,
    this.intervalSeconds,
    this.proxy,
    this.cachePath,
    this.lastUpdatedAt,
    this.ruleCount,
    this.lastError,
  });

  final String name;
  final RuleProviderType type;
  final RuleProviderBehavior behavior;
  final RuleProviderFormat format;

  /// YAML 中的原始值；运行时会被物化改写为 `./providers/...`。
  final String? url;
  final String? path;

  final int? intervalSeconds;
  final String? proxy;

  final String? cachePath;
  final ProviderCacheState cacheState;
  final DateTime? lastUpdatedAt;

  /// `GET /providers/rules` 的 ruleCount（展开后的条目数）。
  final int? ruleCount;
  final String? lastError;

  bool get isRemote => type == RuleProviderType.http;

  bool get isStale {
    final updated = lastUpdatedAt;
    final interval = intervalSeconds;
    if (updated == null || interval == null || interval <= 0) return false;
    return DateTime.now().toUtc().difference(updated).inSeconds > interval;
  }

  RuleProviderRef copyWith({
    ProviderCacheState? cacheState,
    String? cachePath,
    DateTime? lastUpdatedAt,
    int? ruleCount,
    String? lastError,
  }) =>
      RuleProviderRef(
        name: name,
        type: type,
        behavior: behavior,
        format: format,
        url: url,
        path: path,
        intervalSeconds: intervalSeconds,
        proxy: proxy,
        cachePath: cachePath ?? this.cachePath,
        cacheState: cacheState ?? this.cacheState,
        lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
        ruleCount: ruleCount ?? this.ruleCount,
        lastError: lastError,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'type': type.wire,
        'behavior': behavior.wire,
        'format': format.wire,
        if (url != null) 'url': url,
        if (path != null) 'path': path,
        if (intervalSeconds != null) 'interval': intervalSeconds,
        if (proxy != null) 'proxy': proxy,
        if (cachePath != null) 'cachePath': cachePath,
        'cacheState': cacheState.wire,
        if (lastUpdatedAt != null)
          'lastUpdatedAt': lastUpdatedAt!.toUtc().toIso8601String(),
        if (ruleCount != null) 'ruleCount': ruleCount,
        if (lastError != null) 'lastError': lastError,
      };

  factory RuleProviderRef.fromJson(Map<String, Object?> j) => RuleProviderRef(
        name: j['name'] as String,
        type: RuleProviderType.fromWire(j['type'] as String?),
        behavior: RuleProviderBehavior.fromWire(j['behavior'] as String?),
        format: RuleProviderFormat.fromWire(j['format'] as String?),
        url: j['url'] as String?,
        path: j['path'] as String?,
        intervalSeconds: (j['interval'] as num?)?.toInt(),
        proxy: j['proxy'] as String?,
        cachePath: j['cachePath'] as String?,
        cacheState: ProviderCacheState.fromWire(j['cacheState'] as String?),
        lastUpdatedAt: j['lastUpdatedAt'] == null
            ? null
            : DateTime.parse(j['lastUpdatedAt'] as String).toUtc(),
        ruleCount: (j['ruleCount'] as num?)?.toInt(),
        lastError: j['lastError'] as String?,
      );
}

// ---------------------------------------------------------------------------
// 3) ProxyGroupSnapshot
// ---------------------------------------------------------------------------

class ProxyGroupSnapshot {
  const ProxyGroupSnapshot({
    required this.name,
    required this.kind,
    required this.all,
    required this.capturedAt,
    this.now,
    this.fixed,
    this.testUrl,
    this.expectedStatus,
    this.hidden = false,
    this.iconUrl,
    this.latency = const {},
  });

  final String name;
  final ProxyGroupKind kind;

  /// 当前出口；LoadBalance 恒为 null。
  final String? now;

  final List<String> all;

  /// url-test / fallback 被手动钉住的节点。
  final String? fixed;

  final String? testUrl;
  final String? expectedStatus;
  final bool hidden;
  final String? iconUrl;

  /// 本地最近一次测速结果（ms），null 表示不可用。非内核字段。
  final Map<String, int?> latency;

  final DateTime capturedAt;

  /// 延迟分档，UI 直接映射颜色/宽度，避免在 widget 里写逻辑。
  int? get bestLatency {
    final values = latency.values.whereType<int>().where((e) => e > 0);
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a < b ? a : b);
  }

  bool isAvailable(String node) => (latency[node] ?? 0) > 0;

  ProxyGroupSnapshot copyWith({
    String? now,
    String? fixed,
    Map<String, int?>? latency,
    DateTime? capturedAt,
  }) =>
      ProxyGroupSnapshot(
        name: name,
        kind: kind,
        now: now ?? this.now,
        all: all,
        fixed: fixed ?? this.fixed,
        testUrl: testUrl,
        expectedStatus: expectedStatus,
        hidden: hidden,
        iconUrl: iconUrl,
        latency: latency ?? this.latency,
        capturedAt: capturedAt ?? this.capturedAt,
      );

  /// `GET /proxies` 的单个 value 直接可转。
  factory ProxyGroupSnapshot.fromKernel(
    String name,
    Map<String, Object?> j, {
    DateTime? capturedAt,
  }) =>
      ProxyGroupSnapshot(
        name: name,
        kind: ProxyGroupKind.fromKernel(j['type'] as String?),
        now: j['now'] as String?,
        all: ((j['all'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        fixed: j['fixed'] as String?,
        testUrl: j['testUrl'] as String?,
        expectedStatus: j['expectedStatus'] as String?,
        hidden: j['hidden'] as bool? ?? false,
        iconUrl: j['icon'] as String?,
        capturedAt: capturedAt ?? DateTime.now().toUtc(),
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'kind': kind.wire,
        if (now != null) 'now': now,
        'all': all,
        if (fixed != null) 'fixed': fixed,
        if (testUrl != null) 'testUrl': testUrl,
        if (expectedStatus != null) 'expectedStatus': expectedStatus,
        'hidden': hidden,
        if (iconUrl != null) 'iconUrl': iconUrl,
        'latency': latency,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
      };

  factory ProxyGroupSnapshot.fromJson(Map<String, Object?> j) =>
      ProxyGroupSnapshot(
        name: j['name'] as String,
        kind: ProxyGroupKind.fromWire(j['kind'] as String?),
        now: j['now'] as String?,
        all: ((j['all'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        fixed: j['fixed'] as String?,
        testUrl: j['testUrl'] as String?,
        expectedStatus: j['expectedStatus'] as String?,
        hidden: j['hidden'] as bool? ?? false,
        iconUrl: j['iconUrl'] as String?,
        latency: ((j['latency'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt())),
        capturedAt: DateTime.parse(j['capturedAt'] as String).toUtc(),
      );
}

// ---------------------------------------------------------------------------
// 4) RuleTrace
// ---------------------------------------------------------------------------

class RuleTrace {
  const RuleTrace({
    required this.connectionId,
    required this.network,
    required this.matchedRuleText,
    required this.ruleType,
    required this.rulePayload,
    required this.outboundName,
    required this.chain,
    required this.startedAt,
    required this.verdict,
    this.host,
    this.destIp,
    this.destPort,
    this.processName,
    this.uid,
    this.providerName,
    this.upload = 0,
    this.download = 0,
    this.closedAt,
  });

  final String connectionId;

  final String? host;
  final String? destIp;
  final int? destPort;

  /// `tcp` / `udp`。
  final String network;

  final String? processName;
  final int? uid;

  /// 渲染用规则文本，**不含出口**，例如 `RULE-SET,cn-domain`、`DOMAIN-SUFFIX,google.com`。
  /// 出口单独展示，避免把"命中的规则"和"实际走的节点"混为一谈。
  final String matchedRuleText;
  final String ruleType;
  final String rulePayload;

  /// `ruleType == 'RuleSet'` 时由 payload 反查得到。
  final String? providerName;

  /// 实际拨号的节点。
  ///
  /// ⚠️ 取 `chains` 的**第一个**元素：它是最内层（真正建连的节点），末元素是最外层策略组。
  /// 不同内核版本/嵌套深度下顺序可能相反（见附录 A-1），因此该字段只用于展示与过滤，
  /// 不要用它做任何路由语义判断。
  final String outboundName;

  /// 完整链路（内层 → 外层），UI 用 `→` 连接。
  final List<String> chain;

  final int upload;
  final int download;
  final DateTime startedAt;
  final DateTime? closedAt;
  final TraceVerdict verdict;

  /// 列表主文案：优先域名，其次 IP:port。
  String get displayTarget {
    if (host != null && host!.isNotEmpty) {
      return destPort == null ? host! : '$host:$destPort';
    }
    if (destIp == null) return '(unknown)';
    return destPort == null ? destIp! : '$destIp:$destPort';
  }

  bool get isActive => closedAt == null;

  factory RuleTrace.fromKernel(Map<String, Object?> j) {
    final meta = ((j['metadata'] as Map?) ?? const {}).cast<String, Object?>();
    final chains = ((j['chains'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);
    final rule = j['rule'] as String? ?? '';
    final payload = j['rulePayload'] as String? ?? '';

    // chains[0] 是实际拨号节点；为空时退化为 payload 末段（DIRECT/REJECT 等场景）。
    final outbound = chains.isNotEmpty ? chains.first : _lastSegment(payload);

    return RuleTrace(
      connectionId: j['id']?.toString() ?? '',
      host: meta['host'] as String?,
      destIp: meta['destinationIP'] as String?,
      destPort: (meta['destinationPort'] as num?)?.toInt(),
      network: meta['network'] as String? ?? 'tcp',
      processName: meta['process'] as String?,
      uid: (meta['uid'] as num?)?.toInt(),
      matchedRuleText: _renderRule(rule, payload),
      ruleType: rule,
      rulePayload: payload,
      providerName: rule == 'RuleSet' ? payload : null,
      outboundName: outbound,
      chain: chains,
      upload: (j['upload'] as num?)?.toInt() ?? 0,
      download: (j['download'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        ((j['start'] as num?)?.toInt() ?? 0) * 1000,
        isUtc: true,
      ),
      closedAt: j['closedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (j['closedAt'] as num).toInt() * 1000,
              isUtc: true,
            ),
      verdict: _verdictOf(outbound),
    );
  }

  static String _lastSegment(String payload) {
    if (payload.isEmpty) return '';
    final parts = payload.split(',');
    return parts.last.trim();
  }

  static String _renderRule(String rule, String payload) {
    if (rule.isEmpty) return '未命中规则';
    if (rule == 'Match') return 'MATCH';
    if (payload.isEmpty) return rule;
    return '$rule,$payload';
  }

  static TraceVerdict _verdictOf(String outbound) {
    switch (outbound.toUpperCase()) {
      case 'DIRECT':
        return TraceVerdict.direct;
      case 'REJECT':
      case 'REJECT-DROP':
        return TraceVerdict.rejected;
      case '':
        return TraceVerdict.unknown;
      default:
        return TraceVerdict.proxied;
    }
  }

  Map<String, Object?> toJson() => {
        'connectionId': connectionId,
        if (host != null) 'host': host,
        if (destIp != null) 'destIp': destIp,
        if (destPort != null) 'destPort': destPort,
        'network': network,
        if (processName != null) 'processName': processName,
        if (uid != null) 'uid': uid,
        'matchedRuleText': matchedRuleText,
        'ruleType': ruleType,
        'rulePayload': rulePayload,
        if (providerName != null) 'providerName': providerName,
        'outboundName': outboundName,
        'chain': chain,
        'upload': upload,
        'download': download,
        'startedAt': startedAt.toUtc().toIso8601String(),
        if (closedAt != null) 'closedAt': closedAt!.toUtc().toIso8601String(),
        'verdict': verdict.wire,
      };

  factory RuleTrace.fromJson(Map<String, Object?> j) => RuleTrace(
        connectionId: j['connectionId'] as String,
        host: j['host'] as String?,
        destIp: j['destIp'] as String?,
        destPort: (j['destPort'] as num?)?.toInt(),
        network: j['network'] as String? ?? 'tcp',
        processName: j['processName'] as String?,
        uid: (j['uid'] as num?)?.toInt(),
        matchedRuleText: j['matchedRuleText'] as String? ?? '',
        ruleType: j['ruleType'] as String? ?? '',
        rulePayload: j['rulePayload'] as String? ?? '',
        providerName: j['providerName'] as String?,
        outboundName: j['outboundName'] as String? ?? '',
        chain: ((j['chain'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        upload: (j['upload'] as num?)?.toInt() ?? 0,
        download: (j['download'] as num?)?.toInt() ?? 0,
        startedAt: DateTime.parse(j['startedAt'] as String).toUtc(),
        closedAt: j['closedAt'] == null
            ? null
            : DateTime.parse(j['closedAt'] as String).toUtc(),
        verdict: TraceVerdict.fromWire(j['verdict'] as String?),
      );
}

// ---------------------------------------------------------------------------
// 5) AndroidVpnState
// ---------------------------------------------------------------------------

class TunnelError {
  const TunnelError({
    required this.code,
    required this.message,
    this.recoverable = false,
    this.cause,
    this.retryAfter,
  });

  final String code;
  final String message;
  final bool recoverable;
  final String? cause;

  /// 部分错误（如 onRevoke 后的自动重连）需要退避。
  final Duration? retryAfter;

  Map<String, Object?> toJson() => {
        'code': code,
        'message': message,
        'recoverable': recoverable,
        if (cause != null) 'cause': cause,
        if (retryAfter != null) 'retryAfterMs': retryAfter!.inMilliseconds,
      };

  factory TunnelError.fromJson(Map<String, Object?> j) => TunnelError(
        code: j['code'] as String? ?? 'E_UNKNOWN',
        message: j['message'] as String? ?? '',
        recoverable: j['recoverable'] as bool? ?? false,
        cause: j['cause'] as String?,
        retryAfter: j['retryAfterMs'] == null
            ? null
            : Duration(milliseconds: (j['retryAfterMs'] as num).toInt()),
      );
}

class AndroidVpnState {
  const AndroidVpnState({
    required this.phase,
    required this.prepare,
    required this.service,
    required this.tunFd,
    required this.core,
    required this.since,
    this.sessionId,
    this.error,
    this.underlying,
    this.coreVersion,
    this.profileId,
  });

  /// 进程启动、尚未收到原生状态时使用。
  factory AndroidVpnState.idle() => AndroidVpnState(
        phase: TunnelPhase.idle,
        prepare: PrepareState.notRequested,
        service: ServiceState.stopped,
        tunFd: TunFdState.none,
        core: CoreState.stopped,
        since: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  final TunnelPhase phase;
  final PrepareState prepare;
  final ServiceState service;
  final TunFdState tunFd;
  final CoreState core;
  final TunnelError? error;

  /// 每次连接生成，旧事件据此丢弃。
  final String? sessionId;
  final String? profileId;
  final String? underlying; // wifi / cellular / ethernet / vpn / none
  final String? coreVersion;
  final DateTime since;

  bool get isConnected => phase == TunnelPhase.connected;
  bool get canConnect =>
      phase == TunnelPhase.idle ||
      phase == TunnelPhase.failed ||
      phase == TunnelPhase.permissionDenied;
  bool get canDisconnect => phase.isEngaged;

  AndroidVpnState copyWith({
    TunnelPhase? phase,
    PrepareState? prepare,
    ServiceState? service,
    TunFdState? tunFd,
    CoreState? core,
    String? sessionId,
    String? profileId,
    String? underlying,
    String? coreVersion,
    DateTime? since,
    TunnelError? error,
    bool clearError = false,
  }) =>
      AndroidVpnState(
        phase: phase ?? this.phase,
        prepare: prepare ?? this.prepare,
        service: service ?? this.service,
        tunFd: tunFd ?? this.tunFd,
        core: core ?? this.core,
        sessionId: sessionId ?? this.sessionId,
        error: clearError ? null : (error ?? this.error),
        profileId: profileId ?? this.profileId,
        underlying: underlying ?? this.underlying,
        coreVersion: coreVersion ?? this.coreVersion,
        since: since ?? this.since,
      );

  Map<String, Object?> toJson() => {
        'phase': phase.wire,
        'prepare': prepare.wire,
        'service': service.wire,
        'tunFd': tunFd.wire,
        'core': core.wire,
        if (error != null) 'error': error!.toJson(),
        if (sessionId != null) 'sessionId': sessionId,
        if (profileId != null) 'profileId': profileId,
        if (underlying != null) 'underlying': underlying,
        if (coreVersion != null) 'coreVersion': coreVersion,
        'since': since.toUtc().toIso8601String(),
      };

  factory AndroidVpnState.fromJson(Map<String, Object?> j) => AndroidVpnState(
        phase: TunnelPhase.fromWire(j['phase'] as String?),
        prepare: PrepareState.fromWire(j['prepare'] as String?),
        service: ServiceState.fromWire(j['service'] as String?),
        tunFd: TunFdState.fromWire(j['tunFd'] as String?),
        core: CoreState.fromWire(j['core'] as String?),
        error: j['error'] == null
            ? null
            : TunnelError.fromJson((j['error'] as Map).cast<String, Object?>()),
        sessionId: j['sessionId'] as String?,
        profileId: j['profileId'] as String?,
        underlying: j['underlying'] as String?,
        coreVersion: j['coreVersion'] as String?,
        since: DateTime.parse(j['since'] as String).toUtc(),
      );
}

// ---------------------------------------------------------------------------
// 组合（Merge 模式，v1.1）：编译产物，供 UI 预览"合并后的有效规则顺序"
// ---------------------------------------------------------------------------

class CompositionPlan {
  const CompositionPlan({
    required this.memberProfileIds,
    required this.proxyRenames,
    required this.providerRenames,
    required this.ruleSegments,
    required this.finalMatchTarget,
    required this.warnings,
  });

  final List<String> memberProfileIds;
  final Map<String, String> proxyRenames; // 原名 -> 新名
  final Map<String, String> providerRenames;
  final List<RuleSegment> ruleSegments;
  final String finalMatchTarget;
  final List<String> warnings;

  Map<String, Object?> toJson() => {
        'memberProfileIds': memberProfileIds,
        'proxyRenames': proxyRenames,
        'providerRenames': providerRenames,
        'ruleSegments': ruleSegments.map((e) => e.toJson()).toList(growable: false),
        'finalMatchTarget': finalMatchTarget,
        'warnings': warnings,
      };
}

class RuleSegment {
  const RuleSegment({
    required this.profileId,
    required this.startIndex,
    required this.count,
    required this.matchTarget,
  });

  final String profileId;
  final int startIndex;
  final int count;

  /// 该段的 MATCH 被改写成的兜底组。
  final String matchTarget;

  Map<String, Object?> toJson() => {
        'profileId': profileId,
        'startIndex': startIndex,
        'count': count,
        'matchTarget': matchTarget,
      };
}
