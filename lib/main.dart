import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_controller.dart';
import 'core/settings_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final AppController controller = AppController();
  final SettingsController settings = SettingsController();

  controller.init();
  settings.load();

  runApp(TideApp(controller: controller, settings: settings));
}
