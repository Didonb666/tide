import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_controller.dart';
import '../../core/app_scope.dart';
import '../../core/page_transitions.dart';
import '../../core/profile.dart';
import '../../design/tokens.dart';
import '../../widgets/liquid_profile_card.dart';
import 'import_sheet.dart';
import 'profile_detail_page.dart';
import '../../widgets/liquid_glass_container.dart';

class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key});

  Future<void> _pickAvatar(
    BuildContext context,
    AppController controller,
    Profile profile,
  ) async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (file == null) return;
      await controller.updateAvatar(profile.id, file.path);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更换头像失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppController c = AppScope.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                TideSpace.page,
                TideSpace.x2,
                TideSpace.x1,
                TideSpace.x1,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text('配置', style: text.displaySmall)),
                  IconButton(
                    onPressed: () => _import(context, c),
                    icon: const Icon(Icons.add_rounded),
                    tooltip: '导入配置',
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                TideSpace.page,
                0,
                TideSpace.page,
                TideSpace.x2,
              ),
              child: Text(
                '点击头像换图 · 长按卡片设为当前',
                style: text.labelSmall,
              ),
            ),
          ),
          if (c.profiles.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text('还没有配置，点右上角 + 导入', style: text.bodySmall),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: c.profiles.length,
              itemBuilder: (BuildContext context, int index) {
                final Profile p = c.profiles[index];
                return LiquidProfileCard(
                  profile: p,
                  index: index,
                  active: p.id == c.activeProfileId,
                  heroTag: 'hero-profiles-${p.id}',
                  onAvatarTap: () => _pickAvatar(context, c, p),
                  onLongPress: () {
                    c.selectProfile(p.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已设为当前配置：${p.name}')),
                    );
                  },
                  onTap: () {
                    Navigator.of(context).push<void>(
                      tideRoute<void>(
                        ProfileDetailPage(
                          profile: p,
                          heroTag: 'hero-profiles-${p.id}',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context, AppController c) async {
    final Profile? created = await showImportSheet(context, c);
    if (created == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导入：${created.name}')),
    );
  }
}
