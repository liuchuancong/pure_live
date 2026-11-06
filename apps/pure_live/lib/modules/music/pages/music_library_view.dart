import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/page_layout_scope.dart' show PageLayoutScope;
import 'package:pure_live/modules/music/controller/music_library.dart' show musicFavouritesProvider;
import 'package:pure_live/modules/music/controller/music_online_playlists.dart' show musicSonglistSearchProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_playback_settings.dart'
    show MusicSourceNameType, musicPlaybackSettingsProvider, musicSourceDisplayName;
import 'package:pure_live/modules/music/controller/music_search.dart';
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceListProvider, musicSourceProvider;
import 'package:pure_live/modules/music/controller/sources/music_browse_source.dart' show musicCapabilityOf;
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart'
    show MusicPlaylistInfo, MusicPlaylistPage, SonglistSearch;
import 'package:pure_live/modules/music/music_page.dart' show MusicView;
import 'package:pure_live/modules/music/pages/music_playlist_card.dart' show MusicPlaylistCard, MusicPlaylistGrid;
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/shared.dart' show LiveWindow;

/// The library: a search, its history and the songs it answers, each row
/// playing the answer from that song on. Another view can hand it a word to
/// search — 推荐's hot chip — which it runs as it mounts.
final class MusicLibraryView extends ConsumerStatefulWidget {
  const MusicLibraryView({
    required this.search,
    required this.onOpenSonglist,
    this.initialQuery,
    this.onQueryUsed,
    super.key,
  });

  final TextEditingController search;

  /// Opens a 歌单-search hit in the songlists view.
  final ValueChanged<MusicPlaylistInfo> onOpenSonglist;

  /// The word another view (推荐's hot chip) or the toolbar asked this one
  /// to search; taken once, when the view mounts or the word changes.
  final String? initialQuery;

  /// Called as [initialQuery] is taken, so a later visit does not re-run it.
  final VoidCallback? onQueryUsed;

  @override
  ConsumerState<MusicLibraryView> createState() => MusicLibraryViewState();
}

/// The head tab strip's two answers, the strings the tabs carry: the songs
/// ask and the 歌单 ask.
const String _kSongsTab = 'songs';
const String _kSonglistsTab = 'songlists';

final class MusicLibraryViewState extends ConsumerState<MusicLibraryView> {
  /// The display page the wide window's pager shows over the accumulated
  /// answers; a shorter list (a new query) reads as its first page.
  int _asked = 1;

  static const int _pageSize = 30;

  /// The word typed since the last debounce tick, the field's focus, and
  /// the ask in flight — the search suggestion overlay lives on all three:
  /// it shows while the field holds the focus and a word that is not the
  /// committed query yet, the reference's tip list.
  String _typed = '';

  /// Whether the search answers playlists (歌单) instead of songs, the
  /// reference's search-type switch.
  bool _songlist = false;

