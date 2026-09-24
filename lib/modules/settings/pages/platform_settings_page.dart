import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';

class PlatformSettingsPage extends GetView<SettingsService> {
  const PlatformSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("platform_settings"))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("platform_settings")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.apps_2_line,
              title: i18n("platform_display"),
              subtitle: i18n("platform_display_subtitle"),
              onTap: () => Get.toNamed(RoutePath.kSettingsHotAreas),
            ),
            Obx(
              () => context.buildTile(
                icon: Remix.heart_3_line,
                title: i18n("prefer_platform"),
                subtitle: i18n('prefer_platform_subtitle'),
                isLong: true,
                stackTrailingOnNarrow: true,
                showNavigationChevronWhenStacked: false,
                trailing: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _platformLabel(SettingsService.to.fav.preferPlatform.value),
                      style: AppTextStyles.t14.copyWith(color: Theme.of(context).hintColor.withValues(alpha: 0.75)),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Theme.of(context).hintColor.withValues(alpha: 0.4),
                      size: 20,
                    ),
                  ],
                ),
                onTap: () => showPreferPlatformSelectorDialog(context),
              ),
            ),
            context.buildTile(
              icon: Remix.accessibility_line,
              title: i18n('third_party_auth'),
              subtitle: i18n('third_party_auth_subtitle'),
              isLong: true,
              onTap: () {
                Get.toNamed(RoutePath.kSettingsAccount);
              },
            ),
            context.buildTile(
              icon: Remix.price_tag_3_line,
              title: i18n('tag_management'),
              subtitle: i18n('tag_management_subtitle'),
              isLong: true,
              onTap: () {
                Get.toNamed(RoutePath.kSettingsTags);
              },
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _platformLabel(String id) {
    final normalized = id.trim().toLowerCase();
    return i18nOr('site_$normalized', normalized);
  }

  void showPreferPlatformSelectorDialog(BuildContext context) {
    showDialog<void>(context: context, builder: (_) => const _PreferPlatformSelectorDialog());
  }
}

class _PreferPlatformSelectorDialog extends StatefulWidget {
  const _PreferPlatformSelectorDialog();

  @override
  State<_PreferPlatformSelectorDialog> createState() => _PreferPlatformSelectorDialogState();
}

class _PreferPlatformSelectorDialogState extends State<_PreferPlatformSelectorDialog> {
  String _query = '';
  final Map<String, Site> _siteCache = {};

  List<Site> _visibleSites() {
    final seen = <String>{};
    final result = <Site>[];
    for (final rawId in SettingsService.to.fav.hotAreasList) {
      final id = rawId.trim().toLowerCase();
      if (!seen.add(id) || !Sites.isSupported(id)) continue;
      // Searching must not reconstruct every adapter on each keystroke.
      result.add(_siteCache.putIfAbsent(id, () => Sites.of(id)));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(i18n('prefer_platform'), style: const TextStyle(fontWeight: FontWeight.bold)),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                key: const ValueKey('prefer-platform-filter'),
                onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: i18n('prefer_platform_filter_hint'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Obx(() {
              final sites = _visibleSites()
                  .where((site) {
                    if (_query.isEmpty) return true;
                    return site.id.contains(_query) || site.name.toLowerCase().contains(_query);
                  })
                  .toList(growable: false);
              if (sites.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(i18n('prefer_platform_filter_empty'), style: AppTextStyles.t14),
                );
              }
              return RadioGroup<String>(
                groupValue: SettingsService.to.fav.preferPlatform.value,
                onChanged: (value) {
                  if (value == null) return;
                  SettingsService.to.fav.changePreferPlatform(value);
                  Navigator.of(context).pop();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: sites
                      .map(
                        (site) => RadioListTile<String>(
                          value: site.id,
                          activeColor: theme.colorScheme.primary,
                          title: Text(site.name, style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w500)),
                        ),
                      )
                      .toList(growable: false),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
