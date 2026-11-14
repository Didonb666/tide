import 'package:flutter/material.dart';

import '../../core/license/license_controller.dart';
import '../../core/license/license_scope.dart';
import '../../design/tokens.dart';
import '../../widgets/liquid_glass_container.dart';

enum _Mode { key, account }

/// 授权激活页：卡密激活 / 账号登录 / 用卡密注册。
class ActivatePage extends StatefulWidget {
  const ActivatePage({super.key});

  @override
  State<ActivatePage> createState() => _ActivatePageState();
}

class _ActivatePageState extends State<ActivatePage> {
  final TextEditingController _key = TextEditingController();
  final TextEditingController _user = TextEditingController();
  final TextEditingController _pass = TextEditingController();

  _Mode _mode = _Mode.key;
  bool _register = false;

  @override
  void dispose() {
    _key.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final LicenseController license = LicenseScope.of(context);
    if (license.busy) return;
    FocusScope.of(context).unfocus();

    if (_mode == _Mode.key) {
      await license.activate(_key.text);
    } else if (_register) {
      await license.register(_key.text, _user.text, _pass.text);
    } else {
      await license.login(_user.text, _pass.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LicenseController license = LicenseScope.of(context);
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    final String subtitle;
    if (_mode == _Mode.key) {
      subtitle = '输入卡密即可激活，自动绑定当前设备';
    } else if (_register) {
      subtitle = '用一张未使用的卡密开通新账号';
    } else {
      subtitle = '使用已注册的账号登录';
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: LiquidGlassContainer(
                radius: 28,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.verified_user_rounded,
                          size: 22,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 8),
                        Text('授权 Fstool', style: text.titleLarge),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: text.bodySmall?.copyWith(
                        color: colors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ModeSwitch(
                      mode: _mode,
                      onChanged: (_Mode mode) => setState(() => _mode = mode),
                    ),
                    const SizedBox(height: 16),
                    if (_mode == _Mode.key || _register) ...<Widget>[
                      _Field(
                        controller: _key,
                        label: '卡密',
                        hint: 'FST-XXXX-XXXX-XXXX',
                        icon: Icons.vpn_key_rounded,
                        uppercase: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_mode == _Mode.account) ...<Widget>[
                      _Field(
                        controller: _user,
                        label: '账号',
                        hint: '用户名',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _pass,
                        label: '密码',
                        hint: '至少 6 位',
                        icon: Icons.lock_outline_rounded,
                        obscure: true,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              setState(() => _register = !_register),
                          child: Text(
                            _register ? '已有账号？改为登录' : '用卡密注册新账号',
                          ),
                        ),
                      ),
                    ],
                    if (license.message != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        license.message!,
                        style: text.labelSmall?.copyWith(
                          color: colors.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: license.busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: onAccent(colors.accent),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(TideRadii.md),
                          ),
                        ),
                        child: license.busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_mode == _Mode.key
                                ? '激活'
                                : (_register ? '注册并激活' : '登录')),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.fingerprint_rounded,
                          size: 14,
                          color: colors.inkTertiary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '设备标识 ${license.deviceShort}',
                            style: text.labelSmall?.copyWith(
                              color: colors.inkTertiary,
                            ),
                          ),
                        ),
                        if (license.status == LicenseStatus.expired)
                          Text(
                            '授权已过期',
                            style: text.labelSmall?.copyWith(
                              color: colors.danger,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    Widget item(String label, _Mode value) {
      final bool active = mode == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? colors.accent.withOpacity(0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(TideRadii.md),
              border: Border.all(
                color: active
                    ? colors.accent.withOpacity(0.55)
                    : colors.hairline,
              ),
            ),
            child: Text(
              label,
              style: text.labelLarge?.copyWith(
                color: active ? colors.accent : colors.inkSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        item('卡密激活', _Mode.key),
        const SizedBox(width: 10),
        item('账号登录', _Mode.account),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.uppercase = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return TextField(
      controller: controller,
      obscureText: obscure,
      textCapitalization:
          uppercase ? TextCapitalization.characters : TextCapitalization.none,
      style: text.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: colors.inkTertiary),
        filled: true,
        fillColor: colors.surface.withOpacity(0.45),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TideRadii.md),
          borderSide: BorderSide(color: colors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TideRadii.md),
          borderSide: BorderSide(color: colors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TideRadii.md),
          borderSide: BorderSide(color: colors.accent.withOpacity(0.7)),
        ),
      ),
    );
  }
}
