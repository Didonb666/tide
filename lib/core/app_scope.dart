import 'package:flutter/widgets.dart';

import 'app_controller.dart';

/// 用一个 InheritedNotifier 把 Controller 传给整棵树。
/// 依赖它的 widget 会在 notifyListeners 时重建，其余部分不受影响。
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, '找不到 AppScope，请检查是否包在 TideApp 内');
    return scope!.notifier!;
  }
}
