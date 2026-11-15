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


  static String _lang = 'zh';

  /// 由 LocaleController 在语言变化时调用。
  static void setLang(String code) {
    _lang = code;
  }

  static String get lang => _lang;

  /// 免 context 的翻译入口：`tr('连接状态')`。
  /// 没收录的字符串会原样返回中文，不会报错。
  static String tr(String zh) {
    if (_lang == 'zh') return zh;
    final Map<String, String>? item = _byZh[zh];
    return item?[_lang] ?? zh;
  }

  /// 中文原文 → 其它语言
  static const Map<String, Map<String, String>> _byZh =
      <String, Map<String, String>>{
    '连接状态': {'en': 'Status', 'it': 'Stato', 'ru': 'Статус'},
    '协议': {'en': 'Protocol', 'it': 'Protocollo', 'ru': 'Протокол'},
    '地址': {'en': 'Address', 'it': 'Indirizzo', 'ru': 'Адрес'},
    '上行': {'en': 'Upload', 'it': 'Caricamento', 'ru': 'Отдача'},
    '下行': {'en': 'Download', 'it': 'Download', 'ru': 'Загрузка'},
    '规则': {'en': 'Rules', 'it': 'Regole', 'ru': 'Правила'},
    '查看': {'en': 'View', 'it': 'Apri', 'ru': 'Открыть'},
    '当前': {'en': 'Active', 'it': 'Attivo', 'ru': 'Активен'},
    '取消': {'en': 'Cancel', 'it': 'Annulla', 'ru': 'Отмена'},
    '确定': {'en': 'OK', 'it': 'OK', 'ru': 'ОК'},
    '保存': {'en': 'Save', 'it': 'Salva', 'ru': 'Сохранить'},
    '删除': {'en': 'Delete', 'it': 'Elimina', 'ru': 'Удалить'},
    '编辑': {'en': 'Edit', 'it': 'Modifica', 'ru': 'Изменить'},
    '粘贴': {'en': 'Paste', 'it': 'Incolla', 'ru': 'Вставить'},
    '文件': {'en': 'File', 'it': 'File', 'ru': 'Файл'},
    '扫码导入': {'en': 'Scan to import', 'it': 'Scansiona', 'ru': 'Сканировать'},
    '选择节点': {'en': 'Select node', 'it': 'Scegli nodo', 'ru': 'Выбрать узел'},
    '未选择': {'en': 'Not selected', 'it': 'Non selezionato', 'ru': 'Не выбрано'},
    '未选择节点': {'en': 'No node selected', 'it': 'Nessun nodo', 'ru': 'Узел не выбран'},
    '断开': {'en': 'Disconnect', 'it': 'Disconnetti', 'ru': 'Отключить'},
    '已断开': {'en': 'Disconnected', 'it': 'Disconnesso', 'ru': 'Отключено'},
    '正在断开': {'en': 'Disconnecting', 'it': 'Disconnessione', 'ru': 'Отключение'},
    '已连接': {'en': 'Connected', 'it': 'Connesso', 'ru': 'Подключено'},
    '未连接': {'en': 'Disconnected', 'it': 'Non connesso', 'ru': 'Не подключено'},
    '连接中': {'en': 'Connecting', 'it': 'Connessione', 'ru': 'Подключение'},
    '失败': {'en': 'Failed', 'it': 'Errore', 'ru': 'Ошибка'},
    '全局': {'en': 'Global', 'it': 'Globale', 'ru': 'Глобально'},
    '直连': {'en': 'Direct', 'it': 'Diretto', 'ru': 'Напрямую'},
    '已启动': {'en': 'Started', 'it': 'Avviato', 'ru': 'Запущено'},
    '已拒绝': {'en': 'Rejected', 'it': 'Rifiutato', 'ru': 'Отклонено'},
    '日志': {'en': 'Logs', 'it': 'Log', 'ru': 'Журнал'},
    '搜索日志': {'en': 'Search logs', 'it': 'Cerca nei log', 'ru': 'Поиск в журнале'},
    '暂无匹配的日志': {'en': 'No matching logs', 'it': 'Nessun log corrispondente', 'ru': 'Совпадений нет'},
    '连接后会在这里看到实时日志': {'en': 'Live logs appear after connecting', 'it': 'I log compaiono dopo la connessione', 'ru': 'Журнал появится после подключения'},
    '全部': {'en': 'All', 'it': 'Tutti', 'ru': 'Все'},
    '清空': {'en': 'Clear', 'it': 'Pulisci', 'ru': 'Очистить'},
    '复制': {'en': 'Copy', 'it': 'Copia', 'ru': 'Копировать'},
    '关闭': {'en': 'Close', 'it': 'Chiudi', 'ru': 'Закрыть'},
    '知道了': {'en': 'Got it', 'it': 'Ho capito', 'ru': 'Понятно'},
    '我知道了': {'en': 'Got it', 'it': 'Ho capito', 'ru': 'Понятно'},
    '2 小时内不再提醒': {'en': 'Mute for 2 hours', 'it': 'Silenzia 2 ore', 'ru': 'Не напоминать 2 часа'},
    '主题': {'en': 'Theme', 'it': 'Tema', 'ru': 'Тема'},
    '主色调': {'en': 'Accent color', 'it': 'Colore', 'ru': 'Акцент'},
    '刷新率': {'en': 'Refresh rate', 'it': 'Frequenza', 'ru': 'Частота'},
    '启动时自动连接': {'en': 'Auto connect on launch', 'it': 'Connessione automatica', 'ru': 'Автоподключение'},
    '详细日志': {'en': 'Verbose logs', 'it': 'Log dettagliati', 'ru': 'Подробный журнал'},
    '恢复默认': {'en': 'Restore defaults', 'it': 'Ripristina', 'ru': 'Сбросить'},
    '全部恢复默认': {'en': 'Restore all defaults', 'it': 'Ripristina tutto', 'ru': 'Сбросить всё'},
    '统一背景': {'en': 'Shared background', 'it': 'Sfondo comune', 'ru': 'Общий фон'},
    '竖屏背景': {'en': 'Portrait background', 'it': 'Sfondo verticale', 'ru': 'Портретный фон'},
    '横屏背景': {'en': 'Landscape background', 'it': 'Sfondo orizzontale', 'ru': 'Ландшафтный фон'},
    '背景透明度': {'en': 'Background opacity', 'it': 'Opacità sfondo', 'ru': 'Прозрачность фона'},
    '背景模糊度': {'en': 'Background blur', 'it': 'Sfocatura sfondo', 'ru': 'Размытие фона'},
    '雪花数量': {'en': 'Snow amount', 'it': 'Quantità neve', 'ru': 'Количество снега'},
    '雪花大小': {'en': 'Snow size', 'it': 'Dimensione neve', 'ru': 'Размер снега'},
    '雪花速度': {'en': 'Snow speed', 'it': 'Velocità neve', 'ru': 'Скорость снега'},
    '公告': {'en': 'Announcement', 'it': 'Avvisi', 'ru': 'Объявления'},
    '官方公告': {'en': 'Announcement', 'it': 'Avvisi', 'ru': 'Объявления'},
    '关于': {'en': 'About', 'it': 'Informazioni', 'ru': 'О программе'},
    '版本': {'en': 'Version', 'it': 'Versione', 'ru': 'Версия'},
    '外观': {'en': 'Appearance', 'it': 'Aspetto', 'ru': 'Внешний вид'},
    '性能': {'en': 'Performance', 'it': 'Prestazioni', 'ru': 'Производительность'},
    '背景设置': {'en': 'Background', 'it': 'Sfondo', 'ru': 'Фон'},
    '行为': {'en': 'Behaviour', 'it': 'Comportamento', 'ru': 'Поведение'},
    '语言': {'en': 'Language', 'it': 'Lingua', 'ru': 'Язык'},
    '通用': {'en': 'General', 'it': 'Generale', 'ru': 'Общие'},
    '账号': {'en': 'Account', 'it': 'Account', 'ru': 'Аккаунт'},
    '机器码': {'en': 'Device ID', 'it': 'ID dispositivo', 'ru': 'ID устройства'},
    '剩余': {'en': 'Remaining', 'it': 'Rimanente', 'ru': 'Осталось'},
    '未兑换': {'en': 'Not redeemed', 'it': 'Non riscattato', 'ru': 'Не активировано'},
    '未注册': {'en': 'Not registered', 'it': 'Non registrato', 'ru': 'Не зарегистрирован'},
    '昵称': {'en': 'Nickname', 'it': 'Nickname', 'ru': 'Никнейм'},
    '密码': {'en': 'Password', 'it': 'Password', 'ru': 'Пароль'},
    '注册': {'en': 'Sign up', 'it': 'Registrati', 'ru': 'Регистрация'},
    '登录': {'en': 'Sign in', 'it': 'Accedi', 'ru': 'Вход'},
    '退出登录': {'en': 'Sign out', 'it': 'Esci', 'ru': 'Выйти'},
    '兑换': {'en': 'Redeem', 'it': 'Riscatta', 'ru': 'Активировать'},
    '兑换时长': {'en': 'Redeem time', 'it': 'Riscatta tempo', 'ru': 'Активировать время'},
    '卡密': {'en': 'Key', 'it': 'Chiave', 'ru': 'Ключ'},
    '设置': {'en': 'Settings', 'it': 'Impostazioni', 'ru': 'Настройки'},
    '连接': {'en': 'Connect', 'it': 'Connetti', 'ru': 'Подключить'},
    '配置': {'en': 'Profiles', 'it': 'Profili', 'ru': 'Профили'},
    '我的': {'en': 'Me', 'it': 'Io', 'ru': 'Профиль'},
    '主题模式': {'en': 'Theme mode', 'it': 'Modalità tema', 'ru': 'Режим темы'},
    '快捷预设': {'en': 'Presets', 'it': 'Preset rapidi', 'ru': 'Пресеты'},
    '玻璃与雪花': {'en': 'Glass & snow', 'it': 'Vetro e neve', 'ru': 'Стекло и снег'},
    '自定义主色调': {'en': 'Custom accent', 'it': 'Colore personalizzato', 'ru': 'Свой акцент'},
    'HSV 调色板 / Hue 滑条 / Hex 输入': {'en': 'HSV picker / Hue slider / Hex input', 'it': 'Selettore HSV / Hue / Hex', 'ru': 'HSV-палитра / Hue / Hex'},
    'Fstool · 内核：mihomo': {'en': 'Fstool · core: mihomo', 'it': 'Fstool · core: mihomo', 'ru': 'Fstool · ядро: mihomo'},
    '切换后立即使用新节点连接': {'en': 'Switching applies immediately', 'it': 'Il cambio è immediato', 'ru': 'Смена применяется сразу'},
    '内核 mihomo v1.19.33': {'en': 'Core mihomo v1.19.33', 'it': 'Core mihomo v1.19.33', 'ru': 'Ядро mihomo v1.19.33'},
    '还没有配置，点右上角 + 导入': {'en': 'No profiles yet. Tap + to import.', 'it': 'Nessun profilo. Tocca + per importare.', 'ru': 'Нет профилей. Нажмите + для импорта.'},
    '帧率': {'en': 'Frame rate', 'it': 'FPS', 'ru': 'Частота кадров'},
    '实测帧率': {'en': 'Measured FPS', 'it': 'FPS misurati', 'ru': 'Измеренный FPS'},
    '不可用': {'en': 'Unavailable', 'it': 'Non disponibile', 'ru': 'Недоступно'},
    '低': {'en': 'Low', 'it': 'Bassa', 'ru': 'Низкая'},
    '中': {'en': 'Medium', 'it': 'Media', 'ru': 'Средняя'},
    '高': {'en': 'High', 'it': 'Alta', 'ru': 'Высокая'},
    '开启': {'en': 'On', 'it': 'Acceso', 'ru': 'Вкл.'},
    '浅色': {'en': 'Light', 'it': 'Chiaro', 'ru': 'Светлая'},
    '深色': {'en': 'Dark', 'it': 'Scuro', 'ru': 'Тёмная'},
    '跟随系统': {'en': 'System', 'it': 'Sistema', 'ru': 'Системная'},
    '极客绿': {'en': 'Geek green', 'it': 'Verde geek', 'ru': 'Гик-зелёный'},
    'Telegram 蓝': {'en': 'Telegram blue', 'it': 'Blu Telegram', 'ru': 'Синий Telegram'},
    '赛博紫': {'en': 'Cyber purple', 'it': 'Viola cyber', 'ru': 'Кибер-фиолетовый'},
    '落日橙': {'en': 'Sunset orange', 'it': 'Arancio tramonto', 'ru': 'Закатный оранжевый'},
    '霓虹玫红': {'en': 'Neon rose', 'it': 'Rosa neon', 'ru': 'Неоново-розовый'},
    '纯白': {'en': 'Pure white', 'it': 'Bianco puro', 'ru': 'Чистый белый'},
    '点击头像换图 · 长按卡片设为当前': {'en': 'Tap avatar to change · long press to select', 'it': 'Tocca avatar · tieni premuto per selezionare', 'ru': 'Нажмите аватар · удерживайте для выбора'},
    '当前节点': {'en': 'Current node', 'it': 'Nodo attuale', 'ru': 'Текущий узел'},
    '节点': {'en': 'Node', 'it': 'Nodo', 'ru': 'Узел'},
    '延时': {'en': 'Latency', 'it': 'Latenza', 'ru': 'Задержка'},
    '测速': {'en': 'Speed test', 'it': 'Speed test', 'ru': 'Скорость'},
    '更多': {'en': 'More', 'it': 'Altro', 'ru': 'Ещё'},
    '导入': {'en': 'Import', 'it': 'Importa', 'ru': 'Импорт'},
    '订阅': {'en': 'Subscription', 'it': 'Abbonamento', 'ru': 'Подписка'},
    '更新': {'en': 'Update', 'it': 'Aggiorna', 'ru': 'Обновить'},
    '删除配置': {'en': 'Delete profile', 'it': 'Elimina profilo', 'ru': 'Удалить профиль'},
    '设为当前': {'en': 'Set active', 'it': 'Imposta attivo', 'ru': 'Сделать активным'},
    '校验失败': {'en': 'Check failed', 'it': 'Verifica fallita', 'ru': 'Проверка не удалась'},
    '当前平台没有原生隧道实现': {'en': 'No native tunnel on this platform', 'it': 'Nessun tunnel nativo', 'ru': 'Нет нативного туннеля'},
    '导入配置': {'en': 'Import profile', 'it': 'Importa profilo', 'ru': 'Импорт профиля'},
    '订阅地址': {'en': 'Subscription URL', 'it': 'URL abbonamento', 'ru': 'URL подписки'},
    '屏幕刷新率': {'en': 'Screen refresh rate', 'it': 'Frequenza schermo', 'ru': 'Частота экрана'},
    '实测帧率：采集中…': {'en': 'Measured FPS: sampling…', 'it': 'FPS misurati: campionamento…', 'ru': 'Измеренный FPS: сбор…'},
    '还没有选择配置': {'en': 'No profile selected', 'it': 'Nessun profilo selezionato', 'ru': 'Профиль не выбран'},
    '未发现 rules 段': {'en': 'No rules section found', 'it': 'Sezione rules assente', 'ru': 'Раздел rules не найден'},
    '已保存原文，连接时交给内核解析': {'en': 'Saved as-is; core parses on connect', 'it': 'Salvato così; il core analizza alla connessione', 'ru': 'Сохранено; ядро разберёт при подключении'},
    '简体中文': {'en': '简体中文', 'it': '简体中文', 'ru': '简体中文'},
    '内置专线': {'en': 'Built-in line', 'it': 'Linea integrata', 'ru': 'Встроенная линия'},
    '处理中…': {'en': 'Processing…', 'it': 'Elaborazione…', 'ru': 'Обработка…'},
    '刚刚': {'en': 'Just now', 'it': 'Adesso', 'ru': 'Только что'},
    '断开中': {'en': 'Disconnecting', 'it': 'Disconnessione', 'ru': 'Отключение'},
    '请先注册或登录': {'en': 'Please sign up or sign in', 'it': 'Registrati o accedi', 'ru': 'Сначала зарегистрируйтесь'},
    '需要联网校验授权，请检查网络': {'en': 'Online check required. Check network.', 'it': 'Verifica online richiesta. Controlla la rete.', 'ru': 'Нужна проверка онлайн. Проверьте сеть.'},
    '演示模式：未接入内核': {'en': 'Demo mode: core not attached', 'it': 'Modalità demo: core non collegato', 'ru': 'Демо: ядро не подключено'},
    '正在建立隧道…': {'en': 'Establishing tunnel…', 'it': 'Creazione tunnel…', 'ru': 'Установка туннеля…'},
    '已连接（桌面演示模式，未启动内核）': {'en': 'Connected (desktop demo, core off)', 'it': 'Connesso (demo desktop, core off)', 'ru': 'Подключено (демо, ядро выкл.)'},
    '正在断开…': {'en': 'Disconnecting…', 'it': 'Disconnessione…', 'ru': 'Отключение…'},
    '连接失败': {'en': 'Connection failed', 'it': 'Connessione fallita', 'ru': 'Ошибка подключения'},
    '例如 Asuna': {'en': 'e.g. Asuna', 'it': 'es. Asuna', 'ru': 'напр. Asuna'},
    '已注册的昵称': {'en': 'Registered nickname', 'it': 'Nickname registrato', 'ru': 'Зарегистрированный никнейм'},
    '至少 6 位': {'en': 'At least 6 characters', 'it': 'Almeno 6 caratteri', 'ru': 'Минимум 6 символов'},
    '已是最新': {'en': 'Up to date', 'it': 'Aggiornato', 'ru': 'Актуально'},
    '断开中…': {'en': 'Disconnecting…', 'it': 'Disconnessione…', 'ru': 'Отключение…'},
    '已代理': {'en': 'Proxied', 'it': 'In proxy', 'ru': 'Через прокси'},
    '演示数据': {'en': 'Demo data', 'it': 'Dati demo', 'ru': 'Демо-данные'},
    '还没有匹配的日志': {'en': 'No matching logs', 'it': 'Nessun log corrispondente', 'ru': 'Совпадений нет'},
    '连接后会在这里看到实时连接': {'en': 'Live connection appears here', 'it': 'La connessione appare qui', 'ru': 'Подключение появится здесь'},
    'Clash 配置': {'en': 'Clash profile', 'it': 'Profilo Clash', 'ru': 'Профиль Clash'},
    '请输入订阅地址': {'en': 'Enter subscription URL', 'it': 'Inserisci URL abbonamento', 'ru': 'Введите URL подписки'},
    '内容超过 5MB': {'en': 'Content exceeds 5MB', 'it': 'Contenuto oltre 5MB', 'ru': 'Содержимое больше 5MB'},
    '内容为空': {'en': 'Content is empty', 'it': 'Contenuto vuoto', 'ru': 'Пустое содержимое'},
    '粘贴 / 编辑 YAML': {'en': 'Paste / edit YAML', 'it': 'Incolla / modifica YAML', 'ru': 'Вставить / изменить YAML'},
    '从剪贴板粘贴': {'en': 'Paste from clipboard', 'it': 'Incolla dagli appunti', 'ru': 'Вставить из буфера'},
    '输入 URL，下载后导入': {'en': 'Enter URL, download and import', 'it': 'Inserisci URL e importa', 'ru': 'Введите URL и импортируйте'},
    '本地文件': {'en': 'Local file', 'it': 'File locale', 'ru': 'Локальный файл'},
    '选择 .yaml / .yml / .txt 文件': {'en': 'Pick .yaml / .yml / .txt', 'it': 'Scegli .yaml / .yml / .txt', 'ru': 'Выберите .yaml / .yml / .txt'},
    '配置名称（可选）': {'en': 'Profile name (optional)', 'it': 'Nome profilo (opzionale)', 'ru': 'Имя профиля (необязательно)'},
    'YAML 内容': {'en': 'YAML content', 'it': 'Contenuto YAML', 'ru': 'Содержимое YAML'},
    '订阅 URL': {'en': 'Subscription URL', 'it': 'URL abbonamento', 'ru': 'URL подписки'},
    '下载并导入': {'en': 'Download and import', 'it': 'Scarica e importa', 'ru': 'Скачать и импортировать'},
    '配置详情': {'en': 'Profile details', 'it': 'Dettagli profilo', 'ru': 'Детали профиля'},
    '策略组': {'en': 'Proxy groups', 'it': 'Gruppi proxy', 'ru': 'Группы прокси'},
    '规则集': {'en': 'Rule sets', 'it': 'Set di regole', 'ru': 'Наборы правил'},
    '还没有策略组数据': {'en': 'No proxy groups yet', 'it': 'Nessun gruppo proxy', 'ru': 'Групп пока нет'},
    '天': {'en': ' days', 'it': ' giorni', 'ru': ' дн.'},
    '到期': {'en': 'expires', 'it': 'scade', 'ru': 'истекает'},
    '已导入': {'en': 'Imported: ', 'it': 'Importato: ', 'ru': 'Импортировано: '},
    '操作失败': {'en': 'Operation failed: ', 'it': 'Operazione fallita: ', 'ru': 'Ошибка операции: '},
    '请求失败': {'en': 'Request failed: ', 'it': 'Richiesta fallita: ', 'ru': 'Ошибка запроса: '},
    '读取文件失败': {'en': 'Read failed: ', 'it': 'Lettura fallita: ', 'ru': 'Ошибка чтения: '},
    '下载失败': {'en': 'Download failed: ', 'it': 'Download fallito: ', 'ru': 'Ошибка загрузки: '},
    '更换头像失败': {'en': 'Avatar update failed: ', 'it': 'Aggiornamento avatar fallito: ', 'ru': 'Не удалось обновить аватар: '},
    '选择雪花图片失败': {'en': 'Snow image failed: ', 'it': 'Immagine neve fallita: ', 'ru': 'Не удалось выбрать снежинку: '},
    '最多': {'en': 'Max ', 'it': 'Max ', 'ru': 'Макс. '},
    '个字': {'en': ' chars', 'it': ' caratteri', 'ru': ' симв.'},
    '分钟前': {'en': ' min ago', 'it': ' min fa', 'ru': ' мин назад'},
    '小时前': {'en': ' h ago', 'it': ' h fa', 'ru': ' ч назад'},
    '天前': {'en': ' d ago', 'it': ' g fa', 'ru': ' дн. назад'},
    '已设为当前配置': {'en': 'Set as active: ', 'it': 'Impostato attivo: ', 'ru': 'Активный профиль: '},
    '已导入：': {'en': 'Imported: ', 'it': 'Importato: ', 'ru': 'Импортировано: '},
    '演示模式（未连接内核）': {'en': 'Demo mode (core not connected)', 'it': 'Modalità demo (core non connesso)', 'ru': 'Демо (ядро не подключено)'},
    '已连接（演示模式，未启动内核）': {'en': 'Connected (demo, core not started)', 'it': 'Connesso (demo, core spento)', 'ru': 'Подключено (демо, ядро выкл.)'},
  };

  static String t(BuildContext context, String key) {
    final LocaleController? controller = LocaleScope.maybeOf(context);
    final String lang = controller?.code ?? 'zh';
    final Map<String, String>? entry = _data[key] ?? _more[key];
    if (entry == null) return key;
    return entry[lang] ?? entry['zh'] ?? key;
  }
}

/// 顶层快捷入口，任何地方都能直接用：tr('连接状态')
String tr(String zh) => AppText.tr(zh);
