import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/iptv/iptv_page.dart';
import 'package:pure_live/modules/backup/backup_page.dart';
import 'package:pure_live/modules/settings/theme_settings_page.dart';
import 'package:pure_live/modules/settings/video_settings_page.dart';
import 'package:pure_live/modules/settings/general_settings_page.dart';
import 'package:pure_live/modules/settings/platform_settings_page.dart';
import 'package:pure_live/modules/settings/navigation_settings_page.dart';
import 'package:pure_live/modules/settings/cache_data_settings_page.dart';
import 'package:pure_live/modules/settings/player_kernel_settings_page.dart';

class SettingsPage extends GetView<SettingsService> {
  const SettingsPage({super.key});

  BuildContext get context => Get.context!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: screenWidth > 640 ? 0 : null,
        title: Text(i18n("settings_title"), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildGroupTitle(theme, i18n("theme_customization")),
          _buildModernCard(theme, [
            _buildTile(
              context,
              icon: Remix.palette_line,
              title: i18n("theme_customization"),
              subtitle: i18n("theme_customization_desc"),
              onTap: () => Get.to(() => const ThemeSettingsPage()),
            ),
          ]),

          const SizedBox(height: 20),
          _buildGroupTitle(theme, i18n("iptv_settings")),
          _buildModernCard(theme, [
            _buildTile(
              context,
              icon: Remix.tv_line,
              title: i18n("iptv_settings"),
              subtitle: i18n("manage_iptv_sources"),
              onTap: () => Get.to(() => const IptvPage()),
            ),
          ]),

          const SizedBox(height: 20),
          _buildGroupTitle(theme, i18n("video")),
          _buildModernCard(theme, [
            _buildTile(
              context,
              icon: Remix.film_line,
              title: i18n("video"),
              subtitle: i18n("video_desc"),
              onTap: () => Get.to(() => const VideoSettingsPage()),
            ),
          ]),

          const SizedBox(height: 20),
          _buildGroupTitle(theme, i18n("player_kernel")),
          _buildModernCard(theme, [
            _buildTile(
              context,
              icon: Remix.cpu_line,
              title: i18n("player_kernel"),
              subtitle: i18n("player_kernel_desc"),
              onTap: () => Get.to(() => const PlayerKernelSettingsPage()),
            ),
          ]),

          const SizedBox(height: 20),
          _buildGroupTitle(theme, i18n("general")),
          _buildModernCard(theme, [
            _buildTile(
              context,
              icon: Remix.settings_4_line,
              title: i18n("general"),
              subtitle: i18n("general_desc"),
              onTap: () => Get.to(() => const GeneralSettingsPage()),
            ),
            _buildTile(
              context,
              icon: Remix.menu_line,
              title: i18n("navigation_display_settings"),
              subtitle: i18n("navigation_display_settings_desc"),
              onTap: () => Get.to(() => NavigationSettingsPage()),
            ),
            _buildTile(
              context,
              icon: Remix.apps_2_line,
              title: i18n("platform_settings"),
              subtitle: i18n("platform_settings_desc"),
              onTap: () => Get.to(() => const PlatformSettingsPage()),
            ),
          ]),

          const SizedBox(height: 20),
          _buildGroupTitle(theme, i18n("cache_and_data")),
          _buildModernCard(theme, [
            _buildTile(
              context,
              icon: Remix.database_2_line,
              title: i18n("cache_and_data"),
              subtitle: i18n("cache_and_data_desc"),
              onTap: () => Get.to(() => const CacheDataSettingsPage()),
            ),
          ]),

          const SizedBox(height: 20),
          _buildGroupTitle(theme, i18n("create_backup")),
          _buildModernCard(theme, [
            _buildTile(
              context,
              icon: Remix.refresh_line,
              title: i18n("backup_recover"),
              subtitle: i18n("backup_recover_desc"),
              onTap: () => Get.to(() => const BackupPage()),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // 统一封装的圆角卡片
  Widget _buildModernCard(ThemeData theme, List<Widget> children) {
    return Material(
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05), width: 0.5),
      ),
      child: Column(children: children),
    );
  }

  // 统一封装的单元行，包含图标、主标题、描述和右侧箭头
  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: theme.hintColor.withValues(alpha: 0.75)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: theme.hintColor.withValues(alpha: 0.4), size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  // 分组的小标题
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
