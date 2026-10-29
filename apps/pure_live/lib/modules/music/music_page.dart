import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/app/app.dart' show RouteNames;
import 'package:pure_live/app/providers/settings/download_directory_provider.dart'
    show DownloadDirectoryPaths, downloadDirectoryProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_downloads.dart';
import 'package:pure_live/modules/music/controller/music_hotkeys.dart'
    show musicHotkeyBindings;
import 'package:pure_live/modules/music/controller/music_library.dart';
import 'package:pure_live/modules/music/controller/music_local.dart';
import 'package:pure_live/modules/music/controller/music_online_playlists.dart'
    show musicOnlineHotTagsProvider, musicOnlinePlaylistDetailProvider, musicOnlinePlaylistsProvider,
        musicPlaylistSortLabel, musicPlaylistSortsProvider, musicPlaylistTagGroupsProvider, musicSonglistSearchProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_playlists.dart';
import 'package:pure_live/modules/music/controller/music_search.dart';
import 'package:pure_live/modules/music/controller/music_settings.dart'
    show MusicSourceNameType, musicSettingsProvider, musicSourceDisplayName;
import 'package:pure_live/modules/music/controller/music_source.dart'
    show musicSourceListProvider, musicSourceProvider;
import 'package:pure_live/modules/music/controller/music_sources.dart' show musicSourcesProvider;
import 'package:pure_live/modules/music/controller/sources/online_playlist_models.dart'
    show MusicPlaylistInfo, MusicPlaylistPage, MusicPlaylistTag, MusicPlaylistTagGroup, OnlinePlaylists,
        SonglistSearch;
import 'package:pure_live/modules/music/pages/music_player_page.dart' show musicDurationText;
import 'package:pure_live/modules/music/pages/music_playlist_card.dart'
    show MusicCardMenuButton, MusicPlaylistCard, MusicPlaylistGrid;
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_widgets.dart';

/// The music module's views. The reference's rail — 搜索 / 歌单 / 排行榜 /
/// 我的列表 — is what the module's menu lists, and the app's own surfaces sit
/// beside them: the device's files and the download centre.
enum MusicView {
  /// The library: a search, its history, its songs, and the player that
  /// answers them.
  library,

  /// The viewer's playlists, the reference's 歌单.
  songlists,

  /// Charts: the source's own leaderboards, the reference's 排行榜.
  toplists,

  /// The viewer's own lists — collected and recently played songs.
  mine,

  /// The device's own music files, the reference's 本地音乐.
  local,

  /// The download queue and its tasks, the reference's 下载管理.
  downloads;

  /// The view's icon, on its empty state.
  DsIconData get icon => switch (this) {
    MusicView.library => DsIcons.discAlbum,
    MusicView.songlists => DsIcons.listMusic,
    MusicView.toplists => DsIcons.chartColumn,
    MusicView.mine => DsIcons.library,
    MusicView.local => DsIcons.folderOpen,
    MusicView.downloads => DsIcons.download,
  };
}

/// The music module's entry: a real player over the module's source.
///
/// The library searches and plays, the charts are the source's own boards,
/// 歌单 keeps the viewer's own lists, 我的列表 keeps the songs this module
/// collected and played, 本地音乐 plays the device's files, and 下载 keeps
/// the queue.
final class MusicPage extends ConsumerStatefulWidget {
  /// The music module's entry page, opening on [view].
  const MusicPage({this.view = MusicView.library, super.key});

  /// The view the page opens on; the module's menu names it.
  final MusicView view;

  @override
  ConsumerState<MusicPage> createState() => _MusicPageState();
}

final class _MusicPageState extends ConsumerState<MusicPage> {
  /// The view the page is showing.
  late MusicView _view = widget.view;

  /// The online playlist the library's 歌单 search asked to open, handed to
  /// the songlists view when it next mounts.
  MusicPlaylistInfo? _openSonglist;

  /// The library's search field, kept across view switches so a query is not
  /// lost by looking at the charts.
  final TextEditingController _search = TextEditingController();

  /// The board the charts view has open; null takes the first one.
  String? _catalogId;

  @override
  void didUpdateWidget(MusicPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shell keeps this state while the menu moves between the module's
    // entries, so a new entry has to move the page to its view.
    if (widget.view != _view) setState(() => _view = widget.view);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: musicHotkeyBindings(ref),
      child: Focus(
        autofocus: true,
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: _ModuleHeader(),
        ),
        Expanded(
          child: switch (_view) {
            MusicView.library => _LibraryView(
              search: _search,
              onOpenSonglist: (info) => setState(() {
                _view = MusicView.songlists;
                _openSonglist = info;
              }),
            ),
            MusicView.songlists => _PlaylistsView(initialOnlineOpen: _openSonglist),
            MusicView.toplists => _ChartsView(
              catalogId: _catalogId,
              onCatalog: (id) => setState(() => _catalogId = id),
            ),
            MusicView.mine => const _MineView(),
            MusicView.local => const _LocalView(),
            MusicView.downloads => const _DownloadsView(),
          },
        ),
        const _MiniPlayer(),
      ],
        ),
      ),
    );
  }
}

