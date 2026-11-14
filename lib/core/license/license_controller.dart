import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'license_api.dart';

/// unknown  = 启动中
/// active   = 已登录且有剩余时长
/// noTime   = 已注册但没兑换（或已到期）
/// expired  = 令牌失效，需要重新激活/登录
/// inactive = 未登录
enum LicenseStatus { unknown, active, noTime, expired, inactive }

/// 授权 + 账号状态：机器码注册、卡密兑换、昵称简介、剩余时长。
class LicenseController extends ChangeNotifier {
  LicenseController({LicenseApi? api}) : _api = api ?? LicenseApi();

  static const String _kToken = 'license.token';
  static const String _kDevice = 'license.deviceId';
  static const String _kPlan = 'license.plan';
  static const String _kExpires = 'license.expiresAt';
  static const String _kCheck = 'license.lastCheck';
  static const String _kUsername = 'license.username';
  static const String _kNickname = 'license.nickname';
  static const String _kBio = 'license.bio';

  static const Duration offlineGrace = Duration(days: 3);

  final LicenseApi _api;

  String? _token;
  String _deviceId = '';
  String _plan = '';
  String _username = '';
  String _nickname = '';
  String _bio = '';
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
  String get username => _username;
  String get nickname => _nickname.isEmpty ? _username : _nickname;
  String get bio => _bio;
  DateTime? get expiresAt => _expiresAt;

  bool get isActive => _status == LicenseStatus.active;
  bool get isLoggedIn => hasToken;
  bool get hasTime =>
      _expiresAt != null && _expiresAt!.isAfter(DateTime.now());

  String get deviceShort => _deviceId.length <= 8
      ? _deviceId.toUpperCase()
      : _deviceId.substring(0, 8).toUpperCase();

  int get remainingDays {
    final DateTime? exp = _expiresAt;
    if (exp == null) return 0;
    final int days = exp.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  String get expiryText {
    final DateTime? exp = _expiresAt;
    if (exp == null) return '未兑换';
    final String y = exp.year.toString();
    final String m = exp.month.toString().padLeft(2, '0');
    final String d = exp.day.toString().padLeft(2, '0');
    return '$y-$m-$d 到期';
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
      _username = prefs.getString(_kUsername) ?? '';
      _nickname = prefs.getString(_kNickname) ?? '';
      _bio = prefs.getString(_kBio) ?? '';
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

  /// 机器码一键注册（无需卡密，注册后进入兑换页）。
  Future<bool> quickRegister(String nickname) {
    return _submit(() => _api.post('/api/quick-register', <String, dynamic>{
          'device': _deviceId,
          'deviceName': _deviceName,
          'nickname': nickname.trim(),
        }));
  }

  /// 直接卡密激活（不进账号体系，只绑定设备）。
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

  /// 兑换时长（登录后使用）。
  Future<bool> redeem(String key) async {
    if (!hasToken) {
      _message = '请先注册或登录';
      notifyListeners();
      return false;
    }
    return _submit(() => _api.post(
          '/api/redeem',
          <String, dynamic>{'key': key.trim()},
        ));
  }

  /// 修改昵称 / 简介。
  Future<bool> updateProfile({String? nickname, String? bio}) async {
    if (!hasToken) return false;
    try {
      final Map<String, dynamic> data =
          await _api.post('/api/profile', <String, dynamic>{
        if (nickname != null) 'nickname': nickname,
        if (bio != null) 'bio': bio,
      }, token: _token);
      if (data['nickname'] != null) _nickname = data['nickname'].toString();
      if (data['bio'] != null) _bio = data['bio'].toString();
      await _persist();
      notifyListeners();
      return true;
    } on LicenseApiException catch (error) {
      _message = error.message;
      notifyListeners();
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> refresh() async {
    if (!hasToken) {
      _status = LicenseStatus.inactive;
      notifyListeners();
      return;
    }

    try {
      final Map<String, dynamic> data = await _withRetry(
        () => _api.get('/api/license', token: _token),
      );
      _applyServerData(data);

      if (data['valid'] == true) {
        _status = LicenseStatus.active;
        _message = null;
      } else if (data['reason'] == 'no_license') {
        _status = LicenseStatus.noTime;
        _message = null;
      } else {
        _status = LicenseStatus.noTime;
        _message = data['message']?.toString();
      }
      await _persist();
    } on LicenseApiException catch (error) {
      if (error.code == 'network' || error.code == 'tls') {
        _applyOfflineGrace();
      } else {
        await _clearToken();
        _status = LicenseStatus.expired;
        _message = error.message;
      }
    } catch (_) {
      _applyOfflineGrace();
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await _clearToken();
    _status = LicenseStatus.inactive;
    _message = null;
    _plan = '';
    _username = '';
    _nickname = '';
    _bio = '';
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
      final Map<String, dynamic> data = await _withRetry(call);
      _token = data['token']?.toString() ?? _token;
      _applyServerData(data);
      _status = hasTime ? LicenseStatus.active : LicenseStatus.noTime;
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

  /// 网络/TLS 偶发失败时自动重试一次（部分设备首次握手会失败）。
  Future<Map<String, dynamic>> _withRetry(
    Future<Map<String, dynamic>> Function() call,
  ) async {
    try {
      return await call();
    } on LicenseApiException catch (error) {
      if (error.code != 'network' && error.code != 'tls') rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return await call();
    }
  }

  void _applyServerData(Map<String, dynamic> data) {
    final Object? plan = data['plan'];
    if (plan != null) _plan = plan.toString();

    if (data.containsKey('expiresAt')) {
      final Object? expires = data['expiresAt'];
      _expiresAt = expires is num
          ? DateTime.fromMillisecondsSinceEpoch(expires.toInt())
          : null;
    }

    final Object? username = data['username'];
    if (username != null) _username = username.toString();
    final Object? nickname = data['nickname'];
    if (nickname != null) _nickname = nickname.toString();
    final Object? bio = data['bio'];
    if (bio != null) _bio = bio.toString();

    _lastCheck = DateTime.now();
  }

  void _applyOfflineGrace() {
    final DateTime? expires = _expiresAt;
    final DateTime? checked = _lastCheck;
    final bool withinGrace = checked == null
        ? false
        : DateTime.now().difference(checked) < offlineGrace;
    final bool notExpired = expires != null && expires.isAfter(DateTime.now());

    if (notExpired && withinGrace) {
      _status = LicenseStatus.active;
      _message = '当前离线，已使用本地授权（$remainingDays 天）';
    } else if (notExpired) {
      _status = LicenseStatus.noTime;
      _message = '需要联网校验授权，请检查网络';
    } else {
      _status = LicenseStatus.noTime;
      _message = null;
    }
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (hasToken) await prefs.setString(_kToken, _token!);
      if (_plan.isNotEmpty) await prefs.setString(_kPlan, _plan);
      if (_username.isNotEmpty) await prefs.setString(_kUsername, _username);
      if (_nickname.isNotEmpty) await prefs.setString(_kNickname, _nickname);
      await prefs.setString(_kBio, _bio);
      if (_expiresAt != null) {
        await prefs.setInt(_kExpires, _expiresAt!.millisecondsSinceEpoch);
      } else {
        await prefs.remove(_kExpires);
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
