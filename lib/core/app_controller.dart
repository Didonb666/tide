import 'dart:async';

import 'package:flutter/material.dart';

import 'profile.dart';
import 'tunnel/simulated_tunnel.dart';
import 'tunnel/tunnel_factory.dart';
import 'tunnel/tunnel_platform.dart';
import 'tunnel/tunnel_state.dart';

/// 全局状态。刻意不引入 Riverpod / Bloc：
/// 第一阶段的页面状态很浅，一个 ChangeNotifier 足够，且能让新手少装一堆依赖。
class AppController extends ChangeNotifier {
  AppController({TunnelPlatform? platform})
      : _platform = platform ?? createTunnelPlatform(),
        profiles = buildMockProfiles();

  TunnelPlatform _platform;
  StreamSubscription<TunnelState>? _subscription;
  Timer? _logTimer;
  bool _initialized = false;
  int _logSeq = 0;

  final List<Profile> profiles;
  final List<LogEntry> logs = <LogEntry>[];
  final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  TunnelState tunnelState = const TunnelState();
  String? activeProfileId;
  int _themeIndex = 0;

  static const List<ThemeMode> _themeOrder = <ThemeMode>[
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];

  Profile? get activeProfile {
    for (final Profile p in profiles) {
      if (p.id == activeProfileId) return p;
    }
    return profiles.isEmpty ? null : profiles.first;
  }

  bool get usingSimulator => !tunnelState.nativeAvailable;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 原生实现不可用（Windows，或 Android 插件缺失）→ 自动降级，UI 不感知。
    try {
      final bool available = await _platform.isAvailable();
      if (!available) {
        await _platform.dispose();
        _platform = SimulatedTunnelPlatform();
      }
    } catch (_) {
      _platform = SimulatedTunnelPlatform();
    }

    _subscription = _platform.states.listen(_onState);

    try {
      tunnelState = await _platform.readState();
    } catch (_) {
      // 读不到就保持默认 idle。
    }

    if (profiles.isNotEmpty) {
      activeProfileId = profiles.first.id;
    }
    _seedLogs();
    notifyListeners();
  }

  void _onState(TunnelState next) {
    tunnelState = next;
    if (next.isConnected) {
      _startLogs();
    } else {
      _stopLogs();
    }
    notifyListeners();
  }

  Future<void> toggleConnection() async {
    if (tunnelState.isBusy) return;

    if (tunnelState.isConnected) {
      await _platform.disconnect();
      _stopLogs();
      return;
    }

    final String profileId =
        activeProfileId ?? (profiles.isEmpty ? 'default' : profiles.first.id);
    try {
      await _platform.connect(profileId);
      _startLogs();
    } catch (error) {
      tunnelState = tunnelState.copyWith(
        phase: TunnelPhase.failed,
        message: '操作失败：$error',
      );
      notifyListeners();
    }
  }

  void selectProfile(String id) {
    activeProfileId = id;
    notifyListeners();
  }

  /// 导入粘贴的 YAML。返回新档案，便于页面做高亮动画。
  Profile importProfile(String yaml, {String? name}) {
    final int rules = estimateRuleCount(yaml);
    final String title = (name == null || name.trim().isEmpty)
        ? '粘贴配置 ${profiles.length + 1}'
        : name.trim();

    final Profile profile = Profile(
      id: 'p-${DateTime.now().millisecondsSinceEpoch}',
      name: title,
      source: ProfileSource.paste,
      ruleCount: rules,
      updatedAt: DateTime.now(),
      groupSummary: rules == 0 ? '未发现 rules 段' : '已保存原文，等待内核解析策略组',
      groups: const <GroupInfo>[],
      rules: const <String>[],
      providers: const <ProviderInfo>[],
      valid: rules > 0,
    );

    profiles.insert(0, profile);
    notifyListeners();
    return profile;
  }

  void setThemeMode(ThemeMode mode) {
    themeMode.value = mode;
  }

  void cycleThemeMode() {
    _themeIndex = (_themeIndex + 1) % _themeOrder.length;
    themeMode.value = _themeOrder[_themeIndex];
  }

  String themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
    }
  }

  void _seedLogs() {
    final DateTime now = DateTime.now();
    logs
      ..clear()
      ..addAll(<LogEntry>[
        LogEntry(
          id: _logSeq++,
          host: 'www.google.com',
          outbound: '香港 01',
          rule: 'DOMAIN-SUFFIX,google.com',
          bytes: 18432,
          time: now.subtract(const Duration(seconds: 12)),
          verdict: LogVerdict.proxied,
        ),
        LogEntry(
          id: _logSeq++,
          host: 'api.github.com',
          outbound: '香港 01',
          rule: 'DOMAIN-KEYWORD,github',
          bytes: 5120,
          time: now.subtract(const Duration(seconds: 26)),
          verdict: LogVerdict.proxied,
        ),
        LogEntry(
          id: _logSeq++,
          host: '223.5.5.5:53',
          outbound: 'DIRECT',
          rule: 'GEOIP,CN',
          bytes: 128,
          time: now.subtract(const Duration(seconds: 41)),
          verdict: LogVerdict.direct,
        ),
        LogEntry(
          id: _logSeq++,
          host: 'ads.example.net',
          outbound: 'REJECT',
          rule: 'RULE-SET,ads',
          bytes: 0,
          time: now.subtract(const Duration(seconds: 58)),
          verdict: LogVerdict.rejected,
        ),
      ]);
  }

  void _startLogs() {
    if (_logTimer != null) return;
    _logTimer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (!tunnelState.isConnected) return;
      final int index = _logSeq++;
      final List<String> hosts = <String>[
        'cdn.jsdelivr.net',
        'www.youtube.com',
        'api.telegram.org',
        'registry.npmjs.org',
        '10.0.0.1:53',
      ];
      final String host = hosts[index % hosts.length];
      final bool direct = host.endsWith(':53');
      logs.insert(
        0,
        LogEntry(
          id: index,
          host: host,
          outbound: direct ? 'DIRECT' : '香港 01',
          rule: direct ? 'GEOIP,CN' : 'RULE-SET,proxy',
          bytes: 1024 + index * 137,
          time: DateTime.now(),
          verdict: direct ? LogVerdict.direct : LogVerdict.proxied,
        ),
      );
      if (logs.length > 200) logs.removeLast();
      notifyListeners();
    });
  }

  void _stopLogs() {
    _logTimer?.cancel();
    _logTimer = null;
  }

  @override
  void dispose() {
    _stopLogs();
    _subscription?.cancel();
    _platform.dispose();
    themeMode.dispose();
    super.dispose();
  }
}
