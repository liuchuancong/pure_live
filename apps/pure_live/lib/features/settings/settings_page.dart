import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/features/settings/settings_catalog.dart';
import 'package:pure_live/features/settings/settings_model.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Settings, in the reference's v5 shape: an overview of five groups, a
/// search box, and the page that is open.
///
/// Below [settingsTwoPaneBreakpoint] the overview is its own page and a row
/// replaces it; from there the overview column ([settingsOverviewWidth]) and
/// the open page sit side by side and pages a section opens stay in that
/// pane's own [Navigator]. Sections that are another route of the app (IPTV,
/// backup) push above everything in both layouts — the reference's split.
///
/// Search filters the catalogue (the pages' rows indexed in
/// `settings_catalog.dart`) behind a 150 ms debounce; results group under
/// "page › group" and tapping one opens its page. Ctrl/⌘+F focuses the box,
/// Esc clears it.
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
  final GlobalKey<NavigatorState> _content = GlobalKey<NavigatorState>();
  late final NavigatorObserver _contentObserver = _ContentObserver(_contentChanged);
  late SettingsSection? _open = switch (SettingsSection.maybeFromId(widget.section)) {
    final SettingsSection? section when section != null && section.route == null => section,
    _ => null,
  };
  String _query = '';
  int _shown = 0;
  bool _contentCanPop = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.addListener(_searchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _searchChanged() {
    final text = _search.text.trim();
    if (text == _query) return;
    _debounce?.cancel();
    // Filtering waits for a pause in typing; clearing shows the overview at
    // once (the reference's debounce rule).
    if (text.isEmpty) {
      setState(() => _query = '');
    } else {
      _debounce = Timer(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _query = _search.text.trim());
      });
    }
  }

  void _contentChanged() {
    final canPop = _content.currentState?.canPop() ?? false;
    if (canPop != _contentCanPop && mounted) setState(() => _contentCanPop = canPop);
  }

  void _openSection(SettingsSection section) {
    if (section.route case final route?) {
      unawaited(context.push<void>(route));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _open = section;
      _shown++;
      _contentCanPop = false;
    });
  }

  /// A search result: open its page. (The reference also flashes the row;
  /// the catalogue rows here live inside pages that key nothing yet, so the
  /// reveal stops at the page.)
  void _reveal(SettingsEntry entry) => _openSection(entry.section);

  void _closeSection() => setState(() {
    _open = null;
    _contentCanPop = false;
  });

  Widget _contentNavigator(SettingsSection section, {required bool twoPane}) => HeroControllerScope.none(
    child: Navigator(
      key: _content,
      observers: [_contentObserver],
      pages: [
        MaterialPage<void>(
          key: ValueKey('settings-content-${section.name}-$_shown'),
          child: _SectionHost(section: section, twoPane: twoPane, onClose: _closeSection),
        ),
      ],
      onDidRemovePage: (_) {},
    ),
  );

  Widget _overviewBody({required bool twoPane, required SettingsSection? selected}) =>
      _query.isEmpty
          ? _Overview(selected: selected, onOpen: _openSection, twoPane: twoPane)
          : _SearchResults(query: _query, twoPane: twoPane, onReveal: _reveal);

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= settingsTwoPaneBreakpoint;
        final Widget page;
        if (twoPane) {
          final section = _open ?? SettingsSection.appearance;
          page = PureScaffold(
            body: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: settingsOverviewWidth,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 56,
                          child: Row(
                            children: [
                              if (Navigator.of(context).canPop()) const BackButton() else const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  context.t.tabs.settings,
                                  textAlign: TextAlign.center,
                                  style: PureTheme.of(context).text.title.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),
                        Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 4), child: _searchField()),
                        Expanded(child: _overviewBody(twoPane: true, selected: section)),
                      ],
                    ),
                  ),
                  VerticalDivider(width: 1, color: PureTheme.of(context).colors.border),
                  Expanded(child: _contentNavigator(section, twoPane: true)),
                ],
              ),
            ),
          );
        } else if (_open case final section?) {
          page = _contentNavigator(section, twoPane: false);
        } else {
          page = PureScaffold(
            appBar: PureAppBar(title: context.t.tabs.settings),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: _searchField()),
                ),
                Expanded(child: _overviewBody(twoPane: false, selected: null)),
              ],
            ),
          );
        }
        return PopScope(
          canPop: !_contentCanPop && (twoPane || _open == null),
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_contentCanPop) {
              _content.currentState?.maybePop();
            } else if (!twoPane && _open != null) {
              _closeSection();
            }
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
                    if (!twoPane && _open != null) _closeSection();
                    _searchFocus.requestFocus();
                    return null;
                  },
                ),
                _ClearSearchIntent: _ClearSearchAction(_search),
              },
              child: page,
            ),
          ),
        );
      },
    );
  }
}