  FocusNode? _focus;
  Timer? _suggestDebounce;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()..addListener(_onFocusChanged);
    _seedQuery();
  }

  /// Searches the word another view handed this one — 推荐's hot chip — once
  /// the frame is up, so the ask does not move the provider mid-build.
  void _seedQuery() {
    final word = widget.initialQuery?.trim();
    if (word == null || word.isEmpty) return;
    widget.onQueryUsed?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runSearch(word, ref.read(musicSearchProvider.notifier));
    });
  }

  @override
  void didUpdateWidget(MusicLibraryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The page is kept while the module's menu moves, so a word handed
    // while this view is already showing arrives as a new query here.
    if (widget.initialQuery != oldWidget.initialQuery) _seedQuery();
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _focus
      ?..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  /// The typed word follows the keystrokes on a short debounce, so the
  /// suggestion ask trails the typing instead of riding every key.
  void _onTyped(String value) {
    _suggestDebounce?.cancel();
    if (value.trim().isEmpty) {
      if (_typed.isNotEmpty) setState(() => _typed = '');
      return;
    }
    _suggestDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _typed = value);
    });
  }

  /// Commits [word] as the search: the field reads it, the query moves, and
  /// the overlay goes away because the word is the query now.
  void _runSearch(String word, MusicSearchController controller) {
    widget.search
      ..text = word
      ..selection = TextSelection.collapsed(offset: word.length);
    setState(() => _typed = word);
    unawaited(controller.search(word));
  }

  /// The page actually shown: [_asked] pulled back into the list's range.
  int _pageOf(int count) {
    if (count <= (_asked - 1) * _pageSize) return 1;
    return _asked;
  }

  /// Moves the pager to [next]: a page in hand moves without a request, one
  /// past the hand asks the source and only moves when the page arrived.
  Future<void> _goToPage(int next, {required MusicSearchController controller}) async {
    final songs = ref.read(musicSearchProvider).songs;
    final inHand = songs.length ~/ _pageSize;
    if (next <= _pageOf(songs.length) || next > inHand + 1) return;
    if (next > inHand) {
      final before = songs.length;
      await controller.loadMore();
      if (!mounted) return;
      if (ref.read(musicSearchProvider).songs.length <= before) return;
    }
    if (!mounted) return;
    setState(() => _asked = next);
  }

  @override
  Widget build(BuildContext context) {
    final search = widget.search;
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    // The page's gutter, the same measure the live module's pages keep.
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final state = ref.watch(musicSearchProvider);
    final controller = ref.read(musicSearchProvider.notifier);
    final history = ref.watch(musicSearchHistoryProvider);
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    final playerController = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    final settings = ref.watch(musicPlaybackSettingsProvider);
    final showSource = settings.showSource;
    final hot = settings.showHotSearches
        ? ref.watch(musicHotSearchesProvider).value ?? const <String>[]
        : const <String>[];
    final sourceId = ref.watch(musicSearchSourceIdProvider);
    final sourceNames = {
      for (final source in ref.watch(musicSourceListProvider))
        source.id: musicSourceDisplayName(t, settings.sourceNameType, source.id, source.name),
    };
    void play(int index) => unawaited(playerController.playAll(state.songs, index: index));
    void runHistory(String query) => _runSearch(query, controller);
    // The tip list lives while the field holds the focus and a word that is
    // not the committed query yet — the reference's typing overlay.
    final word = _typed.trim();
    final showTips = (_focus?.hasFocus ?? false) && word.isNotEmpty && word != state.query;

    Widget songAt(int index) {
      final song = state.songs[index];
      final subtitle = [
        song.artist,
        if (showSource) sourceNames[song.sourceId] ?? '',
      ].where((part) => part.isNotEmpty).join(' · ');
      return MusicSongRow(
        track: song,
        number: index + 1,
        playing: playingId == song.id,
        favourite: favourites.contains(song),
        subtitle: subtitle.isEmpty ? null : subtitle,
        onPlay: () => play(index),
        onFavourite: () => unawaited(favouriteController.toggle(song)),
        onPlayNext: () => unawaited(playerController.playNext(song)),
        onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
        onDownload: () => unawaited(downloadTrackWithToast(context, ref, song)),
        onToggleSource: () => unawaited(showToggleSourceDialog(context, ref, song)),
      );
    }

    // The answer's own head: how many songs are in hand, and the two verbs
    // the whole answer has. Every other song list in the module gives them —
    // the charts, the playlists, the album, the artist, 我的列表, 本地音乐 —
    // and here the page only had the number, so a search answer could only be
    // taken one row at a time.
    Widget resultsHead() {
      final songs = state.songs;
      return Padding(
        padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s8),
        child: Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: Text(
                t.music.songsCount(count: songs.length),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.textSubtle),
              ),
            ),
            Wrap(
              spacing: DsSpace.s8,
              runSpacing: DsSpace.s8,
              children: [
                DsButton(
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.play, size: 16),
                  onPressed: () => unawaited(playerController.playAll(songs)),
                  child: Text(t.music.playAll),
                ),
                // A one-song answer has nothing to shuffle; the verb would be
                // a button that does not do anything.
                if (songs.length > 1)
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    leading: const DsIcon(DsIcons.shuffle, size: 16),
                    onPressed: () => unawaited(playerController.playAll([...songs]..shuffle(math.Random()))),
                    child: Text(t.music.modeRandom),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final Widget body;
    if (state.query.isEmpty) {
      body = history.isEmpty && hot.isEmpty
          ? Center(
              child: DsEmptyState(
                icon: DsIcon(MusicView.library.icon),
                title: Text(t.music.searchIdleTitle),
                description: Text(t.music.searchIdleDescription),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: DsSpace.s16),
              children: [
                if (hot.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s8),
                    child: Text(t.music.searchHot, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
                    child: Wrap(
                      spacing: DsSpace.s8,
                      runSpacing: DsSpace.s8,
                      children: [
                        for (final word in hot)
                          DsChip(
                            label: Text(word),
                            selected: false,
                            onChanged: (on) {
                              if (on) runHistory(word);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
                if (history.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, DsSpace.s12, DsSpace.s4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.music.searchHistory,
                            style: theme.typography.caption.copyWith(color: colors.textSubtle),
                          ),
                        ),
                        DsButton(
                          variant: DsButtonVariant.secondary,
                          size: DsSize.sm,
                          onPressed: () => unawaited(ref.read(musicSearchHistoryProvider.notifier).clear()),
                          child: Text(t.music.searchHistoryClear),
                        ),
                      ],
                    ),
                  ),
                  DsListSection(
                    children: [
                      for (final query in history)
                        DsListRow(
                          leading: const DsIcon(DsIcons.history),
                          title: Text(query),
                          showChevron: true,
                          onPressed: () => runHistory(query),
                          trailing: DsButton.icon(
                            variant: DsButtonVariant.secondary,
                            size: DsSize.sm,
                            semanticLabel: t.music.searchHistoryRemove,
                            onPressed: () => unawaited(ref.read(musicSearchHistoryProvider.notifier).remove(query)),
                            icon: const DsIcon(DsIcons.x, size: 16),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            );
    } else if (state.songs.isEmpty && state.loading) {
      body = const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)));
    } else if (state.songs.isEmpty && state.error != null) {
      body = Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.music.searchFailed),
          description: Text(state.error!),
          actions: [DsButton(onPressed: () => unawaited(controller.retry()), child: Text(t.common.retry))],
        ),
      );
    } else if (state.songs.isEmpty) {
      body = Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.searchX),
          title: Text(t.music.noResultsTitle),
          description: Text(t.music.noResultsDescription),
        ),
      );
    } else {
      // A wide window pages the answers by number — one display page is the
      // local slice, the pager asks the source for one more page past the
      // hand — and a narrow one appends as the viewer scrolls.
      final wide = MediaQuery.sizeOf(context).width >= LiveWindow.paging;
      final page = _pageOf(state.songs.length);
      if (!wide) {
        body = NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.depth != 0) return false;
            if (notification.metrics.pixels < notification.metrics.maxScrollExtent - 600) return false;
            unawaited(controller.loadMore());
            return false;
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              resultsHead(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: DsSpace.s16),
                  itemCount: state.songs.length + (state.hasMore ? 1 : 0) + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return const MusicSongTableHeader();
                    final item = index - 1;
                    if (item >= state.songs.length) {
                      return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24)));
                    }
                    return songAt(item);
                  },
                ),
              ),
            ],
          ),
        );
      } else {
        final start = (page - 1) * _pageSize;
        final pageCount = state.songs.length ~/ _pageSize + (state.hasMore ? 1 : 0);
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  resultsHead(),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: DsSpace.s16),
                      itemCount: math.min(_pageSize, state.songs.length - start) + 1,
                      itemBuilder: (context, index) =>
                          index == 0 ? const MusicSongTableHeader() : songAt(start + index - 1),
                    ),
                  ),
                ],
              ),
            ),
            if (pageCount > 1)
              Padding(
                padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s12),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: DsSpace.s8,
                    children: [
                      if (state.loading) const SizedBox(width: 14, height: 14, child: DsSpinner()),
                      DsPagination(
                        page: page,
                        pageCount: pageCount,
                        onChanged: (next) => unawaited(_goToPage(next, controller: controller)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      }
    }

    // The pane's width decision is the shell's, never a local measure — the
    // live module's history-head rule: wide, the source rail closes the tabs'
    // line; narrow (under the shell's toolbar floor, about 640 of pane once
    // the shell's own chrome is paid) it wraps under the bar as its own
    // compact row instead.
    final narrow = PageLayoutScope.isNarrow(context);

    // The reference's source rail: every platform plus the 'all' choice that
    // searches them at once. It steers the songs, not the songlists.
    Widget sourceRail() {
      return DsChoiceChips<String>(
        options: [
          DsChipOption(
            value: kMusicSearchAllSourceId,
            label: Text(
              settings.sourceNameType == MusicSourceNameType.alias ? t.music.sourceAliasAll : t.music.searchSourceAll,
            ),
          ),
          for (final entry in sourceNames.entries) DsChipOption(value: entry.key, label: Text(entry.value)),
        ],
        value: sourceId,
        onChanged: (id) {
          ref.read(musicSearchSourceIdProvider.notifier).source = id;
          if (state.query.isNotEmpty) unawaited(controller.search(state.query));
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
          child: DsSearchField(
            controller: search,
            autofocus: true,
            focusNode: _focus,
            placeholder: t.music.searchHint,
            onChanged: _onTyped,
            onSubmitted: (value) {
              // The submit commits at once: the pending debounce ask drops
              // and the overlay closes because the word is the query now.
              _suggestDebounce?.cancel();
              setState(() => _typed = value);
              unawaited(controller.search(value));
            },
          ),
        ),
        // The head's one 44px line, the module's own tab grammar: the
        // reference's search-type switch reads as tabs — 歌曲 / 歌单 — and,
        // while the songs answer is the one showing, the source rail closes
        // the line's end. The rail keeps its natural width up to a cap and
        // scrolls inside it, so a long rail cannot crowd the tabs.
        Padding(
          padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
          child: SizedBox(
            height: 44,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: DsTabs<String>(
                        value: _songlist ? _kSonglistsTab : _kSongsTab,
                        onChanged: (tab) => setState(() => _songlist = tab == _kSonglistsTab),
                        style: kMusicFeedTabsStyle,
                        tabs: [
                          DsTab(value: _kSongsTab, label: Text(t.music.searchTypeSongs)),
                          DsTab(value: _kSonglistsTab, label: Text(t.music.searchTypeSonglists)),
                        ],
                        semanticLabel: t.music.searchTypeSongs,
                      ),
                    ),
                    if (!narrow && !_songlist)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.55),
                        child: sourceRail(),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        // A narrow pane wraps the rail under the bar as its own compact row —
        // every source stays one tap away instead of hiding behind a
        // switcher, the live module's rule for a stacked head.
        if (narrow && !_songlist)
          Padding(padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8), child: sourceRail()),
        Expanded(
          child: showTips
              ? _tips(word)
              : _songlist
              ? _SonglistResults(query: state.query, onOpen: widget.onOpenSonglist)
              : body,
        ),
      ],
    );
  }

  /// The reference's tip list: the source's completions for the typed word,
  /// one row each, a tap committing the word as the search.
  Widget _tips(String word) {
    final tips = ref.watch(musicSearchSuggestionsProvider(word)).value ?? const <String>[];
    if (tips.isEmpty) return const SizedBox.shrink();
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    return ListView(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s4, inset, DsSpace.s16),
      children: [
        DsListSection(
          children: [
            for (final tipWord in tips)
              DsListRow(
                leading: const DsIcon(DsIcons.search, size: 16),
                title: Text(tipWord),
                onPressed: () => _runSearch(tipWord, ref.read(musicSearchProvider.notifier)),
              ),
          ],
        ),
      ],
    );
  }
}

