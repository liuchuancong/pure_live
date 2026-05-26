import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';

class NavigationSettingsPage extends StatelessWidget {
  const NavigationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Get.find<SettingsService>();

    // 1. 定义所有菜单（固定不变）
    final allMenus = [HomeMenu.favorites, HomeMenu.popular, HomeMenu.areas, HomeMenu.record];

    return Scaffold(
      appBar: AppBar(title: Text(i18n("navigation_display_settings"))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildTipBanner(theme),
          const SizedBox(height: 16),
          context.buildGroupTitle(i18n("navigation_display_settings")),
          Obx(() {
            // 2. 关键：按 savedMenuIds 的顺序给 allMenus 排序
            final savedOrder = settings.savedMenuIds;
            // 给每个菜单一个排序权重：在 savedMenuIds 里的位置，不在里面的排到最后
            final sortedMenus = List<HomeMenu>.from(allMenus);
            sortedMenus.sort((a, b) {
              final indexA = savedOrder.indexOf(a.id);
              final indexB = savedOrder.indexOf(b.id);
              // 都在列表里：按 savedOrder 顺序排
              if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
              // 只有一个在列表里：在列表里的排前面
              if (indexA != -1) return -1;
              if (indexB != -1) return 1;
              // 都不在：保持原始顺序
              return 0;
            });

            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05), width: 0.5),
              ),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: sortedMenus.length,
                onReorderItem: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex -= 1;
                  // 拖拽时直接更新 savedMenuIds
                  final currentOrder = List<String>.from(settings.savedMenuIds);
                  final movedId = currentOrder.removeAt(oldIndex);
                  currentOrder.insert(newIndex, movedId);
                  settings.savedMenuIds.value = currentOrder;
                },
                itemBuilder: (context, index) {
                  final menu = sortedMenus[index];
                  // 开关状态直接从 savedMenuIds 判断
                  final isVisible = settings.savedMenuIds.contains(menu.id);

                  String titleText = "";
                  IconData menuIcon = Remix.question_line;
                  switch (menu) {
                    case HomeMenu.favorites:
                      titleText = i18n("favorites_title");
                      menuIcon = Icons.favorite_rounded;
                      break;
                    case HomeMenu.popular:
                      titleText = i18n("popular_title");
                      menuIcon = CustomIcons.popular;
                      break;
                    case HomeMenu.areas:
                      titleText = i18n("areas_title");
                      menuIcon = Icons.area_chart_rounded;
                      break;
                    case HomeMenu.record:
                      titleText = i18n("record_center");
                      menuIcon = Remix.download_2_fill;
                      break;
                  }

                  return Material(
                    key: ValueKey(menu.id),
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      title: Text(titleText, style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600)),
                      leading: Icon(menuIcon, size: 22, color: theme.colorScheme.primary),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: isVisible,
                            activeThumbColor: theme.colorScheme.primary,
                            onChanged: (value) => settings.toggleMenuVisibility(menu, value),
                          ),
                          const SizedBox(width: 8),
                          ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Icon(RemixIcons.sort_asc, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTipBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Remix.information_line, size: 18, color: theme.colorScheme.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              i18n('drag_menu_to_sort_tip'),
              style: AppTextStyles.t13.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