/// The module's mark: the music note in a tinted tile, the module's name,
/// and one line on what feeds it — the imported lx sources, or the built-in
/// lx-music channel when none are imported.
final class _ModuleHeader extends ConsumerWidget {
  const _ModuleHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final t = context.t;
    final sources = ref.watch(musicSourcesProvider).where((source) => source.enabled).length;
    final active = musicDownloadsActive(ref.watch(musicDownloadsProvider));
    return Row(
      spacing: DsSpace.s12,
      children: [
        Container(
          width: theme.sizes.md,
          height: theme.sizes.md,
          decoration: DsBoxDecoration(
            color: colors.accentTint,
            borderRadius: theme.radii.controlCorners(null, theme.sizes.md),
          ),
          child: Center(
            child: DsIcon(DsIcons.music, size: theme.sizes.iconMd, color: colors.accentText),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s3,
            children: [
              Text(
                t.music.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: colors.text),
              ),
              Text(
                active > 0
                    ? t.music.downloadsActive(count: active)
                    : sources == 0
                    ? t.music.tagline
                    : t.music.sourcesReady(count: sources),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The library: a search, its history and the songs it answers, each row
/// playing the answer from that song on.
final class _LibraryView extends ConsumerStatefulWidget {
  const _LibraryView({required this.search, required this.onOpenSonglist});

  final TextEditingController search;

  /// Opens a 歌单-search hit in the songlists view.
  final ValueChanged<MusicPlaylistInfo> onOpenSonglist;

  @override
  ConsumerState<_LibraryView> createState() => _LibraryViewState();
}

final class _LibraryViewState extends ConsumerState<_LibraryView> {
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
    final state = ref.watch(musicSearchProvider);
    final controller = ref.read(musicSearchProvider.notifier);
    final history = ref.watch(musicSearchHistoryProvider);
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    final playerController = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    final settings = ref.watch(musicSettingsProvider);
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
      final subtitle = [song.artist, if (showSource) sourceNames[song.sourceId] ?? '']
          .where((part) => part.isNotEmpty)
          .join(' · ');
      return MusicSongRow(
        track: song,
        playing: playingId == song.id,
        favourite: favourites.contains(song),
        subtitle: subtitle.isEmpty ? null : subtitle,
        onPlay: () => play(index),
        onFavourite: () => unawaited(favouriteController.toggle(song)),
        onPlayNext: () => unawaited(playerController.playNext(song)),
        onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
        onDownload: () => unawaited(downloadTrackWithToast(context, ref, song)),
      );
    }

    final Widget body;
    if (state.query.isEmpty) {
      body = history.isEmpty && hot.isEmpty
          ? Center(
              child: DsEmptyState(
                icon: const DsIcon(DsIcons.music),
                title: Text(t.music.searchIdleTitle),
                description: Text(t.music.searchIdleDescription),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: DsSpace.s16),
              children: [
                if (hot.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
                    child: Text(
                      t.music.searchHot,
                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
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
                    padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s12, DsSpace.s4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.music.searchHistory,
                            style: theme.typography.caption.copyWith(color: colors.textSubtle),
                          ),
                        ),
                        DsButton(
                          variant: DsButtonVariant.ghost,
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
                            variant: DsButtonVariant.ghost,
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
      final wide = MediaQuery.sizeOf(context).width >= 768;
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
                child: Text(
                  t.music.songsCount(count: state.songs.length),
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: DsSpace.s16),
                  itemCount: state.songs.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.songs.length) {
                      return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24)));
                    }
                    return songAt(index);
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
                    child: Text(
                      t.music.songsCount(count: state.songs.length),
                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: DsSpace.s16),
                      itemCount: math.min(_pageSize, state.songs.length - start),
                      itemBuilder: (context, index) => songAt(start + index),
                    ),
                  ),
                ],
              ),
            ),
            if (pageCount > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s12),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
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
              // The reference's search-type switch: songs or songlists.
              DsSegmentedControl<bool>(
                segments: [
                  DsSegment(value: false, label: Text(t.music.searchTypeSongs)),
                  DsSegment(value: true, label: Text(t.music.searchTypeSonglists)),
                ],
                value: _songlist,
                onChanged: (songlist) => setState(() => _songlist = songlist),
              ),
            ],
          ),
        ),
        // The reference's source rail: every platform plus the 'all' choice
        // that searches them at once. It steers the songs, not the songlists.
        if (!_songlist)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            child: DsTopNav<String>(
              items: [
                DsTopNavItem(
                  value: kMusicSearchAllSourceId,
                  label: Text(
                    settings.sourceNameType == MusicSourceNameType.alias
                        ? t.music.sourceAliasAll
                        : t.music.searchSourceAll,
                  ),
                ),
                for (final entry in sourceNames.entries)
                  DsTopNavItem(value: entry.key, label: Text(entry.value)),
              ],
              value: sourceId,
              onChanged: (id) {
                ref.read(musicSearchSourceIdProvider.notifier).source = id;
                if (state.query.isNotEmpty) unawaited(controller.search(state.query));
              },
            ),
          ),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s16),
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
    final source = ref.watch(musicSourceProvider);
    if (source is! SonglistSearch) {
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
    final items = <MusicPlaylistInfo>[for (final page in pages) if (page.value != null) ...page.value!.items];
    final loading = pages.any((page) => page.isLoading);
    final error = pages.where((page) => page.hasError).firstOrNull;
    final total = pages.lastOrNull?.value?.total ?? 0;
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
      hasMore: items.length < total,
      onLoadMore: () async {
        setState(() => _page += 1);
      },
      itemBuilder: (context, info) => MusicPlaylistCard.online(info: info, onOpen: () => widget.onOpen(info)),
    );
  }
}

/// 歌单: the viewer's own playlists and the songs in the one that is open.
final class _PlaylistsView extends ConsumerStatefulWidget {
  const _PlaylistsView({this.initialOnlineOpen});

  /// The online playlist a caller (the library's 歌单 search) asked to
  /// open; consumed once the view mounts.
  final MusicPlaylistInfo? initialOnlineOpen;

  @override
  ConsumerState<_PlaylistsView> createState() => _PlaylistsViewState();
}

final class _PlaylistsViewState extends ConsumerState<_PlaylistsView> {
  String? _openId;
  bool _selecting = false;
  final Set<audio.MusicTrack> _selected = <audio.MusicTrack>{};

  /// Whether the view browses the source's online playlists (在线歌单)
  /// instead of the viewer's own lists; LX keeps both behind one rail.
  bool _online = false;

  /// The online playlist opened to its tracks; null shows the browse list.
  MusicPlaylistInfo? _onlineOpen;

  @override
  void initState() {
    super.initState();
    final open = widget.initialOnlineOpen;
    if (open != null) {
      _online = true;
      _onlineOpen = open;
    }
  }

  Future<void> _create() async {
    final playlist = await showCreatePlaylistDialog(context, ref);
    if (playlist != null && mounted) {
      setState(() {
        _openId = playlist.id;
        _selecting = false;
        _selected.clear();
      });
    }
  }