/// The pane's root: the inline section page, or a stub while the overview
/// owns the whole window (single-pane never mounts the navigator with no
/// section, and two-pane always has one).
class _SectionHost extends StatelessWidget {
  const new({required this.section, required this.twoPane, required this.onClose});

  final SettingsSection section;
  final bool twoPane;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final page = section.buildPage();
    if (page == null) {
      // A route section never lives in the pane; defend the invariant by
      // closing back to the overview.
      WidgetsBinding.instance.addPostFrameCallback((_) => onClose());
      return const SizedBox.shrink();
    }
    return page;
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

class _ContentObserver extends NavigatorObserver {
  new(this.changed);

  final VoidCallback changed;

  void _later() => WidgetsBinding.instance.addPostFrameCallback((_) => changed());

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _later();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _later();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _later();
}

/// The overview: five groups of pages, the reference's `_Overview`.
class _Overview extends StatelessWidget {
  const new({required this.selected, required this.onOpen, required this.twoPane});

  final SettingsSection? selected;
  final ValueChanged<SettingsSection> onOpen;
  final bool twoPane;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          key: const ValueKey('settings-overview'),
          padding: EdgeInsets.fromLTRB(twoPane ? 12 : 16, 0, twoPane ? 12 : 16, 32),
          children: [
            for (final (index, area) in SettingsArea.values.indexed) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(8, index == 0 ? 4 : 20, 8, 8),
                child: Text(
                  area.titleOf(t),
                  style: theme.text.caption.copyWith(color: theme.colors.textTertiary, fontWeight: FontWeight.w600),
                ),
              ),
              for (final section in SettingsSection.values)
                if (section.area == area)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: PureListRow(
                      key: ValueKey('settings-section-${section.name}'),
                      leading: Icon(section.icon),
                      title: settingsSectionTitle(t, section),
                      subtitle: settingsSectionDescription(t, section),
                      selected: twoPane && section == selected,
                      onTap: () => onOpen(section),
                      trailing: Icon(
                        section.route == null ? Icons.chevron_right_rounded : Icons.open_in_new_rounded,
                        color: theme.colors.textTertiary,
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Search results: the found rows under "page › group" headings.
class _SearchResults extends StatelessWidget {
  const new({required this.query, required this.twoPane, required this.onReveal});

  final String query;
  final bool twoPane;
  final ValueChanged<SettingsEntry> onReveal;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final found = searchSettings(t, settingsCatalog, query);
    if (found.isEmpty) {
      return Center(
        child: Column(
          key: const ValueKey('settings-search-empty'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 44, color: theme.colors.textTertiary),
            const SizedBox(height: PureSpacing.md),
            Text(t.settings.searchEmpty, style: theme.text.title),
            const SizedBox(height: PureSpacing.xs),
            Text(
              t.settings.searchEmptyHint,
              style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary),
            ),
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
        child: ListView(
          key: const ValueKey('settings-search-results'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(twoPane ? 12 : 16, 0, twoPane ? 12 : 16, 32),
          children: [
            for (final MapEntry(key: crumb, value: entries) in byCrumb.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Text(
                  crumb,
                  style: theme.text.caption.copyWith(color: theme.colors.textTertiary, fontWeight: FontWeight.w600),
                ),
              ),
              for (final entry in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: PureListRow(
                    key: ValueKey('settings-entry-${entry.id}'),
                    title: entry.titleText(t),
                    subtitle: entry.descriptionText(t),
                    onTap: () => onReveal(entry),
                    trailing: Icon(Icons.chevron_right_rounded, color: theme.colors.textTertiary),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
