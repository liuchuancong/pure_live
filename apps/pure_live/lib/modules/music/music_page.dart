import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/app/app.dart' show RouteNames;
import 'package:pure_live/app/providers/settings/download_directory_provider.dart'
    show DownloadDirectoryPaths, downloadDirectoryProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_downloads.dart';
import 'package:pure_live/modules/music/controller/music_library.dart';
import 'package:pure_live/modules/music/controller/music_local.dart';
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_playlists.dart';
import 'package:pure_live/modules/music/controller/music_search.dart';
import 'package:pure_live/modules/music/controller/music_settings.dart' show musicSettingsProvider;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceProvider;
import 'package:pure_live/modules/music/controller/music_sources.dart' show musicSourcesProvider;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: _ModuleHeader(),
        ),
        Expanded(
          child: switch (_view) {
            MusicView.library => _LibraryView(search: _search),
            MusicView.songlists => const _PlaylistsView(),
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
    final sources = ref.watch(musicSourcesProvider).length;
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
final class _LibraryView extends ConsumerWidget {
  const _LibraryView({required this.search});

  final TextEditingController search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final showSource = ref.watch(musicSettingsProvider).showSource;
    final sourceName = ref.watch(musicSourceProvider).name;
    void play(int index) => unawaited(playerController.playAll(state.songs, index: index));
    void runHistory(String query) {
      search.text = query;
      search.selection = TextSelection.collapsed(offset: query.length);
      unawaited(controller.search(query));
    }

    Widget songAt(int index) {
      final song = state.songs[index];
      final subtitle = [song.artist, if (showSource) sourceName].where((part) => part.isNotEmpty).join(' · ');
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
      body = history.isEmpty
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
      body = Column(
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
            child: ListView.builder(itemCount: state.songs.length, itemBuilder: (context, index) => songAt(index)),
          ),
          if (state.hasMore)
            Padding(
              padding: const EdgeInsets.all(DsSpace.s12),
              child: Center(
                child: DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: state.loading ? null : () => unawaited(controller.loadMore()),
                  child: Text(t.music.loadMore),
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: DsSearchField(
            controller: search,
            autofocus: true,
            placeholder: t.music.searchHint,
            onSubmitted: (value) => unawaited(controller.search(value)),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

/// 歌单: the viewer's own playlists and the songs in the one that is open.
final class _PlaylistsView extends ConsumerStatefulWidget {
  const _PlaylistsView();

  @override
  ConsumerState<_PlaylistsView> createState() => _PlaylistsViewState();
}

final class _PlaylistsViewState extends ConsumerState<_PlaylistsView> {
  String? _openId;

  Future<void> _create() async {
    final playlist = await showCreatePlaylistDialog(context, ref);
    if (playlist != null && mounted) setState(() => _openId = playlist.id);
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
    if (mounted) setState(() => _openId = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final playlists = ref.watch(musicPlaylistsProvider);
    final open = _openId == null ? null : playlists.where((playlist) => playlist.id == _openId).firstOrNull;
    if (open != null) return _playlistDetail(open);

    if (playlists.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.plus, size: 16),
                onPressed: () => unawaited(_create()),
                child: Text(t.music.playlistCreate),
              ),
            ),
          ),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.music.playlistsCount(count: playlists.length),
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
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
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: DsSpace.s16),
            children: [
              DsListSection(
                children: [
                  for (final playlist in playlists)
                    DsListRow(
                      leading: const DsIcon(DsIcons.listMusic),
                      title: Text(playlist.name),
                      description: Text(t.music.songsCount(count: playlist.tracks.length)),
                      showChevron: true,
                      onPressed: () => setState(() => _openId = playlist.id),
                      trailing: DsMenuAnchor(
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
                    ),
                ],
              ),
            ],
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
                onPressed: () => setState(() => _openId = null),
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
                height: 40,
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
final class _LocalView extends ConsumerWidget {
  const _LocalView();

  Future<void> _addFolder(BuildContext context, WidgetRef ref) async {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                semanticLabel: t.music.localRescan,
                onPressed: state.roots.isEmpty || state.loading ? null : () => unawaited(controller.rescan()),
                icon: const DsIcon(DsIcons.refreshCw, size: 16),
              ),
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.folderPlus, size: 16),
                onPressed: () => unawaited(_addFolder(context, ref)),
                child: Text(t.music.localAddFolder),
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
                        onPressed: () => unawaited(_addFolder(context, ref)),
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
                            subtitle: song.localPath == null ? null : _fileNameOf(song.localPath!),
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

/// The strip over the module's views while something plays: the song, its
/// transport and the way into the player page.
final class _MiniPlayer extends ConsumerWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(musicPlayerProvider.select((state) => (track: state.track, playing: state.playing)));
    final controller = ref.read(musicPlayerProvider.notifier);
    final track = state.track;
    if (track == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s8),
      child: DsSurface(
        decoration: DsBoxDecoration(color: colors.control, borderRadius: BorderRadius.circular(theme.radii.card)),
        child: DsListRow(
          leading: MusicArtwork(track: track),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.copyWith(color: colors.text, fontWeight: FontWeight.w600),
          ),
          description: Text(
            track.artist.isEmpty ? t.music.nowPlaying : track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s4,
            children: [
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
          onPressed: () => unawaited(context.push(RouteNames.musicPlayer)),
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