  Future<void> _rename(MusicPlaylist playlist) async {
    final t = context.t;
    final field = TextEditingController(text: playlist.name);
    final name = await showDsDialog<String>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(t.music.playlistRenameTitle),
        icon: const DsIcon(DsIcons.pencil),
        description: DsTextField(
          controller: field,
          autofocus: true,
          clearable: true,
          semanticLabel: t.music.playlistName,
        ),
        actions: [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          DsButton(onPressed: () => Navigator.of(context).pop(field.text), child: Text(t.common.confirm)),
        ],
      ),
    );
    field.dispose();
    if (name == null || name.trim().isEmpty) return;
    await ref.read(musicPlaylistsProvider.notifier).rename(playlist.id, name);
  }

  Future<void> _downloadAll(MusicPlaylist playlist) async {
    final t = context.t;
    final queued = await ref
        .read(musicDownloadsProvider.notifier)
        .downloadAll(playlist.tracks, listName: playlist.name);
    if (!mounted) return;
    showDsToast(
      context: context,
      title: t.music.downloadAllQueued(count: queued),
      status: queued > 0 ? DsStatus.success : DsStatus.warning,
    );
  }

  Future<void> _delete(MusicPlaylist playlist) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.music.playlistDeleteTitle(name: playlist.name),
      description: t.music.playlistDeleteDesc,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(musicPlaylistsProvider.notifier).delete(playlist.id);
    if (mounted) {
      setState(() {
        _openId = null;
        _selecting = false;
        _selected.clear();
      });
    }
  }

  /// Reads a playlist file the viewer picked; the list lands as a new playlist.
  Future<void> _import() async {
    final t = context.t;
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: t.music.playlistImport,
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      final path = file?.path;
      if (!mounted || path == null) return;
      final playlist = await ref.read(musicPlaylistsProvider.notifier).importFromFile(path);
      if (!mounted) return;
      showDsToast(
        context: context,
        title: playlist == null
            ? t.music.playlistImportFailed(error: t.music.playlistImportInvalid)
            : t.music.playlistImportDone(name: playlist.name),
        status: playlist == null ? DsStatus.danger : DsStatus.success,
      );
      if (playlist != null) {
        setState(() {
          _openId = playlist.id;
          _selecting = false;
          _selected.clear();
        });
      }
    } on Object catch (failure) {
      if (mounted) {
        showDsToast(
          context: context,
          title: t.music.playlistImportFailed(error: '$failure'),
          status: DsStatus.danger,
        );
      }
    }
  }

  /// Writes a playlist into the download folder the module already uses.
  Future<void> _export(MusicPlaylist playlist) async {
    final t = context.t;
    try {
      final directory = ref.read(downloadDirectoryProvider).effectivePath;
      final path = await ref.read(musicPlaylistsProvider.notifier).exportToDirectory(playlist, directory);
      if (mounted) {
        showDsToast(
          context: context,
          title: t.music.playlistExportDone(path: path),
          status: DsStatus.success,
        );
      }
    } on Object catch (failure) {
      if (mounted) {
        showDsToast(
          context: context,
          title: t.music.playlistExportFailed(error: '$failure'),
          status: DsStatus.danger,
        );
      }
    }
  }

  /// Enters or leaves the reference's multi-selection.
  void _setSelecting({required bool selecting}) {
    setState(() {
      _selecting = selecting;
      if (!selecting) _selected.clear();
    });
  }

  void _toggleSelected(audio.MusicTrack track) {
    setState(() {
      if (!_selected.remove(track)) _selected.add(track);
    });
  }

  void _selectAll(MusicPlaylist playlist) {
    setState(() {
      _selected
        ..clear()
        ..addAll(playlist.tracks);
    });
  }

  Future<void> _removeSelected(MusicPlaylist playlist) async {
    final tracks = List<audio.MusicTrack>.of(_selected);
    if (tracks.isEmpty) return;
    final t = context.t;
    await ref.read(musicPlaylistsProvider.notifier).removeTracks(playlist.id, tracks);
    if (!mounted) return;
    showDsToast(
      context: context,
      title: t.music.selectionRemoveDone(count: tracks.length),
      status: DsStatus.success,
    );
    _setSelecting(selecting: false);
  }

  Future<void> _downloadSelected(MusicPlaylist playlist) async {
    final tracks = List<audio.MusicTrack>.of(_selected);
    if (tracks.isEmpty) return;
    final t = context.t;
    final queued = await ref.read(musicDownloadsProvider.notifier).downloadAll(tracks, listName: playlist.name);
    if (!mounted) return;
    showDsToast(
      context: context,
      title: t.music.downloadAllQueued(count: queued),
      status: queued > 0 ? DsStatus.success : DsStatus.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final playlists = ref.watch(musicPlaylistsProvider);
    final open = _openId == null ? null : playlists.where((playlist) => playlist.id == _openId).firstOrNull;
    if (open != null) return _playlistDetail(open);
    if (_onlineOpen != null) {
      return _OnlinePlaylistDetail(info: _onlineOpen!, onBack: () => setState(() => _onlineOpen = null));
    }
    if (_online) {
      return _OnlinePlaylistBrowse(
        mineCount: playlists.length,
        onOpen: (info) => setState(() => _onlineOpen = info),
        onBackToMine: () => setState(() => _online = false),
      );
    }

    final tabs = _SonglistTabs(online: _online, mineCount: playlists.length, onChanged: (online) {
      setState(() {
        _online = online;
        _onlineOpen = null;
      });
    });

    // One toolbar row, the areas page's measure: the tabs take the leftover
    // width, the count and the verbs close the row.
    final Widget toolbar = SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s4),
        child: Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(child: tabs),
            if (!_online)
              Text(
                t.music.playlistsCount(count: playlists.length),
                style: theme.typography.caption.copyWith(color: colors.textSubtle),
              ),
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.arrowDownToLine, size: 16),
              onPressed: () => unawaited(_import()),
              child: Text(t.music.playlistImport),
            ),
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.plus, size: 16),
              onPressed: () => unawaited(_create()),
              child: Text(t.music.playlistCreate),
            ),
          ],
        ),
      ),
    );

    if (playlists.isEmpty && !_online) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toolbar,
          Expanded(
            child: Center(
              child: DsEmptyState(
                icon: const DsIcon(DsIcons.listMusic),
                title: Text(t.music.playlistsEmptyTitle),
                description: Text(t.music.playlistsEmptyDescription),
                actions: [
                  DsButton(
                    leading: const DsIcon(DsIcons.plus, size: 16),
                    onPressed: () => unawaited(_create()),
                    child: Text(t.music.playlistCreate),
                  ),
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    leading: const DsIcon(DsIcons.arrowDownToLine, size: 16),
                    onPressed: () => unawaited(_import()),
                    child: Text(t.music.playlistImport),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toolbar,
        Expanded(
          child: MusicPlaylistGrid<MusicPlaylist>(
            items: playlists,
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s24),
            itemBuilder: (context, playlist) => MusicPlaylistCard.own(
              playlist: playlist,
              onOpen: () => setState(() {
                _openId = playlist.id;
                _selecting = false;
                _selected.clear();
              }),
              menuBuilder: (context) => MusicCardMenuButton(
                semanticLabel: t.music.moreActions,
                items: [
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.play),
                    label: Text(t.music.play),
                    onPressed: playlist.tracks.isEmpty
                        ? null
                        : () => unawaited(ref.read(musicPlayerProvider.notifier).playAll(playlist.tracks)),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.pencil),
                    label: Text(t.music.playlistRename),
                    onPressed: () => unawaited(_rename(playlist)),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.arrowUpFromLine),
                    label: Text(t.music.playlistExport),
                    onPressed: playlist.tracks.isEmpty ? null : () => unawaited(_export(playlist)),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.trash2),
                    label: Text(t.music.playlistDelete),
                    destructive: true,
                    onPressed: () => unawaited(_delete(playlist)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _playlistDetail(MusicPlaylist playlist) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    final player = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouritesController = ref.read(musicFavouritesProvider.notifier);
    final controller = ref.read(musicPlaylistsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s8, 0, DsSpace.s20, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: t.common.back,
                onPressed: () => setState(() {
                  _openId = null;
                  _selecting = false;
                  _selected.clear();
                }),
                icon: const DsIcon(DsIcons.chevronLeft),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s3,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.title.copyWith(color: colors.text),
                    ),
                    Text(
                      t.music.songsCount(count: playlist.tracks.length),
                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                    ),
                  ],
                ),
              ),
              DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: _selecting ? t.music.selectionCancel : t.music.selectionStart,
                onPressed: playlist.tracks.isEmpty ? null : () => _setSelecting(selecting: !_selecting),
                icon: DsIcon(_selecting ? DsIcons.x : DsIcons.listChecks, size: 16),
              ),
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.play, size: 16),
                onPressed: playlist.tracks.isEmpty ? null : () => unawaited(player.playAll(playlist.tracks)),
                child: Text(t.music.playAll),
              ),
              DsMenuAnchor(
                semanticLabel: t.music.moreActions,
                items: [
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.download),
                    label: Text(t.music.downloadAll),
                    onPressed: playlist.tracks.isEmpty ? null : () => unawaited(_downloadAll(playlist)),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.upload),
                    label: Text(t.music.playlistExport),
                    onPressed: playlist.tracks.isEmpty ? null : () => unawaited(_export(playlist)),
                  ),
                  DsMenuItem.submenu(
                    leading: const DsIcon(DsIcons.arrowUpDown),
                    label: Text(t.music.playlistSort),
                    submenu: [
                      DsMenuItem(
                        label: Text(t.music.sortByTitle),
                        onPressed: () => unawaited(controller.sortTracks(playlist.id, MusicPlaylistSort.title)),
                      ),
                      DsMenuItem(
                        label: Text(t.music.sortByArtist),
                        onPressed: () => unawaited(controller.sortTracks(playlist.id, MusicPlaylistSort.artist)),
                      ),
                      DsMenuItem(
                        label: Text(t.music.sortByAlbum),
                        onPressed: () => unawaited(controller.sortTracks(playlist.id, MusicPlaylistSort.album)),
                      ),
                      DsMenuItem(
                        label: Text(t.music.sortByDuration),
                        onPressed: () => unawaited(controller.sortTracks(playlist.id, MusicPlaylistSort.duration)),
                      ),
                      DsMenuItem(
                        label: Text(t.music.sortByShuffle),
                        onPressed: () => unawaited(controller.sortTracks(playlist.id, MusicPlaylistSort.shuffle)),
                      ),
                    ],
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.pencil),
                    label: Text(t.music.playlistRename),
                    onPressed: () => unawaited(_rename(playlist)),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.x),
                    label: Text(t.music.playlistClear),
                    onPressed: () => unawaited(controller.clear(playlist.id)),
                  ),
                  DsMenuItem(
                    leading: const DsIcon(DsIcons.trash2),
                    label: Text(t.music.playlistDelete),
                    destructive: true,
                    onPressed: () => unawaited(_delete(playlist)),
                  ),
                ],
                builder: (context, controller, _) => DsButton.icon(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  semanticLabel: t.music.moreActions,
                  onPressed: controller.toggle,
                  icon: const DsIcon(DsIcons.ellipsisVertical, size: 16),
                ),
              ),
            ],
          ),
        ),
        if (_selecting)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            child: Row(
              spacing: DsSpace.s8,
              children: [
                Expanded(
                  child: Text(
                    t.music.selectionCount(count: _selected.length),
                    style: theme.typography.caption.copyWith(color: colors.textSubtle),
                  ),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => _selectAll(playlist),
                  child: Text(t.music.selectionAll),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.listMusic, size: 16),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => unawaited(showAddTracksToPlaylistDialog(context, ref, _selected.toList())),
                  child: Text(t.music.addToPlaylist),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.download, size: 16),
                  onPressed: _selected.isEmpty ? null : () => unawaited(_downloadSelected(playlist)),
                  child: Text(t.music.selectionDownload),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: _selected.isEmpty ? null : () => unawaited(_removeSelected(playlist)),
                  child: Text(t.music.selectionRemove),
                ),
              ],
            ),
          ),
        Expanded(
          child: playlist.tracks.isEmpty
              ? Center(
                  child: DsEmptyState(
                    icon: const DsIcon(DsIcons.listMusic),
                    title: Text(t.music.playlistEmptyTitle),
                    description: Text(t.music.playlistEmptyDescription),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: DsSpace.s16),
                  itemCount: playlist.tracks.length,
                  itemBuilder: (context, index) {
                    final song = playlist.tracks[index];
                    return MusicSongRow(
                      track: song,
                      playing: playingId == song.id,
                      favourite: favourites.contains(song),
                      selecting: _selecting,
                      selected: _selected.contains(song),
                      onSelected: () => _toggleSelected(song),
                      onPlay: () => unawaited(player.playAll(playlist.tracks, index: index)),
                      onFavourite: () => unawaited(favouritesController.toggle(song)),
                      onRemove: () => unawaited(controller.removeTrack(playlist.id, song)),
                      onPlayNext: () => unawaited(player.playNext(song)),
                      onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
                      onDownload: () => unawaited(downloadTrackWithToast(context, ref, song, listName: playlist.name)),
                      onMoveUp: index == 0
                          ? null
                          : () => unawaited(controller.moveTrack(playlist.id, index, index - 1)),
                      onMoveDown: index == playlist.tracks.length - 1
                          ? null
                          : () => unawaited(controller.moveTrack(playlist.id, index, index + 1)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// The charts: the source's own boards, each one answer rather than a feed.
final class _ChartsView extends ConsumerWidget {
  const _ChartsView({required this.catalogId, required this.onCatalog});

  final String? catalogId;
  final ValueChanged<String> onCatalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final catalogs = ref.watch(musicCatalogsProvider);
    return catalogs.when(
      loading: () => const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28))),
      error: (error, _) => Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.music.chartsFailed),
          description: Text('$error'),
          actions: [DsButton(onPressed: () => ref.invalidate(musicCatalogsProvider), child: Text(t.common.retry))],
        ),
      ),
      data: (boards) {
        if (boards.isEmpty) {
          return Center(
            child: DsEmptyState(
              icon: const DsIcon(DsIcons.chartColumn),
              title: Text(t.music.chartsEmptyTitle),
              description: Text(t.music.chartsEmptyDescription),
            ),
          );
        }
        final selected = boards.firstWhere((board) => board.id == catalogId, orElse: () => boards.first);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
              child: SizedBox(
                height: 44,
                child: DsTopNav<String>(
                  value: selected.id,
                  onChanged: onCatalog,
                  items: [for (final board in boards) DsTopNavItem(value: board.id, label: Text(board.name))],
                ),
              ),
            ),
            Expanded(child: _ChartItems(catalog: selected)),
          ],
        );
      },
    );
  }
}

