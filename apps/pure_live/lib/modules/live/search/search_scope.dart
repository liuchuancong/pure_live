import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveSite;
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/search/search_capability.dart';
import 'package:pure_live/shared/shared.dart' show localizedSiteIcon, localizedSiteName;

/// Platforms outside mainland China: without a proxy their requests usually
/// fail there, which is why "all" lets the viewer leave them out.
const Set<String> overseasSearchPlatforms = {
  'twitch',
  'soop',
  'picarto',
  'twitcasting',
  'niconico',
  'showroom',
  'chzzk',
  'liveme',
  'tiktok',
  'youtube',
  'bigo',
  'pandalive',
  'fc2live',
  'steambroadcast',
  '17live',
};

/// The platforms the viewer leaves out of the search's "all", persisted as a
/// JSON list under `search.allExcluded` (the reference's record).
final class SearchExcludedController extends Notifier<Set<String>> {
  /// The stored key.
  static const String key = 'search.allExcluded';

  @override
  Set<String> build() {
    try {
      final raw = StoragePrefs.getString(key);
      if (raw == null || raw.isEmpty) return const <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>{};
      return {
        for (final id in decoded)
          if (id is String && id.trim().isNotEmpty) id.trim().toLowerCase(),
      };
    } on Object {
      return const <String>{};
    }
  }

  /// Stores [excluded]; an empty set clears the record.
  Future<void> save(Set<String> excluded) async {
    final clean = {
      for (final id in excluded)
        if (id.trim().isNotEmpty) id.trim().toLowerCase(),
    };
    state = clean;
    try {
      if (clean.isEmpty) {
        await StoragePrefs.remove(key);
      } else {
        await StoragePrefs.setString(key, jsonEncode(clean.toList()..sort()));
      }
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The platforms left out of "all".
final searchExcludedProvider = NotifierProvider<SearchExcludedController, Set<String>>(SearchExcludedController.new);

/// Opens the search-scope panel: what every platform finds, and which ones
/// "all" searches, domestic and overseas apart, with "domestic only" and
/// "select all". Answers the excluded set, or [excluded] when dismissed.
Future<Set<String>> showSearchScopePanel(
  BuildContext context, {
  required List<LiveSite> sites,
  required Set<String> excluded,
}) async {
  final result = await showDsPanel<Set<String>>(
    context: context,
    builder: (context) => _SearchScopePanel(
      sites: sites,
      excluded: {
        for (final site in sites)
          if (excluded.contains(site.manifest.id)) site.manifest.id,
      },
    ),
  );
  return result ?? excluded;
}

final class _SearchScopePanel extends StatefulWidget {
  const _SearchScopePanel({required this.sites, required this.excluded});

  final List<LiveSite> sites;
  final Set<String> excluded;

  @override
  State<_SearchScopePanel> createState() => _SearchScopePanelState();
}

final class _SearchScopePanelState extends State<_SearchScopePanel> {
  late Set<String> _excluded = {...widget.excluded};

  int get _chosen => widget.sites.length - _excluded.length;

  void _set(Set<String> next) {
    // Leaving every platform out would search none: keep the last one.
    if (next.length >= widget.sites.length) return;
    setState(() => _excluded = next);
  }

  void _toggle(String id, {required bool included}) {
    final next = {..._excluded};
    if (included) {
      next.remove(id);
    } else {
      next.add(id);
    }
    _set(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final muted = theme.typography.caption.copyWith(color: colors.textMuted);
    final domestic = [
      for (final site in widget.sites)
        if (!overseasSearchPlatforms.contains(site.manifest.id)) site,
    ];
    final overseas = [
      for (final site in widget.sites)
        if (overseasSearchPlatforms.contains(site.manifest.id)) site,
    ];
    final accent = DsTheme.colorsOf(context).accent;

    Widget group(String title, List<LiveSite> members) {
      if (members.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s4,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.s8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.typography.bodyStrong.copyWith(color: accent)),
                ),
                Text(
                  '${members.where((site) => !_excluded.contains(site.manifest.id)).length}/${members.length}',
                  style: muted,
                ),
              ],
            ),
          ),
          for (final site in members)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.s8),
                  child: localizedSiteIcon(site, size: 24) ?? const SizedBox.square(dimension: 24),
                ),
                Expanded(
                  child: DsCheckbox(
                    value: !_excluded.contains(site.manifest.id),
                    // The last chosen platform cannot be left out.
                    onChanged: _chosen == 1 && !_excluded.contains(site.manifest.id)
                        ? null
                        : (value) => _toggle(site.manifest.id, included: value ?? false),
                    label: Text(localizedSiteName(site)),
                    description: Text(searchCoverageText(t, SearchCapabilities.of(site.manifest.id)), style: muted),
                  ),
                ),
              ],
            ),
        ],
      );
    }

    return DsPanel(
      title: Text(t.search.scopeTitle),
      footer: DsButton(
        onPressed: _chosen == 0 ? null : () => Navigator.of(context).pop(_excluded),
        child: Text(t.search.scopeApply),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.search.scopeHint, style: theme.typography.body.copyWith(color: colors.textMuted)),
            Row(
              spacing: DsSpace.s8,
              children: [
                DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: domestic.isEmpty ? null : () => _set({for (final site in overseas) site.manifest.id}),
                  child: Text(t.search.scopeDomesticOnly),
                ),
                DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: () => _set(<String>{}),
                  child: Text(t.search.scopeSelectAll),
                ),
              ],
            ),
            group(t.search.scopeDomestic, domestic),
            group(t.search.scopeOverseas, overseas),
          ],
        ),
      ),
    );
  }
}
