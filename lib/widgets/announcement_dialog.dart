import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../design/tokens.dart';

/// 公告内容：改文案只改这里。
class Announcement {
  const Announcement({
    required this.title,
    required this.version,
    required this.date,
    required this.summary,
    required this.body,
  });

  final String title;
  final String version;
  final String date;
  final String summary;
  final String body;
}

const Announcement kFstoolAnnouncement = Announcement(
  title: '公告',
  version: 'v0.1.0',
  date: '2026-11-06',
  summary: '欢迎使用 Fstool，本次更新重构首页并支持节点一键切换。',
  body: '欢迎使用 Fstool。\n\n'
      '本次更新：\n'
      '· 首页布局重构，新增「当前节点」卡片，点击即可切换；\n'
      '· 新增液态玻璃视觉与雪花特效，可在「设置」中调节；\n'
      '· 内核 mihomo v1.19.33，支持 VMess / VLESS / Trojan / Shadowsocks。\n\n'
      '使用提示：\n'
      '· 在「配置」页导入自己的 Clash.Meta 订阅后即可连接；\n'
      '· 首次连接需要授权 VPN 权限。',
);

/// 公告免打扰状态：记录“静音到什么时候”。
class AnnouncementStore {
  static const String _key = 'announcement.mutedUntil';
  static const Duration _quiet = Duration(hours: 2);

  static Future<bool> shouldShow() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final int until = prefs.getInt(_key) ?? 0;
      return DateTime.now().millisecondsSinceEpoch >= until;
    } catch (_) {
      return true;
    }
  }

  static Future<void> muteForTwoHours() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _key,
        DateTime.now().add(_quiet).millisecondsSinceEpoch,
      );
    } catch (_) {}
  }
}

Future<void> showAnnouncementDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (BuildContext dialogContext) => const AnnouncementDialog(),
  );
}

/// 启动时调用：不在免打扰时间内才弹。
Future<void> maybeShowAnnouncementOnLaunch(BuildContext context) async {
  final bool show = await AnnouncementStore.shouldShow();
  if (!show || !context.mounted) return;
  await showAnnouncementDialog(context);
}

class AnnouncementDialog extends StatefulWidget {
  const AnnouncementDialog({super.key});

  @override
  State<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<AnnouncementDialog> {
  bool _muting = false;

  Future<void> _muteAndClose() async {
    if (_muting) return;
    setState(() => _muting = true);
    await AnnouncementStore.muteForTwoHours();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface.withOpacity(0.94),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.hairline),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accent.withOpacity(0.14),
                        border: Border.all(
                          color: colors.accent.withOpacity(0.25),
                        ),
                      ),
                      child: Icon(
                        Icons.campaign_rounded,
                        size: 20,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        kFstoolAnnouncement.title,
                        style: text.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Text(
                      kFstoolAnnouncement.version,
                      style: text.labelSmall?.copyWith(color: colors.accent),
                    ),
                    const SizedBox(width: 8),
                    Text(kFstoolAnnouncement.date, style: text.labelSmall),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: colors.hairline, height: 1),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: SingleChildScrollView(
                    child: Text(
                      kFstoolAnnouncement.body,
                      style: text.bodyMedium?.copyWith(height: 1.6),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _muting ? null : _muteAndClose,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.inkSecondary,
                          side: BorderSide(color: colors.hairline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(TideRadii.md),
                          ),
                        ),
                        child: Text(_muting ? '处理中…' : '2 小时内不再提醒'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(TideRadii.md),
                          ),
                        ),
                        child: const Text('我知道了'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
