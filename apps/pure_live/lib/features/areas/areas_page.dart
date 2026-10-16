import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveArea, LiveAreaProvider, LiveSite;
import 'package:live_uikit/styling.dart' show LiveAppBar, LiveButton, LiveEmpty, LiveScaffold, LiveSpinner;

import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/areas/areas_routes.dart';
import 'package:pure_live/features/areas/area_card.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';

/// Areas: every area-capable platform as a tab over its category catalogue
/// (3.x `AreasPage`); a category chip row splits the platforms that group
/// their areas, a plain grid serves the ones that do not.
final class AreasPage extends ConsumerWidget {
  /// The areas page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(sitesProvider);
    final capable = sites.registry.all.where((site) => site.capability<LiveAreaProvider>() != null).toList();
    if (capable.isEmpty) {
      return LiveScaffold(
        appBar: LiveAppBar(title: context.t.tabs.areas, actions: const [SettingsEntryButton()]),
        body: LiveEmpty(title: context.t.common.empty),
      );
    }
    return DefaultTabController(
      length: capable.length,
      child: LiveScaffold(
        appBar: LiveAppBar(
          title: context.t.tabs.areas,
          actions: const [SettingsEntryButton()],
          // A Material strip for now: `LiveTabs` has no TabController, so this
          // bar and its `TabBarView` below have to move to an index plus an
          // IndexedStack together, not one at a time.
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final site in capable) Tab(text: site.manifest.localizedName(_tag(context), 'zh-CN'))],
          ),
        ),
        body: TabBarView(
          children: [for (final site in capable) _PlatformAreas(key: ValueKey(site.manifest.id), site: site)],
        ),
      ),
    );
  }

  static String _tag(BuildContext context) => Localizations.localeOf(context).toLanguageTag();
}

/// One platform's catalogue: the areas, grouped by their parent category.
final class _PlatformAreas extends StatefulWidget {
  /// A catalogue for [site].
  const new({required this.site, super.key});

  final LiveSite site;

  @override
  State<_PlatformAreas> createState() => _PlatformAreasState();
}

final class _PlatformAreasState extends State<_PlatformAreas> with AutomaticKeepAliveClientMixin {
  List<LiveArea>? _areas;
  Object? _error;
  String? _selectedParent;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
    });
    final capability = widget.site.capability<LiveAreaProvider>();
    if (capability == null) {
      return;
    }
    final result = await capability.getAreas();
    if (!mounted) {
      return;
    }
    setState(() {
      result.fold((error) => _error = error, (areas) {
        _areas = areas;
        _selectedParent = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final areas = _areas;
    if (areas == null) {
      if (_error != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.t.errors.network, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              LiveButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: _load),
            ],
          ),
        );
      }
      return const Center(child: LiveSpinner(size: 40));
    }
    if (areas.isEmpty) {
      return LiveEmpty(title: context.t.common.empty);
    }
    // The parent groups, in the order the site presents them; a platform
    // without parents is one group and shows no chip row.
    final groups = <String, List<LiveArea>>{};
    for (final area in areas) {
      final parent = area.parentAreaName ?? '';
      groups.putIfAbsent(parent, () => []).add(area);
    }
    final visible = _selectedParent == null || !groups.containsKey(_selectedParent)
        ? groups.values.expand((list) => list).toList()
        : groups[_selectedParent]!;
    return Column(
      children: [
        if (groups.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                for (final parent in groups.keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(parent.isEmpty ? context.t.tabs.areas : parent),
                      selected: _selectedParent == parent || (_selectedParent == null && parent.isEmpty),
                      onSelected: (_) => setState(() => _selectedParent = parent),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              childAspectRatio: 0.85,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final area = visible[index];
              return AreaCard(
                area: area,
                onOpen: () => AreaRoomsRoute(
                  siteId: area.platform,
                  areaId: area.areaId,
                  areaName: area.areaName,
                ).push<void>(context),
              );
            },
          ),
        ),
      ],
    );
  }
}
