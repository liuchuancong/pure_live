import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';

class NavigationSettingsPage extends StatelessWidget {
  const NavigationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Get.find<SettingsService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n("navigation_display_settings"), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildTipBanner(theme),
          const SizedBox(height: 16),
          _buildGroupTitle(theme, i18n("navigation_display_settings")),
          Obx(() {
            final activeIds = settings.savedMenuIds;
            if (activeIds.isEmpty) return const SizedBox.shrink();

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
                itemCount: activeIds.length,
                onReorderItem: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex -= 1;
                  List<String> currentOrder = List.from(settings.savedMenuIds);
                  final String movedId = currentOrder.removeAt(oldIndex);
                  currentOrder.insert(newIndex, movedId);

                  settings.savedMenuIds.value = currentOrder;
                },
                itemBuilder: (context, index) {
                  final String menuId = activeIds[index];
                  final menu = HomeMenu.fromId(menuId);
                  if (menu == null) return const SizedBox.shrink();
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
                      title: Text(titleText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      leading: Icon(menuIcon, size: 22, color: theme.colorScheme.primary),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: true,
                            activeThumbColor: theme.colorScheme.primary,
                            onChanged: (bool value) => settings.toggleMenuVisibility(menu, value),
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
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary.withValues(alpha: 0.65),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
