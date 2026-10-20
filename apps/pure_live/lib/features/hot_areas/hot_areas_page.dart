import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveSite;
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The platform visibility and order page (the reference's `HotAreasPage`,
/// 3.x `SettingHotAreasPage`): which platforms the app shows at all, and in
/// what order. Hidden platforms are left out of popular, areas and search;
/// the order drives their tabs.
///
/// Both answers are stored as id lists in the shared preferences document —
/// `siteOrder` lists every id in its current order (a fresh install stores
/// nothing and the registry order rules), `hiddenSiteIds` is the hidden set.
/// At least one platform must stay visible: a shell with no content source
/// cannot be browsed, so the last visible row refuses to hide with a toast.
final class HotAreasPage extends ConsumerWidget {
  /// The platform visibility page.
  const new({super.key});

  /// The name a site row shows.
  static String siteName(BuildContext context, LiveSite site) =>
      site.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN');

  /// The registry's sites in the user's stored order: stored ids first in
  /// their stored order, the rest behind them in registry order.
  static List<LiveSite> orderedSites(List<LiveSite> sites, List<String> order) {
    if (order.isEmpty) return sites;
    final remaining = {for (final site in sites) site.manifest.id: site};
    final result = <LiveSite>[];
    for (final id in order) {
      final site = remaining.remove(id);
      if (site != null) result.add(site);
    }
    result.addAll(remaining.values);
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final preferences = ref.watch(appPreferencesProvider);
    final sites = ref.watch(sitesProvider).registry.all;
    final ordered = orderedSites(sites, preferences.siteOrder);
    final hidden = preferences.hiddenSiteIds.toSet();
    final visible = [
      for (final site in ordered)
        if (!hidden.contains(site.manifest.id)) site,
    ];
    final hiddenSites = [
      for (final site in ordered)
        if (hidden.contains(site.manifest.id)) site,
    ];

    return PureScaffold(
      appBar: PureAppBar(title: t.hotAreas.title),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            buildDefaultDragHandles: false,
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(t.hotAreas.note, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${t.hotAreas.visible} (${visible.length}) · ${t.hotAreas.orderNote}',
                          style: theme.text.caption.copyWith(color: theme.colors.textTertiary),
                        ),
                      ),
                      if (hiddenSites.isNotEmpty)
                        PureButton(
                          label: t.hotAreas.restore,
                          variant: ButtonVariant.ghost,
                          size: ControlSize.sm,
                          onPressed: () => unawaited(_restoreDefaults(ref)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            itemCount: visible.length + (hiddenSites.isEmpty ? 0 : 1 + hiddenSites.length),
            onReorderItem: (oldIndex, newIndex) => unawaited(_reorder(ref, visible, hiddenSites, oldIndex, newIndex)),
            itemBuilder: (context, index) {
              if (index >= visible.length) {
                final hiddenIndex = index - visible.length - 1;
                if (hiddenIndex < 0) {
                  return Padding(
                    key: const ValueKey('hot-areas-hidden-header'),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text('${t.hotAreas.hidden} (${hiddenSites.length})', style: theme.text.title),
                  );
                }
                final site = hiddenSites[hiddenIndex];
                return _SiteRow(
                  key: ValueKey('hidden-${site.manifest.id}'),
                  site: site,
                  hidden: true,
                  onToggle: () => unawaited(_setHidden(ref, site, false)),
                );
              }
              final site = visible[index];
              return _SiteRow(
                key: ValueKey('visible-${site.manifest.id}'),
                site: site,
                hidden: false,
                dragIndex: index,
                onToggle: () => unawaited(_setHidden(ref, site, true)),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _reorder(
    WidgetRef ref,
    List<LiveSite> visible,
    List<LiveSite> hiddenSites,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex < 0 || oldIndex >= visible.length) return;
    // onReorderItem already adjusts newIndex for the removed item.
    final moved = visible[oldIndex];
    final next = [...visible]..removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), moved);
    // The stored order covers both groups so un-hiding keeps a platform
    // where the user left it.
    final order = [for (final site in next) site.manifest.id, for (final site in hiddenSites) site.manifest.id];
    await ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(siteOrder: order));
  }

  Future<void> _setHidden(WidgetRef ref, LiveSite site, bool hide) async {
    final preferences = ref.read(appPreferencesProvider);
    final hidden = {...preferences.hiddenSiteIds};
    final id = site.manifest.id;
    if (hide) {
      final visibleCount = ref.read(sitesProvider).registry.all.length - hidden.length;
      if (visibleCount <= 1) {
        PureToast.show(ref.context, ref.context.t.hotAreas.keepAtLeastOne, type: PureToastType.warning);
        return;
      }
      hidden.add(id);
    } else {
      hidden.remove(id);
    }
    // Store the ids in registry order so the document stays stable.
    final orderedHidden = [
      for (final s in ref.read(sitesProvider).registry.all)
        if (hidden.contains(s.manifest.id)) s.manifest.id,
    ];
    await ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(hiddenSiteIds: orderedHidden));
  }

  Future<void> _restoreDefaults(WidgetRef ref) =>
      ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(hiddenSiteIds: const [], siteOrder: const []));
}

class _SiteRow extends StatelessWidget {
  const new({required this.site, required this.hidden, required this.onToggle, this.dragIndex, super.key});

  final LiveSite site;
  final bool hidden;
  final VoidCallback onToggle;
  final int? dragIndex;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          if (dragIndex case final index?)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Icon(Icons.drag_handle_rounded, color: theme.colors.textTertiary),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Icon(Icons.visibility_off_outlined, size: 20, color: theme.colors.textTertiary),
            ),
          Expanded(
            child: Text(
              HotAreasPage.siteName(context, site),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.text.body,
            ),
          ),
          if (hidden)
            PureButton(
              label: context.t.hotAreas.restore,
              variant: ButtonVariant.ghost,
              size: ControlSize.sm,
              onPressed: onToggle,
            )
          else
            PureSwitch(value: true, onChanged: (_) => onToggle()),
        ],
      ),
    );
  }
}