/// One board's songs, playing the whole board from the chosen row.
final class _ChartItems extends ConsumerWidget {
  const _ChartItems({required this.catalog});

  final audio.MusicCatalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final items = ref.watch(musicCatalogItemsProvider(catalog));
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    final playerController = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    return items.when(
      loading: () => const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28))),
      error: (error, _) => Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.music.chartsFailed),
          description: Text('$error'),
          actions: [
            DsButton(onPressed: () => ref.invalidate(musicCatalogItemsProvider(catalog)), child: Text(t.common.retry)),
          ],
        ),
      ),
      data: (songs) => songs.isEmpty
          ? Center(
              child: DsEmptyState(
                icon: const DsIcon(DsIcons.chartColumn),
                title: Text(t.music.chartsEmptyTitle),
                description: Text(t.music.chartsEmptyDescription),
              ),
            )
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return MusicSongRow(
                  track: song,
                  playing: playingId == song.id,
                  favourite: favourites.contains(song),
                  onPlay: () => unawaited(playerController.playAll(songs, index: index)),
                  onFavourite: () => unawaited(favouriteController.toggle(song)),
                  onPlayNext: () => unawaited(playerController.playNext(song)),
                  onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
                  onDownload: () => unawaited(downloadTrackWithToast(context, ref, song, listName: catalog.name)),
                );
              },
            ),
    );
  }
}

