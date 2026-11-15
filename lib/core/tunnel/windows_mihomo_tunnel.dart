import 'dart:async';
import 'dart:io';

import '../app_text.dart';
import 'tunnel_platform.dart';
import 'tunnel_state.dart';

/// Windows 真实隧道：调用随包分发的 `mihomo.exe`，并切换系统代理。
///
/// 约定：
///   - 内核文件放在 **exe 同目录** 的 `mihomo.exe`（CI 构建时下载并复制过去）；
///   - 配置写入 `%LOCALAPPDATA%\Fstool\core\config.yaml`；
///   - 系统代理指向 `127.0.0.1:<mixed-port>`，断开时还原为「不使用代理」。
class WindowsMihomoTunnelPlatform implements TunnelPlatform {
  final StreamController<TunnelState> _controller =
      StreamController<TunnelState>.broadcast();

  TunnelState _state = TunnelState(message: '未连接');
  Process? _process;
  bool _proxyChanged = false;
  bool _disposed = false;

  static const int _mixedPort = 7890;

  String get _exeDir => File(Platform.resolvedExecutable).parent.path;

  String get _corePath => '$_exeDir${Platform.pathSeparator}mihomo.exe';

  Directory get _workDir {
    final String base = Platform.environment['LOCALAPPDATA'] ?? _exeDir;
    return Directory('$base${Platform.pathSeparator}Fstool${Platform.pathSeparator}core')
      ..createSync(recursive: true);
  }

  @override
  Future<bool> isAvailable() async => File(_corePath).existsSync();

  @override
  Future<TunnelState> readState() async => _state;

  @override
  Stream<TunnelState> get states => _controller.stream;

  void _emit(TunnelState next) {
    if (_disposed) return;
    _state = next;
    _controller.add(next);
  }

  @override
  Future<void> connect(
    String profileId,
    String configYaml, {
    required String secret,
    required int port,
    bool ipv6 = true,
  }) async {
    if (_state.isConnected || _state.isBusy) return;

    if (!await isAvailable()) {
      _emit(_state.copyWith(
        phase: TunnelPhase.failed,
        message: tr('内核文件缺失（mihomo.exe）'),
      ));
      return;
    }

    _emit(_state.copyWith(
      phase: TunnelPhase.connecting,
      profileId: profileId,
      message: tr('正在启动内核…'),
    ));

    try {
      final Directory dir = _workDir;
      final File config = File('${dir.path}${Platform.pathSeparator}config.yaml');
      String yaml = configYaml;
      if (!yaml.contains('mixed-port')) {
        yaml = 'mixed-port: $_mixedPort\n'
            'allow-lan: false\n'
            'mode: rule\n'
            'log-level: info\n'
            '$yaml';
      }
      config.writeAsStringSync(yaml);

      _process = await Process.start(
        _corePath,
        <String>['-d', dir.path, '-f', config.path],
        workingDirectory: _exeDir,
      );
      _process!.stdout.listen((_) {});
      _process!.stderr.listen((_) {});
      _process!.exitCode.then((int code) {
        if (_disposed || code == 0) return;
        _emit(_state.copyWith(
          phase: TunnelPhase.failed,
          message: '${tr('内核退出')} ($code)',
        ));
      });

      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _setSystemProxy(true);
      _emit(_state.copyWith(
        phase: TunnelPhase.connected,
        message: tr('已连接（mihomo 内核）'),
      ));
    } catch (error) {
      _emit(_state.copyWith(
        phase: TunnelPhase.failed,
        message: '${tr('启动失败')}：$error',
      ));
    }
  }

  @override
  Future<void> disconnect() async {
    _emit(_state.copyWith(
      phase: TunnelPhase.disconnecting,
      message: tr('正在断开…'),
    ));

    await _setSystemProxy(false);
    _proxyChanged = false;

    final Process? process = _process;
    _process = null;
    if (process != null) {
      process.kill();
      await process.exitCode.timeout(
        const Duration(seconds: 3),
        onTimeout: () => -1,
      );
    }

    _emit(_state.copyWith(phase: TunnelPhase.idle, message: tr('已断开')));
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _setSystemProxy(false);
    _process?.kill();
    await _controller.close();
  }

  /// 通过注册表切换系统代理（HKCU，无需管理员）。
  Future<void> _setSystemProxy(bool enable) async {
    try {
      if (enable) {
        await Process.run('reg', <String>[
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v',
          'ProxyEnable',
          '/t',
          'REG_DWORD',
          '/d',
          '1',
          '/f',
        ]);
        await Process.run('reg', <String>[
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v',
          'ProxyServer',
          '/t',
          'REG_SZ',
          '/d',
          '127.0.0.1:$_mixedPort',
          '/f',
        ]);
        _proxyChanged = true;
      } else if (_proxyChanged) {
        await Process.run('reg', <String>[
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v',
          'ProxyEnable',
          '/t',
          'REG_DWORD',
          '/d',
          '0',
          '/f',
        ]);
      }
    } catch (_) {}
  }
}
