import 'package:flutter_test/flutter_test.dart';
import 'package:tide/core/profile.dart';

// 这个文件名特意用 widget_test.dart：
// `flutter create` 只在文件不存在时才生成模板测试，而模板测试会 import 一个
// 我们没有的 `MyApp`，导致 `flutter test` 直接报错。放着我们的测试就能挡住它。
void main() {
  test('estimateRuleCount 能数出块状 YAML 的规则条数', () {
    const String yaml = '''
proxies:
  - name: a
    type: ss
    server: 1.2.3.4
rules:
  - DOMAIN-SUFFIX,a.com,PROXY
  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
  - MATCH,DIRECT
''';
    expect(estimateRuleCount(yaml), 3);
  });

  test('estimateRuleCount 不会把 proxies 当规则', () {
    const String yaml = '''
proxies:
  - name: a
  - name: b
rules:
  - MATCH,DIRECT
''';
    expect(estimateRuleCount(yaml), 1);
  });
}
