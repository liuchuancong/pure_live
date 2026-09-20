import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:remixicon/remixicon.dart'; // 🌟 Imported Remix Icons pack

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  bool _openingProject = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: <Widget>[
          Center(
            child: Column(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Container(
                    width: PlatformUtils.isMobile ? 80 : 96,
                    height: PlatformUtils.isMobile ? 80 : 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.08), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Image.asset('assets/icons/icon.png', fit: BoxFit.contain),
                  ),
                ),

                const SizedBox(height: 18),
                Text(
                  i18n("app_name"),
                  style: AppTextStyles.t18.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05), width: 0.5),
                  ),
                  child: Text(
                    'v${VersionUtil.version}',
                    style: AppTextStyles.t11.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
          context.buildGroupTitle(i18n("about")),
          const SizedBox(height: 8),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.download_cloud_2_line,
              title: i18n("online_update"),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v${VersionUtil.version}',
                  style: AppTextStyles.t11.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ),
              stackTrailingOnNarrow: true,
              onTap: () => Get.toNamed(RoutePath.kVersionPage),
            ),
            context.buildTile(
              icon: Remix.history_line,
              title: i18n("history"),
              subtitle: i18n("history_desc"),
              onTap: () => Get.toNamed(RoutePath.kVersionHistory),
            ),
            context.buildTile(icon: Remix.shield_user_line, title: i18n("license"), onTap: openLicensePage),
          ]),
          const SizedBox(height: 24),
          context.buildGroupTitle(i18n("project")),
          const SizedBox(height: 8),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.code_s_slash_line,
              title: i18n("project_page"),
              subtitle: VersionUtil.projectUrl,
              isLong: true,
              onTap: () => unawaited(_openProject()),
            ),
            context.buildTile(
              icon: Remix.error_warning_line,
              title: i18n("project_alert"),
              subtitle: i18n("app_legalese"),
              isLong: true,
              iconColor: theme.colorScheme.error,
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _openProject() async {
    if (_openingProject) return;
    _openingProject = true;
    try {
      final opened = await launchUrl(Uri.parse(VersionUtil.projectUrl), mode: LaunchMode.externalApplication);
      if (!opened) ToastUtil.show(i18n('external_browser_not_opened'));
    } catch (_) {
      ToastUtil.show(i18n('external_browser_not_opened'));
    } finally {
      _openingProject = false;
    }
  }

  void openLicensePage() {
    showLicensePage(
      context: context,
      applicationName: i18n("app_name"),
      applicationLegalese: i18n("app_legalese"),
      applicationVersion: VersionUtil.version,
      useRootNavigator: true,
      applicationIcon: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(width: 60, child: Center(child: Image.asset('assets/icons/icon.png'))),
      ),
    );
  }
}
