import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/features/settings/settings_catalog.dart';
import 'package:pure_live/features/settings/settings_model.dart';
import 'package:pure_live/features/settings/widgets/settings_chrome.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart' as sui;
import 'package:pure_uikit/pure_uikit.dart';

/// Settings, on the package's `SettingsSplitView`.
///
/// The split view draws the whole screen in the active design language: the
/// overview as its list pane (a Windows `NavigationView` with the icon rail
/// and the pane opened over the page in the fluent style, a macOS sidebar,
/// iOS/Android grouped lists elsewhere), and each section page as a
/// destination in the detail pane — pushed over the list, with a back
/// button, when there is room for one pane only. The section pages build
/// through [SettingsChrome], which drops their own bar when embedded.
///
/// Sections that are another route of the app (IPTV, backup) push above
/// everything in both layouts, as before.
///
/// Search filters the catalogue (the pages' rows indexed in
/// `settings_catalog.dart`) behind a 150 ms debounce into a panel over the
/// split view; results group under "page › group" and tapping one opens its
/// page. Ctrl/⌘+F focuses the box, Esc clears it, and back closes the panel
/// before it leaves settings.
class SettingsPage extends ConsumerStatefulWidget {
  /// The settings index, optionally opening [section] at once.
  const new({this.section = '', super.key});

  /// A `SettingsSection` value name to open directly (the reference's route
  /// argument). Route sections are ignored here — their callers push them.
  final String section;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final sui.SettingsSplitController _split = sui.SettingsSplitController();
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.addListener(_searchChanged);
    // A deep link: picked before the view exists, it is the first page the
    // view shows — also in one pane, which is what the route asks for.
    if (SettingsSection.maybeFromId(widget.section) case final SettingsSection section when section.route == null) {
      _split.select(section.name);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _split.dispose();
    super.dispose();
  }

  void _searchChanged() {
    final text = _search.text.trim();
    if (text == _query) return;
    _debounce?.cancel();
    // Filtering waits for a pause in typing; clearing shows the index at
    // once (the reference's debounce rule).
    if (text.isEmpty) {
      setState(() => _query = '');
    } else {
      _debounce = Timer(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _query = _search.text.trim());
      });
    }
  }

  /// A search result: close the panel and open the entry's page.
  void _reveal(SettingsEntry entry) {
    FocusScope.of(context).unfocus();
    _search.clear();
    final section = entry.section;
    if (section.route case final route?) {
      unawaited(context.push<void>(route));
    } else {
      _split.select(section.name);
    }
  }

  /// The overview: the sections' tiles, grouped by area.
  List<sui.AbstractSettingsSection> _indexSections(Translations t) => [
    for (final area in SettingsArea.values)
      sui.SettingsSection(
        title: Text(area.titleOf(t)),
        tiles: [
          for (final section in SettingsSection.values)
            if (section.area == area) _sectionTile(t, section),
        ],
      ),
  ];

  sui.SettingsTile _sectionTile(Translations t, SettingsSection section) {
    final title = Text(settingsSectionTitle(t, section));
    final description = Text(settingsSectionDescription(t, section));
    if (section.route case final route?) {
      // Another route of the app: pushed above everything, not a pane page.
      return sui.SettingsTile.navigation(
        key: ValueKey('settings-section-${section.name}'),
        leading: Icon(section.icon, size: 20),
        title: title,
        description: description,
        trailing: const Icon(Icons.open_in_new, size: 18),
        onPressed: (_) => unawaited(context.push<void>(route)),
      );
    }
    return sui.SettingsTile.navigation(
      key: ValueKey('settings-section-${section.name}'),
      leading: Icon(section.icon, size: 20),
      title: title,
      description: description,
      destination: sui.SettingsDestination(
        id: section.name,
        title: title,
        builder: (context) => SettingsEmbedded(child: section.buildPage() ?? const SizedBox.shrink()),
      ),
    );
  }

  Widget _searchField() => PureTextField(
    controller: _search,
    focusNode: _searchFocus,
    placeholder: context.t.settings.searchHint,
    prefix: const Icon(Icons.search_rounded, size: 18),
    suffix: _search.text.isEmpty
        ? null
        : PureIconButton(
            icon: Icons.close_rounded,
            size: ControlSize.sm,
            tooltip: context.t.common.clear,
            onPressed: _search.clear,
          ),
  );

  /// The results panel: the found rows under "page › group" headings, over
  /// the split view (which stays mounted, keeping its picked page).
  Widget _searchPanel(Translations t) {
    final found = searchSettings(t, settingsCatalog, _query);
    if (found.isEmpty) {
      return Center(
        child: Column(
          key: const ValueKey('settings-search-empty'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 44),
            const SizedBox(height: PureSpacing.md),
            Text(t.settings.searchEmpty),
            const SizedBox(height: PureSpacing.xs),
            Text(t.settings.searchEmptyHint, style: TextStyle(color: PureTheme.of(context).colors.textSecondary)),
          ],
        ),
      );
    }
    final byCrumb = <String, List<SettingsEntry>>{};
    for (final entry in found) {
      byCrumb.putIfAbsent(entry.crumb(t), () => []).add(entry);
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: sui.SettingsList(
          sections: [
            for (final MapEntry(key: crumb, value: entries) in byCrumb.entries)
              sui.SettingsSection(
                title: Text(crumb),
                tiles: [
                  for (final entry in entries)
                    sui.SettingsTile.navigation(
                      key: ValueKey('settings-entry-${entry.id}'),
                      title: Text(entry.titleText(t)),
                      description: entry.descriptionText(t) == null ? null : Text(entry.descriptionText(t)!),
                      onPressed: (_) => _reveal(entry),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return PopScope(
      // Back closes the search panel before it leaves settings.
      canPop: _query.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _search.clear();
      },
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.keyF, control: true): _FindIntent(),
          SingleActivator(LogicalKeyboardKey.keyF, meta: true): _FindIntent(),
          SingleActivator(LogicalKeyboardKey.escape): _ClearSearchIntent(),
        },
        child: Actions(
          actions: {
            _FindIntent: CallbackAction<_FindIntent>(
              onInvoke: (_) {
                _searchFocus.requestFocus();
                return null;
              },
            ),
            _ClearSearchIntent: _ClearSearchAction(_search),
          },
          child: Material(
            // The page sits under the split view's own surfaces, but the
            // search bar above it needs a Material ancestor of its own.
            color: PureTheme.of(context).colors.bgLayout,
            child: Column(
              children: [
                SafeArea(
                  left: false,
                  right: false,
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: _searchField()),
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      sui.SettingsSplitView(
                        controller: _split,
                        title: Text(t.tabs.settings),
                        restorationId: 'settings',
                        sections: _indexSections(t),
                      ),
                      if (_query.isNotEmpty)
                        Material(color: PureTheme.of(context).colors.bgLayout, child: _searchPanel(t)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FindIntent extends Intent {
  const new();
}

class _ClearSearchIntent extends Intent {
  const new();
}

/// Esc clears the search; with nothing typed it is not handled, so Esc keeps
/// going back (the reference's rule).
class _ClearSearchAction extends Action<_ClearSearchIntent> {
  new(this.search);

  final TextEditingController search;

  @override
  bool isEnabled(_ClearSearchIntent intent) => search.text.isNotEmpty;

  @override
  Object? invoke(_ClearSearchIntent intent) {
    search.clear();
    return null;
  }
}
