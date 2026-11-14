import 'dart:convert';
import 'dart:io';

/// 授权服务地址。
///
/// 编译时注入：
///   flutter build apk --dart-define=LICENSE_API=https://license.你的域名.com
///
/// 不注入时用下面的默认值（占位，必须替换）。
const String kLicenseApiBase = String.fromEnvironment(
  'LICENSE_API',
  defaultValue: 'https://license.example.com',
);

/// 是否强制门禁。
///
/// 服务端还没部署时保持 false：App 正常可用，激活页只在设置里手动进入。
/// 部署完成后用 `--dart-define=LICENSE_ENFORCE=true` 构建正式包。
const bool kLicenseEnforce = bool.fromEnvironment(
  'LICENSE_ENFORCE',
  defaultValue: false,
);

/// 服务端返回的业务错误。
class LicenseApiException implements Exception {
  LicenseApiException(this.code, this.message, {this.statusCode = 0});

  final String code;
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

/// 极简 HTTP 客户端：只用 dart:io，不引第三方包。
class LicenseApi {
  LicenseApi({String? baseUrl})
      : baseUrl = (baseUrl ?? kLicenseApiBase).replaceAll(RegExp(r'/+$'), '');

  final String baseUrl;

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) {
    return _send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> get(String path, {String? token}) {
    return _send('GET', path, token: token);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);

    try {
      final Uri uri = Uri.parse('$baseUrl$path');
      final HttpClientRequest request =
          method == 'GET' ? await client.getUrl(uri) : await client.postUrl(uri);

      request.headers.set('accept', 'application/json');
      if (token != null && token.isNotEmpty) {
        request.headers.set('authorization', 'Bearer $token');
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(body)));
      }

      final HttpClientResponse response = await request.close();
      final String text = await response.transform(utf8.decoder).join();

      Map<String, dynamic> data = <String, dynamic>{};
      if (text.isNotEmpty) {
        final Object? decoded = jsonDecode(text);
        if (decoded is Map) data = decoded.cast<String, dynamic>();
      }

      if (response.statusCode >= 400) {
        throw LicenseApiException(
          data['error']?.toString() ?? 'http_${response.statusCode}',
          data['message']?.toString() ?? '请求失败（${response.statusCode}）',
          statusCode: response.statusCode,
        );
      }
      return data;
    } on LicenseApiException {
      rethrow;
    } on HandshakeException {
      throw LicenseApiException('tls', '证书校验失败，请确认服务端使用 HTTPS');
    } on SocketException catch (error) {
      throw LicenseApiException('network', '连不上授权服务器：${error.message}');
    } on HttpException catch (error) {
      throw LicenseApiException('network', '网络异常：${error.message}');
    } finally {
      client.close(force: true);
    }
  }
}
