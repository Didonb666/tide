import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'license_api.dart';

enum LicenseStatus { unknown, active, expired, inactive }

/// 授权状态：卡密激活 / 账号登录，令牌本地持久化，启动即校验。
class LicenseController extends ChangeNotifier {
  LicenseController({LicenseApi? api}) : _api = api ?? LicenseApi();

  static const String _kToken = 'license.token';
  static const String _kDevice = 'license.deviceId';
  static const String _kPlan = 'license.plan';
  static const String _kExpires = 'license.expiresAt';
  static const String _kCheck = 'license.lastCheck';

  /// 网络不通时允许离线使用的宽限期。
  static const Duration offlineGrace = Duration(days: 3);

  final LicenseApi _api;

  String? _token;
  String _deviceId = '';
  String _plan = '';
  DateTime? _expiresAt;
  DateTime? _lastCheck;
  LicenseStatus _status = LicenseStatus.unknown;
  String? _message;
  bool _busy = false;

  LicenseStatus get status => _status;
  String? get message => _message;
  bool get busy => _busy;
  String get plan => _plan;
  String get deviceId => _deviceId;
  DateTime? get expiresAt => _expiresAt;
  bool get isActive => _status == LicenseStatus.active;

  String get deviceShort =>
      _deviceId.length <= 8 ? _deviceId : _deviceId.substring(0, 8).toUpperCase();

  int get remainingDays {
    final DateTime? exp = _expiresAt;
    if (exp == null) return 0;
    final int days = exp.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString(_kDevice) ?? '';
      if (_deviceId.isEmpty) {
        _deviceId = _newDeviceId();
        await prefs.setString(_kDevice, _deviceId);
      }
      _token = prefs.getString(_kToken);
      _plan = prefs.getString(_kPlan) ?? '';
      final int? expires = prefs.getInt(_kExpires);
      _expiresAt =
          expires == null ? null : DateTime.fromMillisecondsSinceEpoch(expires);
      final int? check = prefs.getInt(_kCheck);
      _lastCheck =
          check == null ? null : DateTime.fromMillisecondsSinceEpoch(check);
    } catch (_) {}

    if (!hasToken) {
      _status = LicenseStatus.inactive;
      notifyListeners();
      return;
    }

    await refresh();
  }

  Future<bool> activate(String key) {
    return _submit(() => _api.post('/api/activate', <String, dynamic>{
          'key': key.trim(),
          'device': _deviceId,
          'deviceName': _deviceName,
        }));
  }

  Future<bool> login(String username, String password) {
    return _submit(() => _api.post('/api/login', <String, dynamic>{
          'username': username.trim(),
          'password': password,
          'device': _deviceId,
          'deviceName': _deviceName,
        }));
  }

  Future<bool> register(String key, String username, String password) {
    return _submit(() => _api.post('/api/register', <String, dynamic>{
          'key': key.trim(),
          'username': username.trim(),
          'password': password,
          'device': _deviceId,
          'deviceName': _deviceName,
        }));
  }

  Future<void> refresh() async {
    if (!hasToken) {
      _status = LicenseStatus.inactive;
      notifyListeners();
      return;
    }

    try {
      final Map<String, dynamic> data =
          await _api.get('/api/license', token: _token);
      _applyServerData(data);
      _status = LicenseStatus.active;
      _message = null;
      await _persist();
    } on LicenseApiException catch (error) {
      if (error.code == 'network' || error.code == 'tls') {
        _applyOfflineGrace();
      } else {
        await _clearToken();
        _status = LicenseStatus.expired;
        _message = error.message;
      }
    } catch (error) {
      _applyOfflineGrace();
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await _clearToken();
    _status = LicenseStatus.inactive;
    _message = null;
    _plan = '';
    _expiresAt = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- 内部
  String get _deviceName {
    String name = Platform.operatingSystem;
    if (Platform.isAndroid) name = 'Android';
    if (Platform.isIOS) name = 'iOS';
    if (Platform.isWindows) name = 'Windows';
    return '$name (${_deviceId.substring(0, 6).toUpperCase()})';
  }

  String _newDeviceId() {
    final Random random = Random.secure();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 32; i += 1) {
      buffer.write(random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }

  Future<bool> _submit(Future<Map<String, dynamic>> Function() call) async {
    _busy = true;
    _message = null;
    notifyListeners();

    try {
      final Map<String, dynamic> data = await call();
      _token = data['token']?.toString();
      _applyServerData(data);
      _status = LicenseStatus.active;
      _busy = false;
      await _persist();
      notifyListeners();
      return true;
    } on LicenseApiException catch (error) {
      _busy = false;
      _message = error.message;
      notifyListeners();
      return false;
    } catch (error) {
      _busy = false;
      _message = '请求失败：$error';
      notifyListeners();
      return false;
    }
  }

  void _applyServerData(Map<String, dynamic> data) {
    final Object? plan = data['plan'];
    if (plan != null) _plan = plan.toString();

    final Object? expires = data['expiresAt'];
    if (expires is num) {
      _expiresAt = DateTime.fromMillisecondsSinceEpoch(expires.toInt());
    }

    _lastCheck = DateTime.now();
  }

  void _applyOfflineGrace() {
    final DateTime? expires = _expiresAt;
    final DateTime? checked = _lastCheck;
    final bool withinGrace = checked == null
        ? false
        : DateTime.now().difference(checked) < offlineGrace;
    final bool notExpired =
        expires != null && expires.isAfter(DateTime.now());

    if (notExpired && withinGrace) {
      _status = LicenseStatus.active;
      _message = '当前离线，已使用本地授权（${remainingDays} 天）';
    } else {
      _status = LicenseStatus.expired;
      _message = '需要联网校验授权，请检查网络';
    }
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (hasToken) {
        await prefs.setString(_kToken, _token!);
      }
      if (_plan.isNotEmpty) await prefs.setString(_kPlan, _plan);
      if (_expiresAt != null) {
        await prefs.setInt(_kExpires, _expiresAt!.millisecondsSinceEpoch);
      }
      if (_lastCheck != null) {
        await prefs.setInt(_kCheck, _lastCheck!.millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  Future<void> _clearToken() async {
    _token = null;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kToken);
      await prefs.remove(_kExpires);
      await prefs.remove(_kCheck);
    } catch (_) {}
  }
}