/// 我的列表: the songs this module collected and played, each section playing
/// its own list from the chosen row.
final class _MineView extends ConsumerWidget {
  const _MineView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final favourites = ref.watch(musicFavouritesProvider);
    final recent = ref.watch(musicRecentProvider);
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    final playerController = ref.read(musicPlayerProvider.notifier);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    final recentController = ref.read(musicRecentProvider.notifier);
    if (favourites.isEmpty && recent.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.library),
          title: Text(t.music.mineEmptyTitle),
          description: Text(t.music.mineEmptyDescription),
        ),
      );
    }
    Widget section(
      String title,
      List<audio.MusicTrack> songs, {
      required Future<void> Function(audio.MusicTrack track) remove,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
          child: Text(
            '$title · ${t.music.songsCount(count: songs.length)}',
            style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textSubtle),
          ),
        ),
        DsListSection(
          children: [
            for (final (index, song) in songs.indexed)
              MusicSongRow(
                track: song,
                playing: playingId == song.id,
                favourite: favourites.contains(song),
                onPlay: () => unawaited(playerController.playAll(songs, index: index)),
                onFavourite: () => unawaited(favouriteController.toggle(song)),
                onRemove: () => unawaited(remove(song)),
                onPlayNext: () => unawaited(playerController.playNext(song)),
                onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
                onDownload: () => unawaited(downloadTrackWithToast(context, ref, song, listName: title)),
              ),
          ],
        ),
      ],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: DsSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          if (favourites.isNotEmpty) section(t.music.mineFavourites, favourites, remove: favouriteController.remove),
          if (recent.isNotEmpty) ...[
            section(t.music.mineRecent, recent, remove: recentController.remove),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: () => unawaited(recentController.clear()),
                  child: Text(t.music.clearRecent),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 本地音乐: the folders the viewer added, the files they hold, and the way
/// to add or drop a folder.
final class _LocalView extends ConsumerStatefulWidget {
  const _LocalView();

  @override
  ConsumerState<_LocalView> createState() => _LocalViewState();
}

final class _LocalViewState extends ConsumerState<_LocalView> {
  bool _selecting = false;
  final Set<audio.MusicTrack> _selected = <audio.MusicTrack>{};

  void _setSelecting({required bool selecting}) {
    setState(() {
      _selecting = selecting;
      if (!selecting) _selected.clear();
    });
  }

  void _toggleSelected(audio.MusicTrack track) {
    setState(() {
      if (!_selected.remove(track)) _selected.add(track);
    });
  }

  void _selectAll(List<audio.MusicTrack> tracks) {
    setState(() {
      _selected
        ..clear()
        ..addAll(tracks);
    });
  }

  /// The selected rows, in the list's own order.
  List<audio.MusicTrack> _picked(List<audio.MusicTrack> tracks) => [
    for (final track in tracks)
      if (_selected.contains(track)) track,
  ];

  Future<void> _playSelected(List<audio.MusicTrack> tracks) async {
    final picked = _picked(tracks);
    if (picked.isEmpty) return;
    await ref.read(musicPlayerProvider.notifier).playAll(picked);
    if (mounted) _setSelecting(selecting: false);
  }

  Future<void> _addFolder(BuildContext context) async {
    final t = context.t;
    try {
      final selected = await FilePicker.getDirectoryPath(dialogTitle: t.music.localAddFolder);
      if (selected == null || selected.trim().isEmpty) return;
      await ref.read(musicLocalProvider.notifier).addRoot(selected);
    } on Object catch (failure) {
      if (context.mounted) {
        showDsToast(
          context: context,
          title: t.music.localFolderFailed(error: '$failure'),
          status: DsStatus.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(musicLocalProvider);
    final controller = ref.read(musicLocalProvider.notifier);
    final playingId = ref.watch(musicPlayerProvider.select((state) => state.track?.id));
    final player = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouritesController = ref.read(musicFavouritesProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Text(
                  state.tracks.isEmpty ? t.music.localHint : t.music.localFiles(count: state.tracks.length),
                  maxLines: 2,
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
              ),
              DsButton.icon(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                semanticLabel: _selecting ? t.music.selectionCancel : t.music.selectionStart,
                onPressed: state.tracks.isEmpty ? null : () => _setSelecting(selecting: !_selecting),
                icon: DsIcon(_selecting ? DsIcons.x : DsIcons.listChecks, size: 16),
              ),
              DsButton.icon(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                semanticLabel: t.music.localRescan,
                onPressed: state.roots.isEmpty || state.loading ? null : () => unawaited(controller.rescan()),
                icon: const DsIcon(DsIcons.refreshCw, size: 16),
              ),
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.folderPlus, size: 16),
                onPressed: () => unawaited(_addFolder(context)),
                child: Text(t.music.localAddFolder),
              ),
            ],
          ),
        ),
        if (_selecting)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            child: Row(
              spacing: DsSpace.s8,
              children: [
                Expanded(
                  child: Text(
                    t.music.selectionCount(count: _selected.length),
                    style: theme.typography.caption.copyWith(color: colors.textSubtle),
                  ),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => _selectAll(state.tracks),
                  child: Text(t.music.selectionAll),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.play, size: 16),
                  onPressed: _selected.isEmpty ? null : () => unawaited(_playSelected(state.tracks)),
                  child: Text(t.music.playAll),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.listMusic, size: 16),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => unawaited(
                          showAddTracksToPlaylistDialog(context, ref, _picked(state.tracks)),
                        ),
                  child: Text(t.music.addToPlaylist),
                ),
              ],
            ),
          ),
        if (state.roots.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            child: DsListSection(
              header: Text(t.music.localFolders),
              children: [
                for (final root in state.roots)
                  DsListRow(
                    leading: const DsIcon(DsIcons.folder),
                    title: Text(root, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: DsButton.icon(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      semanticLabel: t.music.localRemoveFolder,
                      onPressed: () => unawaited(controller.removeRoot(root)),
                      icon: const DsIcon(DsIcons.x, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: state.loading
              ? const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)))
              : state.error != null
              ? Center(
                  child: DsEmptyState(
                    icon: const DsIcon(DsIcons.folderOpen),
                    title: Text(t.music.localFailed),
                    description: Text(state.error!),
                    actions: [DsButton(onPressed: () => unawaited(controller.rescan()), child: Text(t.common.retry))],
                  ),
                )
              : state.tracks.isEmpty
              ? Center(
                  child: DsEmptyState(
                    icon: const DsIcon(DsIcons.folderOpen),
                    title: Text(t.music.localEmptyTitle),
                    description: Text(t.music.localEmptyDescription),
                    actions: [
                      DsButton(
                        leading: const DsIcon(DsIcons.folderPlus, size: 16),
                        onPressed: () => unawaited(_addFolder(context)),
                        child: Text(t.music.localAddFolder),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: DsSpace.s16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: DsButton(
                          variant: DsButtonVariant.secondary,
                          size: DsSize.sm,
                          leading: const DsIcon(DsIcons.play, size: 16),
                          onPressed: () => unawaited(player.playAll(state.tracks)),
                          child: Text(t.music.playAll),
                        ),
                      ),
                    ),
                    DsListSection(
                      children: [
                        for (final (index, song) in state.tracks.indexed)
                          MusicSongRow(
                            track: song,
                            playing: playingId == song.id,
                            favourite: favourites.contains(song),
                            selecting: _selecting,
                            selected: _selected.contains(song),
                            onSelected: () => _toggleSelected(song),
                            // Tags name the song; the file name is the fallback
                            // for the files that carry none.
                            subtitle: song.artist.isNotEmpty
                                ? (song.album.isEmpty ? null : '${song.artist} · ${song.album}')
                                : song.localPath == null
                                ? null
                                : _fileNameOf(song.localPath!),
                            onPlay: () => unawaited(player.playAll(state.tracks, index: index)),
                            onFavourite: () => unawaited(favouritesController.toggle(song)),
                            onPlayNext: () => unawaited(player.playNext(song)),
                            onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// 下载: the queue's tasks with their progress and the verbs each state has.
final class _DownloadsView extends ConsumerWidget {
  const _DownloadsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final tasks = ref.watch(musicDownloadsProvider);
    final controller = ref.read(musicDownloadsProvider.notifier);
    final directory = ref.watch(downloadDirectoryProvider).effectivePath;
    final pending = tasks.where((task) => !task.isTerminal).toList();
    final hasFinished = tasks.any((task) => task.isTerminal);
    if (tasks.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.download),
          title: Text(t.music.downloadsEmptyTitle),
          description: Text(t.music.downloadsEmptyDescription(directory: directory)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Text(
                  directory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
              ),
              if (pending.isNotEmpty)
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => unawaited(controller.pauseAll()),
                  child: Text(t.music.downloadPauseAll),
                ),
              if (tasks.any((task) => task.isPaused))
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: () => unawaited(controller.resumeAll()),
                  child: Text(t.music.downloadResumeAll),
                ),
              if (hasFinished)
                DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: () => unawaited(controller.clearFinished()),
                  child: Text(t.music.downloadClearFinished),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: DsSpace.s16),
            children: [
              DsListSection(children: [for (final task in tasks) _DownloadRow(task: task)]),
            ],
          ),
        ),
      ],
    );
  }
}

final class _DownloadRow extends ConsumerWidget {
  const _DownloadRow({required this.task});

  final audio.MusicDownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final controller = ref.read(musicDownloadsProvider.notifier);
    final progress = task.progress;
    final title = task.request.title ?? _fileNameOf(task.outputPath);
    final artist = task.request.artist ?? '';
    final status = _statusLabel(t, task);
    final detail = [
      status,
      if (progress != null && !task.isTerminal) '${(progress * 100).round()}%',
      if (task.bytesPerSecond > 0 && task.status == audio.MusicDownloadStatus.running)
        '${_bytesText(task.bytesPerSecond)}/s',
    ].join(' · ');
    return DsListRow(
      leading: const DsIcon(DsIcons.download),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s4,
        children: [
          if (artist.isNotEmpty)
            Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.typography.caption),
          Text(
            task.status == audio.MusicDownloadStatus.failed && task.error != null
                ? '${t.music.downloadStatusFailed} · ${task.error}'
                : detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
          if (!task.isTerminal && progress != null)
            DsProgressBar(value: progress, semanticLabel: t.music.downloadProgress),
        ],
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, spacing: DsSpace.s4, children: _actions(context, controller, t)),
    );
  }

  List<Widget> _actions(BuildContext context, MusicDownloadsController controller, Translations t) {
    final status = task.status;
    if (status == audio.MusicDownloadStatus.failed) {
      return [
        _icon(t.music.downloadRetry, DsIcons.refreshCw, () => unawaited(controller.retry(task.id))),
        _icon(t.music.downloadRemove, DsIcons.trash2, () => unawaited(controller.remove(task.id))),
      ];
    }
    if (status == audio.MusicDownloadStatus.paused) {
      return [
        _icon(t.music.downloadResume, DsIcons.play, () => unawaited(controller.resume(task.id))),
        _icon(t.music.downloadRemove, DsIcons.trash2, () => unawaited(controller.remove(task.id))),
      ];
    }
    if (!task.isTerminal) {
      return [
        if (status == audio.MusicDownloadStatus.running || status == audio.MusicDownloadStatus.queued)
          _icon(t.music.downloadPause, DsIcons.pause, () => unawaited(controller.pause(task.id))),
        _icon(t.music.downloadCancel, DsIcons.x, () => unawaited(controller.cancel(task.id))),
      ];
    }
    return [_icon(t.music.downloadRemove, DsIcons.trash2, () => unawaited(controller.remove(task.id)))];
  }

  Widget _icon(String label, DsIconData icon, VoidCallback onPressed) => DsButton.icon(
    variant: DsButtonVariant.ghost,
    size: DsSize.sm,
    semanticLabel: label,
    onPressed: onPressed,
    icon: DsIcon(icon, size: 16),
  );
}

