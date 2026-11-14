import 'package:flutter/material.dart';

import '../../core/app_text.dart';
import '../../core/license/license_controller.dart';
import '../../core/license/license_scope.dart';
import '../../design/tokens.dart';
import '../../widgets/liquid_glass_container.dart';

/// 进入 App 的第一步：注册 / 登录（不含卡密，卡密在兑换页用）。
class ActivatePage extends StatefulWidget {
  const ActivatePage({super.key});

  @override
  State<ActivatePage> createState() => _ActivatePageState();
}

class _ActivatePageState extends State<ActivatePage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _pass = TextEditingController();

  bool _register = true;

  @override
  void dispose() {
    _name.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final LicenseController license = LicenseScope.of(context);
    if (license.busy) return;
    FocusScope.of(context).unfocus();
    if (_register) {
      await license.signUp(_name.text, _pass.text);
    } else {
      await license.login(_name.text, _pass.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LicenseController license = LicenseScope.of(context);
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

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
                          Icons.shield_moon_rounded,
                          size: 22,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppText.t(context, 'auth.title'),
                          style: text.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppText.t(
                        context,
                        _register ? 'auth.registerHint' : 'auth.loginHint',
                      ),
                      style: text.bodySmall?.copyWith(
                        color: colors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Segment(
                      left: AppText.t(context, 'auth.register'),
                      right: AppText.t(context, 'auth.login'),
                      leftActive: _register,
                      onLeft: () => setState(() => _register = true),
                      onRight: () => setState(() => _register = false),
                    ),
                    const SizedBox(height: 16),
                    _Field(
                      controller: _name,
                      label: AppText.t(context, 'auth.nickname'),
                      hint: _register ? '例如 Asuna' : '已注册的昵称',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _pass,
                      label: AppText.t(context, 'auth.password'),
                      hint: _register ? '至少 6 位' : '••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: true,
                    ),
                    if (license.message != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Text(
                        license.message!,
                        style: text.labelSmall?.copyWith(color: colors.danger),
                      ),
                    ],
                    const SizedBox(height: 16),
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
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                AppText.t(
                                  context,
                                  _register ? 'auth.register' : 'auth.login',
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _register = !_register),
                        child: Text(
                          AppText.t(
                            context,
                            _register ? 'auth.toLogin' : 'auth.toRegister',
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${AppText.t(context, 'profile.machineCode')} · ${license.deviceShort}',
                        style: text.labelSmall?.copyWith(
                          color: colors.inkTertiary,
                        ),
                      ),
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

class _Segment extends StatelessWidget {
  const _Segment({
    required this.left,
    required this.right,
    required this.leftActive,
    required this.onLeft,
    required this.onRight,
  });

  final String left;
  final String right;
  final bool leftActive;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    Widget item(String label, bool active, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  active ? colors.accent.withOpacity(0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(TideRadii.md),
              border: Border.all(
                color:
                    active ? colors.accent.withOpacity(0.55) : colors.hairline,
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
        item(left, leftActive, onLeft),
        const SizedBox(width: 10),
        item(right, !leftActive, onRight),
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
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(TideRadii.md),
          borderSide: BorderSide(color: color),
        );

    return TextField(
      controller: controller,
      obscureText: obscure,
      style: text.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: colors.inkTertiary),
        filled: true,
        fillColor: colors.surface.withOpacity(0.45),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: border(colors.hairline),
        enabledBorder: border(colors.hairline),
        focusedBorder: border(colors.accent.withOpacity(0.7)),
      ),
    );
  }
}
