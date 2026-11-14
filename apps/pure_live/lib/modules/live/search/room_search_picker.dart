import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/popular/room_card.dart' show RoomCard;
import 'package:pure_live/modules/live/search/search_controller.dart';
import 'package:pure_live/shared/shared.dart';

/// Opens the room search picker: the toolbar's word searched across every
/// platform (or the one the viewer picks in the tabs), the hits as the
/// feed's own room cards, and pressing a card hands the room to [onPick]
/// and closes the panel. The pages that act on a room rather than browse
/// it — the recorder adding a task, the multiview filling a cell — come
/// through here, so "search a room to add" is one shape wherever it is
/// offered.
///
/// The search runs on the shared search surface (the popular page's inline
/// search does the same), so the search page shows these results until its
/// next word.
Future<void> showRoomSearchPicker(
  BuildContext context, {
  required String query,
  required String title,
  required Future<void> Function(LiveRoom room) onPick,
}) {
  return showAppPanel<void>(
    context: context,
    detents: const [0.7, 1],
    builder: (context) => _RoomSearchPickerPanel(query: query, title: title, onPick: onPick),
  );
}

final class _RoomSearchPickerPanel extends ConsumerStatefulWidget {
  const _RoomSearchPickerPanel({required this.query, required this.title, required this.onPick});

  final String query;
  final String title;
  final Future<void> Function(LiveRoom room) onPick;

  @override
  ConsumerState<_RoomSearchPickerPanel> createState() => _RoomSearchPickerPanelState();
}

final class _RoomSearchPickerPanelState extends ConsumerState<_RoomSearchPickerPanel> {
  late final TextEditingController _field = TextEditingController(text: widget.query);
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // The search starts on arrival, every platform at once: a word handed
    // from the toolbar is a room to find, not a platform to browse.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(searchSiteIdProvider.notifier).selected = kSearchAllPlatforms;
      unawaited(ref.read(searchProvider.notifier).search(widget.query));
    });
  }

  @override
  void dispose() {
    _field.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _chooseScope(String id) {
    if (id == ref.read(searchSiteIdProvider)) return;
    ref.read(searchSiteIdProvider.notifier).selected = id;
    unawaited(ref.read(searchProvider.notifier).search(_field.text));
  }

  String _platformName(String id) {
    if (id == kSearchAllPlatforms) return context.t.search.scopeAll;
    final site = ref.read(sitesProvider).getById(id);
    return site == null ? id : localizedSiteName(site);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final search = ref.watch(searchProvider);
    final scope = ref.watch(searchSiteIdProvider);
    final settings = ref.watch(browseSettingsProvider);
    // The platform-display choice is a browse-wide choice: a switched-off
    // platform is not offered as a scope here either.
    ref.watch(sitesDisplayProvider);
    final visible = ref.read(sitesDisplayProvider.notifier).visibleIds();
    final platforms = [
      kSearchAllPlatforms,
      for (final site in ref.watch(sitesProvider).all)
        if (visible.contains(site.manifest.id)) site.manifest.id,
    ];
    Widget cardFor(BuildContext context, LiveRoom room, {bool listRow = false}) {
      Future<void> pick() async {
        Navigator.of(context).pop();
        await widget.onPick(room);
      }

      return RoomCard(room: room, listRow: listRow, onOpen: () => unawaited(pick()));
    }

    return AppPanel(
      title: Text(widget.title),
      // The grid scrolls itself; the panel hands it the room it has.
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          DsSearchField(
            controller: _field,
            autofocus: true,
            placeholder: t.common.searchHint,
            onSubmitted: (word) => unawaited(ref.read(searchProvider.notifier).search(word)),
          ),
          PlatformTabRow(
            platforms: platforms,
            current: scope,
            nameOf: _platformName,
            semanticLabel: t.search.targetsLabel,
            showPlatformWall: false,
            showLayoutToggle: false,
            onChanged: _chooseScope,
          ),
          Expanded(
            child: PagedCardGrid<LiveRoom>(
              scrollController: _scroll,
              items: search.rooms,
              hasMore: search.hasMore,
              isLoading: search.loading,
              onLoadMore: ref.read(searchProvider.notifier).loadMore,
              // The panel is narrower than a page: the rows read as list
              // cards, one room a line.
              layout: CardLayout.list,
              listMatchesGridWidth: true,
              listMainAxisExtent: kRoomCardListDesignHeight,
              listItemBuilder: (context, room) => cardFor(context, room, listRow: true),
              crossSpacing: settings.crossSpacing,
              mainSpacing: settings.mainSpacing,
              padding: const EdgeInsets.fromLTRB(DsSpace.s4, DsSpace.s4, DsSpace.s4, DsSpace.s16),
              error: search.error?.message,
              onRetry: () => unawaited(ref.read(searchProvider.notifier).retry()),
              emptyIcon: DsIcons.searchX,
              emptyTitle: t.search.noResultsTitle,
              itemBuilder: cardFor,
            ),
          ),
        ],
      ),
    );
  }
}
