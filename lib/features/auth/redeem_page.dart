import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/license/license_controller.dart';
import '../../core/license/license_scope.dart';
import '../../design/tokens.dart';
import '../../widgets/liquid_glass_container.dart';
import '../../core/app_text.dart';

/// 兑换时长：注册后没时长时进入，也可从「我的」里再次进入。
class RedeemPage extends StatefulWidget {
  const RedeemPage({super.key, this.canPop = false});

  final bool canPop;

  @override
  State<RedeemPage> createState() => _RedeemPageState();
}

class _RedeemPageState extends State<RedeemPage> {
  final TextEditingController _key = TextEditingController();

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final LicenseController license = LicenseScope.of(context);
    if (license.busy) return;
    FocusScope.of(context).unfocus();
    final bool ok = await license.redeem(_key.text);
    if (!mounted) return;
    if (ok) {
      _key.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('兑换成功，剩余 ${license.remainingDays} 天'))),
      );
      if (widget.canPop) Navigator.of(context).pop();
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
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (widget.canPop)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                  LiquidGlassContainer(
                    radius: 28,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.schedule_rounded,
                              size: 22,
                              color: colors.accent,
                            ),
                            const SizedBox(width: 8),
                            Text(AppText.t(context, 'redeem.title'), style: text.titleLarge),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppText.t(context, 'redeem.subtitle'),
                          style: text.bodySmall
                              ?.copyWith(color: colors.inkSecondary),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.35),
                            borderRadius:
                                BorderRadius.circular(TideRadii.md),
                            border: Border.all(color: colors.hairline),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _InfoRow(
                                icon: Icons.person_outline_rounded,
                                label: AppText.t(context, 'profile.account'),
                                value: license.nickname.isEmpty
                                    ? tr('未注册')
                                    : license.nickname,
                              ),
                              const SizedBox(height: 6),
                              _InfoRow(
                                icon: Icons.fingerprint_rounded,
                                label: AppText.t(context, 'profile.machineCode'),
                                value: license.deviceShort,
                              ),
                              const SizedBox(height: 6),
                              _InfoRow(
                                icon: Icons.hourglass_bottom_rounded,
                                label: AppText.t(context, 'profile.remaining'),
                                value: license.expiresAt == null
                                    ? tr('未兑换')
                                    : tr('${license.remainingDays} 天 · ${license.expiryText}'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _key,
                          textCapitalization: TextCapitalization.characters,
                          style: text.bodyMedium,
                          onSubmitted: (_) => _redeem(),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                              RegExp('[A-Za-z0-9-]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: AppText.t(context, 'redeem.key'),
                            hintText: 'FST-XXXX-XXXX-XXXX',
                            prefixIcon: Icon(
                              Icons.vpn_key_rounded,
                              size: 18,
                              color: colors.inkTertiary,
                            ),
                            filled: true,
                            fillColor: colors.surface.withValues(alpha: 0.45),
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
                              borderSide: BorderSide(
                                color: colors.accent.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                        if (license.message != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            license.message!,
                            style: text.labelSmall
                                ?.copyWith(color: colors.danger),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: license.busy ? null : _redeem,
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.accent,
                              foregroundColor: onAccent(colors.accent),
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(TideRadii.md),
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
                                : Text(AppText.t(context, 'redeem.action')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: colors.inkTertiary),
        const SizedBox(width: 6),
        Text(label, style: text.labelSmall?.copyWith(color: colors.inkTertiary)),
        const Spacer(),
        Text(
          value,
          style: text.labelMedium?.copyWith(color: colors.ink),
        ),
      ],
    );
  }
}
