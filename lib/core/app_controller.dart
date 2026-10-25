import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';
import 'tunnel/simulated_tunnel.dart';
import 'tunnel/tunnel_factory.dart';
import 'tunnel/tunnel_platform.dart';
import 'tunnel/tunnel_state.dart';

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

  TunnelState tunnelState = const TunnelState();
  String? activeProfileId;

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
    } catch (_) {}

    if (profiles.isNotEmpty) {
      activeProfileId = profiles.first.id;
    }

    // 关键修复：头像路径持久化在 SharedPreferences，重启后恢复。
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      for (int i = 0; i < profiles.length; i++) {
        final String? path = prefs.getString('avatar.${profiles[i].id}');
        if (path != null && path.isNotEmpty && File(path).existsSync()) {
          profiles[i] = profiles[i].copyWith(avatarPath: path);
        }
      }
    } catch (_) {}

    notifyListeners();
  }

  void _onState(TunnelState next) {
    tunnelState = next;
    notifyListeners();
  }

  Future<void> toggleConnection() async {
    if (tunnelState.isBusy) return;

    if (tunnelState.isConnected) {
      await _platform.disconnect();
      _stopLogs();
      return;
    }

    final Profile? profile = activeProfile;
    if (profile == null) {
      _fail('还没有选择配置');
      return;
    }
    if (profile.rawYaml.trim().isEmpty) {
      _fail('「${profile.name}」没有可用的 YAML，请先导入真实配置。');
      return;
    }

    final String secret = _randomSecret();
    final int port = 20000 + Random.secure().nextInt(20000);

    try {
      await _platform.connect(
        profile.id,
        profile.rawYaml,
        secret: secret,
        port: port,
        ipv6: true,
      );
      _startLogs();
    } catch (error) {
      _fail('操作失败：$error');
    }
  }

  void _fail(String message) {
    tunnelState = tunnelState.copyWith(
      phase: TunnelPhase.failed,
      message: message,
    );
    notifyListeners();
  }

  String _randomSecret() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  void selectProfile(String id) {
    activeProfileId = id;
    notifyListeners();
  }

  Profile importProfile(String yaml, {String? name}) {
    final int rules = estimateRuleCount(yaml);
    final String title = (name == null || name.trim().isEmpty)
        ? '粘贴配置 ${profiles.length + 1}'
        : name.trim();

    final Profile profile = Profile(
      id: 'p-${DateTime.now().millisecondsSinceEpoch}',
      name: title,
      source: ProfileSource.paste,
      rawYaml: yaml,
      ruleCount: rules,
      updatedAt: DateTime.now(),
      groupSummary: rules == 0 ? '未发现 rules 段' : '已保存原文，连接时交给内核解析',
      groups: const <GroupInfo>[],
      rules: const <String>[],
      providers: const <ProviderInfo>[],
      valid: rules > 0,
    );

    profiles.insert(0, profile);
    notifyListeners();
    return profile;
  }

  /// 复制用户选的头像到应用目录并持久化路径，重启不丢。
  Future<void> updateAvatar(String profileId, String sourcePath) async {
    final int index = profiles.indexWhere((Profile p) => p.id == profileId);
    if (index < 0) return;

    try {
      final Directory dir = await getApplicationSupportDirectory();
      final Directory folder = Directory('${dir.path}/avatars');
      await folder.create(recursive: true);

      String ext = 'jpg';
      final int dot = sourcePath.lastIndexOf('.');
      if (dot >= 0 && dot < sourcePath.length - 1) {
        ext = sourcePath.substring(dot + 1).toLowerCase();
      }

      final String dest =
          '${folder.path}/${profileId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(sourcePath).copy(dest);

      profiles[index] = profiles[index].copyWith(avatarPath: dest);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('avatar.$profileId', dest);

      notifyListeners();
    } catch (_) {}
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
          outbound: direct ? 'DIRECT' : 'PROXY',
          rule: direct ? 'GEOIP,CN' : 'MATCH,PROXY',
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
    super.dispose();
  }
}
