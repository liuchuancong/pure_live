import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart'
    show selectedSiteIdProvider, sitesProvider;
import 'package:pure_live/l10n/translations.dart';

/// The settings page's first floor: the browsing preferences the whole
/// app reads — the site every surface browses, how wide a feed card gets
/// (the grid reflows at once), how many rooms one page asks for — each
/// written through the moment it changes.
///
/// Appearance, network and the rest arrive on the floors above; this page
/// owns what already works end to end.
final class SettingsPage extends ConsumerWidget {
  /// The settings page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(browseSettingsProvider);
    final sites = ref.watch(sitesProvider).all;
    final selectedId = ref.watch(selectedSiteIdProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s24),
      child: DsListSection(
        header: Text(t.settings.browsingTitle),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
            child: DsSelect<String>(
              value: selectedId,
              // The select reports null only when cleared (clearable is
              // off), so a null never reaches the site setter.
              onChanged: (id) {
                if (id != null) ref.read(selectedSiteIdProvider.notifier).selected = id;
              },
              options: [
                for (final site in sites)
                  DsSelectOption(
                    value: site.manifest.id,
                    label: site.manifest.name['zh-CN'] ?? site.manifest.id,
                  ),
              ],
              placeholder: t.settings.site,
              leading: const DsIcon(DsIcons.tv),
              semanticLabel: t.settings.site,
            ),
          ),
          DsListRow(
            leading: const DsIcon(DsIcons.columns2),
            title: Text(t.settings.cardExtent),
            description: Text(t.settings.cardExtentDescription),
            detail: Text('${settings.homeCardExtent.round()} px'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            child: DsSlider(
              value: settings.homeCardExtent,
              min: 160,
              max: 420,
              divisions: 26,
              onChanged: (value) => ref.read(browseSettingsProvider.notifier).homeCardExtent = value,
              semanticLabel: t.settings.cardExtent,
            ),
          ),
          DsListRow(
            leading: const DsIcon(DsIcons.list),
            title: Text(t.settings.pageSize),
            description: Text(t.settings.pageSizeDescription),
            detail: Text('${settings.homePageSize}'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            child: DsSlider(
              value: settings.homePageSize.toDouble(),
              min: 10,
              max: 90,
              divisions: 16,
              onChanged: (value) => ref.read(browseSettingsProvider.notifier).homePageSize = value.round(),
              semanticLabel: t.settings.pageSize,
            ),
          ),
        ],
      ),
    );
  }
}