/// The strip over the module's views while something plays: cover, title,
/// the full transport, and a progress hairline along its top edge — the
/// way a desktop player's dock reads.
final class _MiniPlayer extends ConsumerWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(
      musicPlayerProvider.select(
        (state) => (track: state.track, playing: state.playing, position: state.position, duration: state.duration),
      ),
    );
    final controller = ref.read(musicPlayerProvider.notifier);
    final track = state.track;
    if (track == null) return const SizedBox.shrink();
    final duration = state.duration.inMilliseconds;
    final progress = duration <= 0 ? 0.0 : state.position.inMilliseconds.clamp(0, duration) / duration;
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s8),
      child: DsSurface(
        decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.radii.card),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The hairline: tap anywhere on it to seek without opening
              // the player page.
              LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: duration <= 0
                      ? null
                      : (details) => unawaited(
                          controller.seek(
                            Duration(milliseconds: (details.localPosition.dx / constraints.maxWidth * duration).round()),
                          ),
                        ),
                  child: SizedBox(
                    height: 3,
                    child: Stack(
                      children: [
                        Container(color: colors.surface),
                        FractionallySizedBox(
                          widthFactor: progress,
                          alignment: Alignment.centerLeft,
                          child: Container(color: colors.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                spacing: DsSpace.s8,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: DsSpace.s8),
                    child: GestureDetector(
                      onTap: () => unawaited(context.push(RouteNames.musicPlayer)),
                      child: MusicArtwork(track: track),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => unawaited(context.push(RouteNames.musicPlayer)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: DsSpace.s3,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.body.copyWith(color: colors.text, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${track.artist.isEmpty ? t.music.nowPlaying : track.artist} · ${musicDurationText(state.position)} / ${musicDurationText(state.duration)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.caption.copyWith(color: colors.textSubtle),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: DsSpace.s4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: DsSpace.s3,
                      children: [
                        DsButton.icon(
                          variant: DsButtonVariant.ghost,
                          size: DsSize.sm,
                          semanticLabel: t.music.previous,
                          onPressed: () => unawaited(controller.previous()),
                          icon: const DsIcon(DsIcons.skipBack),
                        ),
                        DsButton.icon(
                          variant: DsButtonVariant.ghost,
                          size: DsSize.sm,
                          semanticLabel: state.playing ? t.music.pause : t.music.play,
                          onPressed: () => unawaited(controller.toggle()),
                          icon: DsIcon(state.playing ? DsIcons.pause : DsIcons.play),
                        ),
                        DsButton.icon(
                          variant: DsButtonVariant.ghost,
                          size: DsSize.sm,
                          semanticLabel: t.music.next,
                          onPressed: () => unawaited(controller.next()),
                          icon: const DsIcon(DsIcons.skipForward),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A path's last segment, for a local file or a download's output.
String _fileNameOf(String path) {
  final separator = path.lastIndexOf(RegExp(r'[\\/]'));
  return separator < 0 ? path : path.substring(separator + 1);
}

/// A byte count as a short human label.
String _bytesText(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// The task's state in words.
String _statusLabel(Translations t, audio.MusicDownloadTask task) => switch (task.status) {
  audio.MusicDownloadStatus.queued => t.music.downloadStatusQueued,
  audio.MusicDownloadStatus.running => t.music.downloadStatusRunning,
  audio.MusicDownloadStatus.paused => t.music.downloadStatusPaused,
  audio.MusicDownloadStatus.processing => t.music.downloadStatusProcessing,
  audio.MusicDownloadStatus.completed => t.music.downloadStatusCompleted,
  audio.MusicDownloadStatus.skipped => t.music.downloadStatusSkipped,
  audio.MusicDownloadStatus.failed => t.music.downloadStatusFailed,
  audio.MusicDownloadStatus.cancelled => t.music.downloadStatusCancelled,
};


/// The 歌单 rail's two tabs: the viewer's own lists and the source's online
/// playlists (在线歌单), the way LX keeps both behind one view.
final class _SonglistTabs extends ConsumerWidget {
  const _SonglistTabs({required this.online, required this.mineCount, required this.onChanged});

  final bool online;
  final int mineCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return DsTabs<bool>(
      value: online,
      onChanged: onChanged,
      tabs: [
        DsTab<bool>(value: false, label: Text(t.music.songlistTabMine), count: mineCount),
        DsTab<bool>(value: true, label: Text(t.music.songlistTabOnline)),
      ],
      semanticLabel: t.music.songlistTabMine,
    );
  }
}

/// The 在线歌单 browser: hot tags as chips, one page row per fetched page,
/// a load-more at the end. A source without the capability says so plainly
/// instead of showing an empty list.
final class _OnlinePlaylistBrowse extends ConsumerStatefulWidget {
  const _OnlinePlaylistBrowse({required this.mineCount, required this.onOpen, required this.onBackToMine});

  final int mineCount;
  final ValueChanged<MusicPlaylistInfo> onOpen;
  final VoidCallback onBackToMine;

  @override
  ConsumerState<_OnlinePlaylistBrowse> createState() => _OnlinePlaylistBrowseState();
}

final class _OnlinePlaylistBrowseState extends ConsumerState<_OnlinePlaylistBrowse> {
  /// The sort tab in browse; null waits for the sorts to name the first.
  String? _order;

  /// The category group in browse; empty is the hot tags.
  String _group = '';

  /// The tag in browse; null waits for the chips to name the first.
  String? _tag;

  /// How many pages are wanted; the family provider caches each one, so
  /// widening this range re-reads, it does not re-fetch.
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final hotTags = ref.watch(musicOnlineHotTagsProvider);
    final tree = ref.watch(musicPlaylistTagGroupsProvider);
    final sorts = ref.watch(musicPlaylistSortsProvider);
    final supported = ref.watch(musicSourceProvider) is OnlinePlaylists;

    final order = _order ?? sorts.firstOrNull?.id ?? '';
    final tagGroups = tree.value ?? const <MusicPlaylistTagGroup>[];
    final hotValues = [
      for (final name in hotTags.value ?? const <String>[])
        if (name.trim().isNotEmpty) MusicPlaylistTag(id: name.trim(), name: name.trim()),
    ];
    final chips = _group.isEmpty
        ? hotValues
        : tagGroups.where((group) => group.name == _group).firstOrNull?.tags ?? const <MusicPlaylistTag>[];
    final effectiveTag = _tag ?? chips.firstOrNull?.id;

    final pages = <AsyncValue<MusicPlaylistPage>>[
      if (effectiveTag != null)
        for (var page = 1; page <= _page; page++)
          ref.watch(musicOnlinePlaylistsProvider((tag: effectiveTag, order: order, page: page))),
    ];
    final items = <MusicPlaylistInfo>[
      for (final page in pages)
        if (page.value != null) ...page.value!.items,
    ];
    final loading = pages.any((page) => page.isLoading);
    final error = pages.where((page) => page.hasError).firstOrNull;
    final total = pages.lastOrNull?.value?.total ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SonglistTabs(online: true, mineCount: widget.mineCount, onChanged: (online) {
          if (!online) widget.onBackToMine();
        }),
        if (!supported)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s16, DsSpace.s20, DsSpace.s16),
            child: Center(
              child: DsEmptyState(
                icon: const DsIcon(DsIcons.listMusic),
                title: Text(t.music.onlineUnsupported),
              ),
            ),
          )
        else ...[
          // The reference's sort tabs, above the tag tree; a plaza with a
          // single sort shows none.
          if (sorts.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
              child: DsTopNav<String>(
                items: [
                  for (final sort in sorts) DsTopNavItem(value: sort.id, label: Text(musicPlaylistSortLabel(t, sort))),
                ],
                value: order,
                onChanged: (id) => setState(() {
                  _order = id;
                  _page = 1;
                }),
              ),
            ),
          // The reference's tag tree: the categories as the nav row, the
          // chosen group's tags as the chips under it, the hot tags their
          // own first group.
          if (tagGroups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
              child: DsTopNav<String>(
                items: [
                  DsTopNavItem(value: '', label: Text(t.music.playlistHotTags)),
                  for (final group in tagGroups) DsTopNavItem(value: group.name, label: Text(group.name)),
                ],
                value: _group,
                onChanged: (name) => setState(() {
                  _group = name;
                  _tag = null;
                  _page = 1;
                }),
              ),
            ),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
              child: Wrap(
                spacing: DsSpace.s8,
                runSpacing: DsSpace.s8,
                children: [
                  for (final tag in chips)
                    DsChip(
                      label: Text(tag.name),
                      selected: tag.id == effectiveTag,
                      onChanged: (on) {
                        if (!on) return;
                        setState(() {
                          _tag = tag.id;
                          _page = 1;
                        });
                      },
                    ),
                ],
              ),
            ),
          Expanded(
            child: switch ((effectiveTag, hotTags, error, loading, items.isEmpty)) {
              // The tags have not named a board yet: the first page waits
              // for them, loading or honestly failed.
              (null, AsyncValue(:final isLoading), _, _, _) when isLoading => const Center(
                child: DsSpinner(style: DsSpinnerStyle(size: 28)),
              ),
              (null, AsyncValue(hasError: true), _, _, _) => Center(
                child: DsEmptyState(
                  icon: const DsIcon(DsIcons.listMusic),
                  title: Text(t.music.onlineLoadFailed),
                  actions: [
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      onPressed: () => ref.invalidate(musicOnlineHotTagsProvider),
                      child: Text(t.common.retry),
                    ),
                  ],
                ),
              ),
              (_, _, _, true, _) || (_, _, _, false, false) => MusicPlaylistGrid<MusicPlaylistInfo>(
                items: items,
                isLoading: loading,
                hasMore: items.length < total,
                onLoadMore: () async {
                  setState(() => _page += 1);
                },
                onRefresh: () async {
                  final tag = effectiveTag;
                  if (tag == null) {
                    ref
                      ..invalidate(musicOnlineHotTagsProvider)
                      ..invalidate(musicPlaylistTagGroupsProvider);
                    return;
                  }
                  for (var page = 1; page <= _page; page++) {
                    ref.invalidate(musicOnlinePlaylistsProvider((tag: tag, order: order, page: page)));
                  }
                  setState(() => _page = 1);
                },
                itemBuilder: (context, playlist) =>
                    MusicPlaylistCard.online(info: playlist, onOpen: () => widget.onOpen(playlist)),
              ),
              (_, _, final pageError, false, true) => Center(
                child: DsEmptyState(
                  icon: const DsIcon(DsIcons.listMusic),
                  title: Text(pageError != null ? t.music.onlineLoadFailed : t.music.onlineEmpty),
                  actions: [
                    if (pageError != null)
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        onPressed: () {
                          final tag = effectiveTag;
                          if (tag == null) return;
                          for (var page = 1; page <= _page; page++) {
                            ref.invalidate(musicOnlinePlaylistsProvider((tag: tag, order: order, page: page)));
                          }
                        },
                        child: Text(t.common.retry),
                      ),
                  ],
                ),
              ),
            },
          ),
        ],
      ],
    );
  }
}

/// One online playlist opened to its tracks: import it into the viewer's
/// own lists (LX's behaviour — the online list lands as a local one), or
/// play straight from here.
final class _OnlinePlaylistDetail extends ConsumerWidget {
  const _OnlinePlaylistDetail({required this.info, required this.onBack});

  final MusicPlaylistInfo info;
  final VoidCallback onBack;

  Future<void> _import(BuildContext context, WidgetRef ref, List<audio.MusicTrack> tracks) async {
    final t = context.t;
    final controller = ref.read(musicPlaylistsProvider.notifier);
    final playlist = await controller.create(info.name);
    if (playlist == null) return;
    final added = await controller.addTracks(playlist.id, tracks);
    if (!context.mounted) return;
    showDsToast(
      context: context,
      title: t.music.onlineImported(name: playlist.name, count: added),
      status: added > 0 ? DsStatus.success : DsStatus.warning,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final detail = ref.watch(musicOnlinePlaylistDetailProvider(info.id));
    final player = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouritesController = ref.read(musicFavouritesProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s8, 0, DsSpace.s20, DsSpace.s8),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              DsButton.icon(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                semanticLabel: t.common.back,
                onPressed: onBack,
                icon: const DsIcon(DsIcons.chevronLeft),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s3,
                  children: [
                    Text(
                      info.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.title.copyWith(color: colors.text),
                    ),
                    Text(
                      '${info.author} · ${t.music.songsCount(count: info.trackCount)}',
                      style: theme.typography.caption.copyWith(color: colors.textSubtle),
                    ),
                  ],
                ),
              ),
              detail.when(
                skipLoadingOnReload: true,
                data: (entry) {
                  final (_, tracks) = entry;
                  return DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    leading: const DsIcon(DsIcons.plus, size: 16),
                    onPressed: tracks.isEmpty ? null : () => unawaited(_import(context, ref, tracks)),
                    child: Text(t.music.onlineImport),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        Expanded(
          child: detail.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28))),
            error: (error, stackTrace) => Center(
              child: DsEmptyState(icon: const DsIcon(DsIcons.listMusic), title: Text(t.music.onlineLoadFailed)),
            ),
            data: (entry) {
              final (info, tracks) = entry;
              return tracks.isEmpty
                  ? Center(child: DsEmptyState(icon: const DsIcon(DsIcons.listMusic), title: Text(t.music.onlineEmpty)))
                  : ListView.builder(
                    padding: const EdgeInsets.only(bottom: DsSpace.s16),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final song = tracks[index];
                      return MusicSongRow(
                        track: song,
                        playing: false,
                        favourite: favourites.contains(song),
                        subtitle: song.artist,
                        onPlay: () => unawaited(player.playAll(tracks, index: index)),
                        onFavourite: () => unawaited(favouritesController.toggle(song)),
                        onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
                        onDownload: () => unawaited(downloadTrackWithToast(context, ref, song, listName: info.name)),
                      );
                    },
                  );
            },
          ),
        ),
      ],
    );
  }
}
