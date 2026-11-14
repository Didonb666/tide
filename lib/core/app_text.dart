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


  /// 第二批：连接页 / 配置页 / 日志页 / 设置页
  static const Map<String, Map<String, String>> _more =
      <String, Map<String, String>>{
    'connect.status': {'zh': '连接状态', 'en': 'Status', 'it': 'Stato', 'ru': 'Статус'},
    'connect.protocol': {'zh': '协议', 'en': 'Protocol', 'it': 'Protocollo', 'ru': 'Протокол'},
    'connect.address': {'zh': '地址', 'en': 'Address', 'it': 'Indirizzo', 'ru': 'Адрес'},
    'connect.upload': {'zh': '上行', 'en': 'Upload', 'it': 'Caricamento', 'ru': 'Отдача'},
    'connect.download': {'zh': '下行', 'en': 'Download', 'it': 'Download', 'ru': 'Загрузка'},
    'connect.rules': {'zh': '规则', 'en': 'Rules', 'it': 'Regole', 'ru': 'Правила'},
    'connect.start': {'zh': '启动 VPN', 'en': 'Start VPN', 'it': 'Avvia VPN', 'ru': 'Включить VPN'},
    'connect.stop': {'zh': '停止 VPN', 'en': 'Stop VPN', 'it': 'Ferma VPN', 'ru': 'Выключить VPN'},
    'connect.connecting': {'zh': '连接中…', 'en': 'Connecting…', 'it': 'Connessione…', 'ru': 'Подключение…'},
    'connect.currentNode': {'zh': '当前节点 · 点击切换', 'en': 'Current node · tap to switch', 'it': 'Nodo attuale · tocca per cambiare', 'ru': 'Текущий узел · нажмите для смены'},
    'connect.announcement': {'zh': '官方公告', 'en': 'Announcement', 'it': 'Avvisi', 'ru': 'Объявления'},
    'connect.view': {'zh': '查看', 'en': 'View', 'it': 'Apri', 'ru': 'Открыть'},

    'profiles.title': {'zh': '配置', 'en': 'Profiles', 'it': 'Profili', 'ru': 'Профили'},
    'profiles.tip': {'zh': '点击头像换图 · 长按卡片设为当前', 'en': 'Tap avatar to change · long press to select', 'it': 'Tocca avatar per cambiare · tieni premuto per selezionare', 'ru': 'Нажмите аватар · удерживайте карточку для выбора'},
    'profiles.current': {'zh': '当前', 'en': 'Active', 'it': 'Attivo', 'ru': 'Активен'},
    'profiles.scan': {'zh': '扫码导入', 'en': 'Scan to import', 'it': 'Scansiona per importare', 'ru': 'Сканировать'},

    'logs.title': {'zh': '日志', 'en': 'Logs', 'it': 'Log', 'ru': 'Журнал'},
    'logs.empty': {'zh': '暂无日志', 'en': 'No logs yet', 'it': 'Nessun log', 'ru': 'Журнал пуст'},

    'settings.appearance': {'zh': '外观', 'en': 'Appearance', 'it': 'Aspetto', 'ru': 'Внешний вид'},
    'settings.performance': {'zh': '性能', 'en': 'Performance', 'it': 'Prestazioni', 'ru': 'Производительность'},
    'settings.background': {'zh': '背景设置', 'en': 'Background', 'it': 'Sfondo', 'ru': 'Фон'},
    'settings.behavior': {'zh': '行为', 'en': 'Behaviour', 'it': 'Comportamento', 'ru': 'Поведение'},
    'settings.about': {'zh': '关于', 'en': 'About', 'it': 'Informazioni', 'ru': 'О программе'},
    'settings.theme': {'zh': '主题', 'en': 'Theme', 'it': 'Tema', 'ru': 'Тема'},
    'settings.accent': {'zh': '主色调', 'en': 'Accent', 'it': 'Colore', 'ru': 'Акцент'},
    'settings.refresh': {'zh': '刷新率', 'en': 'Refresh rate', 'it': 'Frequenza', 'ru': 'Частота'},
    'settings.autoConnect': {'zh': '启动时自动连接', 'en': 'Auto connect on start', 'it': 'Connessione automatica', 'ru': 'Автоподключение'},
    'settings.verbose': {'zh': '详细日志', 'en': 'Verbose logs', 'it': 'Log dettagliati', 'ru': 'Подробный журнал'},
    'settings.restore': {'zh': '恢复默认', 'en': 'Restore defaults', 'it': 'Ripristina', 'ru': 'Сбросить'},
  };

  static String t(BuildContext context, String key) {
    final LocaleController? controller = LocaleScope.maybeOf(context);
    final String lang = controller?.code ?? 'zh';
    final Map<String, String>? entry = _data[key] ?? _more[key];
    if (entry == null) return key;
    return entry[lang] ?? entry['zh'] ?? key;
  }
}