/// The library's 歌单 search answers: the committed query's playlists on the
/// active source, page by page, opening the songlists view's detail.
final class _SonglistResults extends ConsumerStatefulWidget {
  const _SonglistResults({required this.query, required this.onOpen});

  /// The committed keyword; empty shows the idle pane.
  final String query;

  /// Opens a hit in the songlists view.
  final ValueChanged<MusicPlaylistInfo> onOpen;

  @override
  ConsumerState<_SonglistResults> createState() => _SonglistResultsState();
}

final class _SonglistResultsState extends ConsumerState<_SonglistResults> {
  /// How many pages the viewer has asked for; the family provider caches
  /// each one, so widening this range re-reads, it does not re-fetch.
  int _page = 1;

  @override
  void didUpdateWidget(_SonglistResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new keyword restarts the walk; the stale pages of the old word must
    // not ride in.
    if (oldWidget.query != widget.query && _page != 1) setState(() => _page = 1);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (musicCapabilityOf<SonglistSearch>(ref.watch(musicSourceProvider)) == null) {
      return Center(
        child: DsEmptyState(icon: const DsIcon(DsIcons.listMusic), title: Text(t.music.songlistSearchUnsupported)),
      );
    }
    if (widget.query.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.search),
          title: Text(t.music.searchIdleTitle),
          description: Text(t.music.searchIdleDescription),
        ),
      );
    }
    final pages = <AsyncValue<MusicPlaylistPage>>[
      for (var page = 1; page <= _page; page++)
        ref.watch(musicSonglistSearchProvider((keyword: widget.query, page: page))),
    ];
    final items = <MusicPlaylistInfo>[
      for (final page in pages)
        if (page.value != null) ...page.value!.items,
    ];
    final loading = pages.any((page) => page.isLoading);
    final error = pages.where((page) => page.hasError).firstOrNull;
    final total = pages.lastOrNull?.value?.total ?? 0;
    // The source's word and its count both have to allow another page: an
    // empty answer ends the road, and a platform that repeats its last window
    // is stopped by the count it did report.
    final statedMore = pages.lastOrNull?.value?.hasMore;
    if (!loading && items.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.searchX),
          title: Text(error != null ? t.music.onlineLoadFailed : t.music.noResultsTitle),
          description: Text(t.music.noResultsDescription),
          actions: [
            if (error != null)
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () {
                  for (var page = 1; page <= _page; page++) {
                    ref.invalidate(musicSonglistSearchProvider((keyword: widget.query, page: page)));
                  }
                },
                child: Text(t.common.retry),
              ),
          ],
        ),
      );
    }
    return MusicPlaylistGrid<MusicPlaylistInfo>(
      items: items,
      isLoading: loading,
      hasMore: (statedMore ?? true) && (total == 0 || items.length < total),
      onLoadMore: () async {
        setState(() => _page += 1);
      },
      itemBuilder: (context, info) => MusicPlaylistCard.online(info: info, onOpen: () => widget.onOpen(info)),
    );
  }
}

/// 歌单: the viewer's own playlists and the songs in the one that is open.
