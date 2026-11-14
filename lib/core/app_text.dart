import 'package:flutter/widgets.dart';

import 'locale_controller.dart';

/// 轻量文案表：中文 / English / Italiano / Русский。
///
/// 用法：`AppText.t(context, 'nav.mine')`
class AppText {
  const AppText._();

  static const Map<String, Map<String, String>> _data =
      <String, Map<String, String>>{
    // 底部导航
    'nav.connect': {'zh': '连接', 'en': 'Connect', 'it': 'Connetti', 'ru': 'Подключить'},
    'nav.profiles': {'zh': '配置', 'en': 'Profiles', 'it': 'Profili', 'ru': 'Профили'},
    'nav.logs': {'zh': '日志', 'en': 'Logs', 'it': 'Log', 'ru': 'Журнал'},
    'nav.mine': {'zh': '我的', 'en': 'Me', 'it': 'Io', 'ru': 'Профиль'},

    // 无时长提示
    'banner.noTime': {
      'zh': '还没有时长？点击这里去兑换吧',
      'en': 'No time left? Tap here to redeem',
      'it': 'Nessun tempo residuo? Tocca per riscattare',
      'ru': 'Нет времени? Нажмите, чтобы активировать',
    },
    'connect.blocked': {
      'zh': '还没有可用时长，请先到「我的」兑换卡密',
      'en': 'No active time. Redeem a key in "Me" first',
      'it': 'Nessun tempo attivo. Riscatta una chiave in "Io"',
      'ru': 'Нет активного времени. Активируйте ключ в «Профиль»',
    },

    // 注册 / 登录
    'auth.title': {'zh': 'Fstool 账号', 'en': 'Fstool Account', 'it': 'Account Fstool', 'ru': 'Аккаунт Fstool'},
    'auth.register': {'zh': '注册', 'en': 'Sign up', 'it': 'Registrati', 'ru': 'Регистрация'},
    'auth.login': {'zh': '登录', 'en': 'Sign in', 'it': 'Accedi', 'ru': 'Вход'},
    'auth.nickname': {'zh': '昵称', 'en': 'Nickname', 'it': 'Nickname', 'ru': 'Никнейм'},
    'auth.password': {'zh': '密码', 'en': 'Password', 'it': 'Password', 'ru': 'Пароль'},
    'auth.registerHint': {
      'zh': '设置昵称和密码即可注册，注册后兑换卡密才能使用',
      'en': 'Pick a nickname and password. Redeem a key after signing up.',
      'it': 'Scegli nickname e password. Riscatta una chiave dopo la registrazione.',
      'ru': 'Задайте никнейм и пароль. После регистрации активируйте ключ.',
    },
    'auth.loginHint': {
      'zh': '用已注册的昵称和密码登录',
      'en': 'Sign in with your nickname and password',
      'it': 'Accedi con nickname e password',
      'ru': 'Войдите с никнеймом и паролем',
    },
    'auth.toLogin': {'zh': '已有账号？去登录', 'en': 'Have an account? Sign in', 'it': 'Hai un account? Accedi', 'ru': 'Уже есть аккаунт? Войти'},
    'auth.toRegister': {'zh': '没有账号？去注册', 'en': 'No account? Sign up', 'it': 'Nessun account? Registrati', 'ru': 'Нет аккаунта? Регистрация'},

    // 兑换
    'redeem.title': {'zh': '兑换时长', 'en': 'Redeem time', 'it': 'Riscatta tempo', 'ru': 'Активировать время'},
    'redeem.subtitle': {
      'zh': '输入卡密即可增加时长，同一张卡只能用一次',
      'en': 'Enter a key to add time. Each key works once.',
      'it': 'Inserisci una chiave per aggiungere tempo. Ogni chiave vale una volta.',
      'ru': 'Введите ключ, чтобы добавить время. Каждый ключ — один раз.',
    },
    'redeem.key': {'zh': '卡密', 'en': 'Key', 'it': 'Chiave', 'ru': 'Ключ'},
    'redeem.action': {'zh': '兑换', 'en': 'Redeem', 'it': 'Riscatta', 'ru': 'Активировать'},
    'redeem.success': {'zh': '兑换成功，剩余', 'en': 'Redeemed. Remaining', 'it': 'Riscattato. Rimanente', 'ru': 'Активировано. Осталось'},

    // 我的
    'profile.account': {'zh': '账号', 'en': 'Account', 'it': 'Account', 'ru': 'Аккаунт'},
    'profile.machineCode': {'zh': '机器码', 'en': 'Device ID', 'it': 'ID dispositivo', 'ru': 'ID устройства'},
    'profile.bio': {'zh': '主页简介', 'en': 'Bio', 'it': 'Bio', 'ru': 'О себе'},
    'profile.bioEmpty': {
      'zh': '还没有简介，点右上角编辑',
      'en': 'No bio yet. Tap edit to add one.',
      'it': 'Nessuna bio. Tocca modifica per aggiungerla.',
      'ru': 'Пока нет описания. Нажмите «изменить».',
    },
    'profile.edit': {'zh': '编辑', 'en': 'Edit', 'it': 'Modifica', 'ru': 'Изменить'},
    'profile.remaining': {'zh': '剩余时长', 'en': 'Remaining', 'it': 'Rimanente', 'ru': 'Осталось'},
    'profile.days': {'zh': '天', 'en': 'days', 'it': 'giorni', 'ru': 'дн.'},
    'profile.notRedeemed': {'zh': '未兑换', 'en': 'Not redeemed', 'it': 'Non riscattato', 'ru': 'Не активировано'},
    'profile.redeemHint': {
      'zh': '兑换卡密后才可使用',
      'en': 'Redeem a key to start using',
      'it': 'Riscatta una chiave per iniziare',
      'ru': 'Активируйте ключ, чтобы начать',
    },
    'profile.settings': {'zh': '设置', 'en': 'Settings', 'it': 'Impostazioni', 'ru': 'Настройки'},
    'profile.signOut': {'zh': '退出登录', 'en': 'Sign out', 'it': 'Esci', 'ru': 'Выйти'},
    'profile.save': {'zh': '保存', 'en': 'Save', 'it': 'Salva', 'ru': 'Сохранить'},
    'profile.cancel': {'zh': '取消', 'en': 'Cancel', 'it': 'Annulla', 'ru': 'Отмена'},

    // 设置
    'settings.language': {'zh': '语言', 'en': 'Language', 'it': 'Lingua', 'ru': 'Язык'},
    'settings.general': {'zh': '通用', 'en': 'General', 'it': 'Generale', 'ru': 'Общие'},
  };

  static String t(BuildContext context, String key) {
    final LocaleController? controller = LocaleScope.maybeOf(context);
    final String lang = controller?.code ?? 'zh';
    final Map<String, String>? entry = _data[key];
    if (entry == null) return key;
    return entry[lang] ?? entry['zh'] ?? key;
  }
}
