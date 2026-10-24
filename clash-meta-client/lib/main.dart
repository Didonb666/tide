import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final AppController controller = AppController();
  // 不阻塞首帧：init 内部会探测原生通道，失败则自动降级到模拟实现。
  controller.init();

  runApp(TideApp(controller: controller));
}
