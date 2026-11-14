import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_text.dart';

/// 支持的界面语言。
enum AppLanguage { zh, en, it, ru }

extension AppLanguageInfo on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.zh:
        return 'zh';
      case AppLanguage.en:
        return 'en';
      case AppLanguage.it:
        return 'it';
      case AppLanguage.ru:
        return 'ru';
    }
  }

  String get label {
    switch (this) {
      case AppLanguage.zh:
        return tr('简体中文');
      case AppLanguage.en:
        return 'English';
      case AppLanguage.it:
        return 'Italiano';
      case AppLanguage.ru:
        return 'Русский';
    }
  }

  Locale get locale => Locale(code);
}

class LocaleController extends ChangeNotifier {
  static const String _key = 'settings.language';

  AppLanguage _language = AppLanguage.zh;

  AppLanguage get language => _language;
  Locale get locale => _language.locale;
  String get code => _language.code;

  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString(_key);
      if (saved != null) {
        for (final AppLanguage item in AppLanguage.values) {
          if (item.code == saved) _language = item;
        }
      }
    } catch (_) {}
    AppText.setLang(_language.code);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    AppText.setLang(language.code);
    notifyListeners();
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, language.code);
    } catch (_) {}
  }
}

class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.notifier;
  }

  static LocaleController of(BuildContext context) {
    final LocaleController? controller = maybeOf(context);
    assert(controller != null, tr('找不到 LocaleScope'));
    return controller!;
  }
}
