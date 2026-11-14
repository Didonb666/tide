import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_controller.dart';
import 'core/background_controller.dart';
import 'core/license/license_controller.dart';
import 'core/locale_controller.dart';
import 'core/settings_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final AppController controller = AppController();
  final SettingsController settings = SettingsController();
  final BackgroundController background = BackgroundController();
  final LicenseController license = LicenseController();
  final LocaleController locale = LocaleController();

  controller.init();
  settings.load();
  background.load();
  license.load();
  locale.load();

  runApp(TideApp(
    controller: controller,
    settings: settings,
    background: background,
    license: license,
    locale: locale,
  ));
}
