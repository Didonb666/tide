import 'package:flutter/widgets.dart';

import 'license_controller.dart';
import '../app_text.dart';

/// 全局授权状态入口（和 AppScope / SettingsScope 同一套路）。
class LicenseScope extends InheritedNotifier<LicenseController> {
  LicenseScope({
    super.key,
    required LicenseController controller,
    required super.child,
  }) : super(notifier: controller);

  static LicenseController of(BuildContext context) {
    final LicenseScope? scope =
        context.dependOnInheritedWidgetOfExactType<LicenseScope>();
    assert(scope != null, tr('找不到 LicenseScope'));
    return scope!.notifier!;
  }

  static LicenseController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LicenseScope>()?.notifier;
  }
}
