import 'package:flutter/material.dart';

import '../../core/license/license_api.dart';
import '../../core/license/license_controller.dart';
import '../../core/license/license_scope.dart';
import 'activate_page.dart';

/// 授权门禁：未激活时挡住主界面，只显示激活页。
///
/// 只有在编译时传了 `--dart-define=LICENSE_ENFORCE=true` 才会真正拦截，
/// 否则（默认）直接放行，方便服务端还没上线时继续开发。
class LicenseGate extends StatelessWidget {
  const LicenseGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kLicenseEnforce) return child;

    final LicenseController license = LicenseScope.of(context);

    switch (license.status) {
      case LicenseStatus.unknown:
        return const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        );
      case LicenseStatus.active:
        return child;
      case LicenseStatus.inactive:
      case LicenseStatus.expired:
        return const ActivatePage();
    }
  }
}
