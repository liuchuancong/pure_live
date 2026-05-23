import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/iptv/iptv_page.dart';
import 'package:pure_live/modules/backup/backup_page.dart';
import 'package:pure_live/modules/settings/theme_settings_page.dart';
import 'package:pure_live/modules/settings/video_settings_page.dart';
import 'package:pure_live/modules/settings/general_settings_page.dart';
import 'package:pure_live/modules/settings/platform_settings_page.dart';
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
          // 📦 分组一：界面与视听体验 (Appearance & Audio-Visual)
          _buildGroupTitle(theme, i18n("theme_customization")),
          _buildModernCard(theme, [
            _buildTile(
              context,
              icon: Remix.palette_line, // 🎨 调色盘：完美对应外观主题自定义
              title: i18n("theme_customization"),
              subtitle: i18n("theme_customization_desc"),
              onTap: () => Get.to(() => const ThemeSettingsPage()),
            ),
            _buildTile(
              context,
              icon: Remix.tv_line, // 📺 电视机：代表 IPTV 直播源渠道管理
              title: i18n("iptv_settings"),
              subtitle: i18n("manage_iptv_sources"),
              onTap: () => Get.to(() => const IptvPage()),
            ),
            _buildTile(
              context,
              icon: Remix.film_line, // 🎬 胶片：代表视频解码、画质与全屏播放
              title: i18n("video"),
              subtitle: i18n("video_desc"),
              onTap: () => Get.to(() => const VideoSettingsPage()),
            ),
            _buildTile(
              context,
              icon: Remix.cpu_line, // 🧠 CPU核心：代表底层播放器内核核心切换
              title: i18n("player_kernel"),
              subtitle: i18n("player_kernel_desc"),
              onTap: () => Get.to(() => const PlayerKernelSettingsPage()),
            ),
          ]),

          const SizedBox(height: 20),

          // 📦 分组二：系统、数据与多平台 (System, Data & Sync)
          _buildGroupTitle(theme, i18n("general")),
          _buildModernCard(theme, [
            _buildTile(
              context,
              icon: Remix.settings_4_line, // ⚙️ 现代齿轮：代表系统、语言等通用全局配置
              title: i18n("general"),
              subtitle: i18n("general_desc"),
              onTap: () => Get.to(() => const GeneralSettingsPage()),
            ),
            _buildTile(
              context,
              icon: Remix.database_2_line, // 💾 数据库：代表缓存、图片、录制视频等存储数据管理
              title: i18n("cache_and_data"),
              subtitle: i18n("cache_and_data_desc"),
              onTap: () => Get.to(() => const CacheDataSettingsPage()),
            ),
            _buildTile(
              context,
              icon: Remix.apps_2_line, // 🧩 多应用矩阵：代表接入、同步第三方多平台聚合直播源
              title: i18n("platform_settings"),
              subtitle: i18n("platform_settings_desc"),
              onTap: () => Get.to(() => const PlatformSettingsPage()),
            ),
            _buildTile(
              context,
              icon: Remix.refresh_line, // 🔄 循环同步：代表一键配置备份与从云端覆盖恢复
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
