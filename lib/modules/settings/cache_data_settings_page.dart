import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';

class CacheDataSettingsPage extends GetView<SettingsService> {
  const CacheDataSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(i18n("cache_and_data"))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("cache_and_data")),
          context.buildModernCard([
            Obx(() {
              final size = controller.cacheSizeMB.value;
              final turns = controller.refreshTurns.value;
              return _buildTile(
                context,
                icon: Remix.database_2_line,
                title: i18n("current_cache_size"),
                subtitle: "",
                onTap: () => controller.handleManualRefresh(),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${size.toStringAsFixed(2)} MB",
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: turns,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOutCubic,
                      child: Icon(Remix.refresh_line, size: 16, color: theme.hintColor.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              );
            }),
            _buildTile(
              context,
              icon: Remix.delete_bin_6_line,
              title: i18n("clear_all_cache"),
              subtitle: i18n("clear_all_cache_meida_desc"),
              onTap: () async {
                final ok = await Get.dialog<bool>(
                  AlertDialog(
                    title: Text(i18n("confirm_clear_cache")),
                    content: Text(i18n("confirm_clear_meida_desc")),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(Get.context!, false), child: Text(i18n("cancel"))),
                      TextButton(
                        onPressed: () => Navigator.pop(Get.context!, true),
                        child: Text(i18n("clear"), style: TextStyle(color: theme.colorScheme.error)),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await controller.clearCache();
                  Get.snackbar(i18n("done"), i18n("cache_cleared"), snackPosition: SnackPosition.bottom);
                }
              },
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
      title: Text(title, style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w600)),
      subtitle: subtitle.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: AppTextStyles.t12.copyWith(color: theme.hintColor.withValues(alpha: 0.75)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: theme.hintColor.withValues(alpha: 0.4), size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }
}
