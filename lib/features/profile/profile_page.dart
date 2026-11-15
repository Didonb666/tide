import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_text.dart';
import '../../core/license/license_controller.dart';
import '../../core/license/license_scope.dart';
import '../../design/tokens.dart';
import '../../widgets/liquid_glass_container.dart';
import '../settings/settings_page.dart';
import '../auth/redeem_page.dart';
import '../../core/jelly_route.dart';

/// 「我的」：头像 / 昵称 / 简介 / 剩余时长 / 兑换 / 设置入口。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String _kAvatar = 'profile.avatar';
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? path = prefs.getString(_kAvatar);
      if (!mounted) return;
      if (path != null && File(path).existsSync()) {
        setState(() => _avatarPath = path);
      }
    } catch (_) {}
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        imageQuality: 90,
      );
      if (file == null) return;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAvatar, file.path);
      if (!mounted) return;
      setState(() => _avatarPath = file.path);
    } catch (_) {}
  }

  Future<void> _editText({
    required String title,
    required String initial,
    required int maxLength,
    required ValueChanged<String> onSave,
  }) async {
    final TextEditingController controller =
        TextEditingController(text: initial);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLength: maxLength,
            autofocus: true,
            decoration: InputDecoration(hintText: '${tr('最多 ')}${maxLength}${tr(' 个字')}'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppText.t(context, 'profile.cancel')),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(AppText.t(context, 'profile.save')),
            ),
          ],
        );
      },
    );
    if (result != null) onSave(result);
  }

  @override
  Widget build(BuildContext context) {
    final LicenseController license = LicenseScope.of(context);
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    final bool hasTime = license.expiresAt != null &&
        license.expiresAt!.isAfter(DateTime.now());

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
        children: <Widget>[
          // ---------------------------------------------------------- 头像 + 简介
          LiquidGlassContainer(
            radius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: <Widget>[
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.surface.withValues(alpha: 0.45),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _avatarPath != null
                                ? Image.file(
                                    File(_avatarPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.person_rounded,
                                      color: colors.inkTertiary,
                                      size: 32,
                                    ),
                                  )
                                : Icon(
                                    Icons.person_rounded,
                                    color: colors.inkTertiary,
                                    size: 32,
                                  ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.accent,
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size: 11,
                                color: onAccent(colors.accent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          GestureDetector(
                            onTap: () => _editText(
                              title: AppText.t(context, 'auth.nickname'),
                              initial: license.nickname,
                              maxLength: 24,
                              onSave: (String value) =>
                                  license.updateProfile(nickname: value),
                            ),
                            child: Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    license.nickname.isEmpty
                                        ? AppText.t(context, 'profile.account')
                                        : license.nickname,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.titleMedium,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.edit_rounded,
                                  size: 13,
                                  color: colors.inkTertiary,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${AppText.t(context, 'profile.machineCode')} ${license.deviceShort}",
                            style: text.labelSmall
                                ?.copyWith(color: colors.inkTertiary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: colors.hairline),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: license.bio.isEmpty
                          ? Text(
                              AppText.t(context, 'profile.bioEmpty'),
                              style: text.bodySmall
                                  ?.copyWith(color: colors.inkTertiary),
                            )
                          : Text(
                              license.bio,
                              style: text.titleMedium?.copyWith(
                                height: 1.55,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                    TextButton(
                      onPressed: () => _editText(
                        title: AppText.t(context, 'profile.bio'),
                        initial: license.bio,
                        maxLength: 120,
                        onSave: (String value) =>
                            license.updateProfile(bio: value),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        AppText.t(context, 'profile.edit'),
                        style:
                            text.labelMedium?.copyWith(color: colors.accent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ---------------------------------------------------------- 时长
          LiquidGlassContainer(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.hourglass_bottom_rounded,
                      size: 16,
                      color: colors.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(AppText.t(context, 'profile.remaining'), style: text.labelMedium),
                    const Spacer(),
                    Text(
                      hasTime ? '${license.remainingDays}${tr(' 天')}' : tr('未兑换'),
                      style: text.titleMedium?.copyWith(
                        color: hasTime ? colors.accent : colors.danger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  license.expiresAt == null
                      ? AppText.t(context, 'profile.redeemHint')
                      : license.expiryText,
                  style: text.labelSmall?.copyWith(color: colors.inkTertiary),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => showRedeemDialog(context),
                    icon: const Icon(Icons.add_card_rounded, size: 18),
                    label: Text(AppText.t(context, 'redeem.title')),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: onAccent(colors.accent),
                      minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(TideRadii.md),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ---------------------------------------------------------- 设置入口
          LiquidGlassContainer(
            radius: 20,
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.settings_rounded, color: colors.accent),
                  title: Text(AppText.t(context, 'profile.settings')),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.inkTertiary,
                  ),
                  onTap: () => Navigator.of(context).push(
                    JellyPageRoute<void>(
                      builder: (_) => Scaffold(
                        backgroundColor: Colors.transparent,
                        appBar: AppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          title: Text(AppText.t(context, 'profile.settings')),
                        ),
                        body: const SettingsPage(),
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: colors.hairline),
                ListTile(
                  leading: Icon(
                    Icons.logout_rounded,
                    color: colors.inkSecondary,
                  ),
                  title: Text(AppText.t(context, 'profile.signOut')),
                  onTap: license.signOut,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'Fstool · ${license.plan.isEmpty ? 'free' : license.plan}',
              style: text.labelSmall?.copyWith(color: colors.inkTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
