import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/app_scope.dart';
import '../../core/profile.dart';
import '../../design/tokens.dart';
import '../../widgets/common.dart';
import 'profile_detail_page.dart';

/// 配置列表（管理态）：导入、查看、设为当前。
class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  String? _highlightId;
  Timer? _highlightTimer;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  Future<void> _import(BuildContext context) async {
    final AppController c = AppScope.of(context);
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController yamlCtrl = TextEditingController();
    String? error;

    final Profile? created = await showModalBottomSheet<Profile>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final TideColors colors = context.colors;
            return Padding(
              padding: EdgeInsets.only(
                left: TideSpace.page,
                right: TideSpace.page,
                top: TideSpace.x2,
                bottom: MediaQuery.of(context).viewInsets.bottom + TideSpace.x4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '导入 Clash.Meta 配置',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: TideSpace.x3),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      hintText: '配置名称（可选）',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: TideSpace.x3),
                  TextField(
                    controller: yamlCtrl,
                    minLines: 6,
                    maxLines: 10,
                    style: TideType.mono,
                    decoration: InputDecoration(
                      hintText: '把 YAML 粘贴到这里…\n\nproxies:\n  - name: node-1\n    type: ss\nrules:\n  - MATCH,DIRECT',
                      border: const OutlineInputBorder(),
                      errorText: error,
                    ),
                  ),
                  const SizedBox(height: TideSpace.x2),
                  Text(
                    '提示：第一阶段只保存原文并粗略估算规则数，接入内核后才会真正解析与校验。',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: TideSpace.x3),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        final String text = yamlCtrl.text.trim();
                        if (text.isEmpty) {
                          setSheetState(() => error = '内容为空，请先粘贴 YAML');
                          return;
                        }
                        final Profile p =
                            c.importProfile(text, name: nameCtrl.text);
                        Navigator.of(sheetContext).pop(p);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: TideRadii.rMd,
                        ),
                      ),
                      child: const Text('保存配置'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    yamlCtrl.dispose();

    if (!mounted || created == null) return;
    setState(() => _highlightId = created.id);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlightId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final TideColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TideSpace.page,
              TideSpace.x2,
              TideSpace.x2,
              TideSpace.x1,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text('配置', style: text.displaySmall),
                ),
                IconButton(
                  onPressed: () => _import(context),
                  icon: const Icon(Icons.add),
                  tooltip: '导入配置',
                ),
              ],
            ),
          ),
          Expanded(
            child: c.profiles.isEmpty
                ? Center(
                    child: Text('还没有配置，点右上角 + 导入', style: text.bodySmall),
                  )
                : ListView.separated(
                    itemCount: c.profiles.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const Hairline(),
                    itemBuilder: (BuildContext context, int index) {
                      final Profile p = c.profiles[index];
                      return GestureDetector(
                        onLongPress: () {
                          c.selectProfile(p.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已设为当前配置：${p.name}')),
                          );
                        },
                        child: AnimatedContainer(
                          duration: context.motion(TideMotion.base),
                          color: _highlightId == p.id
                              ? colors.accentSoft
                              : Colors.transparent,
                          child: ProfileStreamTile(
                            profile: p,
                            active: p.id == c.activeProfileId,
                            heroTag: 'hero-profiles-${p.id}',
                            onTap: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      ProfileDetailPage(
                                    profile: p,
                                    heroTag: 'hero-profiles-${p.id}',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(TideSpace.page),
            child: Text(
              '长按可设为当前配置 · 导入目前支持粘贴 YAML',
              style: text.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}
