import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_feeds.dart';
import 'package:pure_live/modules/huya/controller/huya_video.dart' show huyaInlineSearchProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart';
import 'package:pure_live/modules/live/areas/areas.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/multiview/multiview.dart' show multiviewSearchHandoffProvider;
import 'package:pure_live/modules/live/popular/popular.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/music/controller/music_search.dart';
import 'package:pure_live/modules/vod/controller/vod_controller.dart';
import 'package:pure_live/shared/shared.dart';

/// The word a page's toolbar search takes: its hint and where the word goes.
///
/// The word lands in the page on screen — its own content in place, its
/// module's own search surface when the module has one — never a cold,
/// scopeless page elsewhere.
typedef PageInlineSearch = ({String hint, void Function(String word) take});

/// The current page's inline search, or null when the page has no list of its
/// own to search (the search pages with their own field, the toolbox, the
/// logs, the settings-like pages).
PageInlineSearch? pageInlineSearch(
  WidgetRef ref,
  Translations t,
  AppModule module,
  NavigationItem page, {
  required void Function(NavigationItem page) openPage,
}) {
  switch (module) {
    case AppModule.live:
      // Each list page narrows its own content: the popular feed its rooms,
      // the areas page its catalogue, the follows, the records. The recorder
      // and the multiview act on a room instead: their word opens the room
      // search picker and the pick becomes a task or a cell.
      return switch (page) {
        NavigationItem.hot => (
          hint: t.common.searchHint,
          take: (word) => ref.read(popularInlineSearchProvider.notifier).search(word),
        ),
        NavigationItem.zones => (
          hint: t.areas.searchHint,
          take: (word) => ref.read(areasInlineSearchProvider.notifier).search(word),
        ),
        NavigationItem.favorites => (
          hint: t.common.searchHint,
          take: (word) => ref.read(favoritesInlineSearchProvider.notifier).search(word),
        ),
        NavigationItem.history => (
          hint: t.common.searchHint,
          take: (word) => ref.read(historySearchHandoffProvider.notifier).hand(word),
        ),
        NavigationItem.record => (
          hint: t.recorder.searchHint,
          take: (word) => ref.read(recorderSearchHandoffProvider.notifier).hand(word),
        ),
        NavigationItem.multiview => (
          hint: t.multiview.searchHint,
          take: (word) => ref.read(multiviewSearchHandoffProvider.notifier).hand(word),
        ),
        _ => null,
      };
    case AppModule.iptv:
      // The channel pages search their channels in place; the sources and the
      // rest have no list of channels to narrow.
      const searchable = {NavigationItem.channels, NavigationItem.iptvFavorites, NavigationItem.iptvGuide};
      if (!searchable.contains(page)) return null;
      return (hint: t.iptv.searchChannels, take: (word) => ref.read(iptvSearchHandoffProvider.notifier).hand(word));
    case AppModule.vod:
      // The station's own search page answers; it has its own field.
      if (page == NavigationItem.vodSearch) return null;
      return (
        hint: t.vod.searchHint,
        take: (word) {
          ref.read(vodPendingSearchProvider.notifier).hand(word);
          openPage(NavigationItem.vodSearch);
        },
      );
    case AppModule.huya:
      // The station's own search page answers; it has its own field.
      if (page == NavigationItem.huyaSearch) return null;
      return (
        hint: t.huya.searchHint,
        take: (word) {
          ref.read(huyaInlineSearchProvider.notifier).hand(word);
          openPage(NavigationItem.huyaSearch);
        },
      );
    case AppModule.music:
      // The library is the module's search: the page takes the word and
      // moves there itself.
      return (
        hint: t.music.searchHint,
        take: (word) {
          ref.read(musicSearchHandoffProvider.notifier).hand(word);
          if (page != NavigationItem.music) openPage(NavigationItem.music);
        },
      );
    case AppModule.hongguo:
      // The station's own search view answers; it has its own field.
      if (page == NavigationItem.hongguoSearch) return null;
      return (
        hint: t.hongguo.searchHint,
        take: (word) {
          ref.read(hongguoSearchHandoffProvider.notifier).hand(word);
          openPage(NavigationItem.hongguoSearch);
        },
      );
  }
}

/// Asks for a word over the page in a panel: the title bar's field folded
/// into a sheet, for a window (or a module bar) too narrow to hold it. The
/// word goes where the page's own inline search would take it.
Future<void> showPageInlineSearch(BuildContext context, {required PageInlineSearch search, String initial = ''}) =>
    showDsPanel<void>(
      context: context,
      builder: (_) => _PageSearchPanel(search: search, initial: initial),
    );

final class _PageSearchPanel extends StatefulWidget {
  const _PageSearchPanel({required this.search, required this.initial});

  final PageInlineSearch search;
  final String initial;

  @override
  State<_PageSearchPanel> createState() => _PageSearchPanelState();
}

final class _PageSearchPanelState extends State<_PageSearchPanel> {
  late final TextEditingController _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final word = _field.text.trim();
    if (word.isEmpty) return;
    widget.search.take(word);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DsPanel(
      title: Text(widget.search.hint),
      child: DsSearchField(
        controller: _field,
        autofocus: true,
        placeholder: widget.search.hint,
        semanticLabel: widget.search.hint,
        onSubmitted: (_) => _submit(),
      ),
    );
  }
}
