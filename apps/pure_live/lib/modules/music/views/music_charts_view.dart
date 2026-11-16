import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/browse/music_search.dart'
    show musicCatalogItemsProvider, musicCatalogsProvider;
import 'package:pure_live/modules/music/controller/library/music_library.dart'
    show musicFavouritesProvider, musicTrackKey;
import 'package:pure_live/modules/music/controller/library/music_playlists.dart' show musicPlaylistsProvider;
import 'package:pure_live/modules/music/controller/playback/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/music_page.dart' show MusicView;
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_detail_hero.dart' show MusicDetailHero;
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/shared.dart' show LiveWindow, SkeletonRows;
import 'package:pure_live/shared/widgets/app_dialog.dart';

/// The charts: the source's own boards, each one answer rather than a feed.
final class MusicChartsView extends ConsumerWidget {
  const MusicChartsView({required this.catalogId, required this.onCatalog, super.key});

  final String? catalogId;
  final ValueChanged<String> onCatalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    // The page's gutter, the same measure the live module's pages keep.
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final catalogs = ref.watch(musicCatalogsProvider);
    return catalogs.when(
      loading: () => const Padding(padding: EdgeInsets.all(DsSpace.s16), child: SkeletonRows()),
      error: (error, _) => Center(
        child: DsEmptyState(
          icon: DsIcon(MusicView.toplists.icon),
          title: Text(t.music.chartsFailed),
          description: Text('$error'),
          actions: [DsButton(onPressed: () => ref.invalidate(musicCatalogsProvider), child: Text(t.common.retry))],
        ),
      ),
      data: (boards) {
        if (boards.isEmpty) {
          return Center(
            child: DsEmptyState(
              icon: DsIcon(MusicView.toplists.icon),
              title: Text(t.music.chartsEmptyTitle),
              description: Text(t.music.chartsEmptyDescription),
            ),
          );
        }
        final selected = boards.firstWhere((board) => board.id == catalogId, orElse: () => boards.first);
        // The head reads the board's songs from the same fetch the list under
        // it uses: the family provider is keyed on the board, so asking twice
        // is still one ask.
        final songs = ref.watch(musicCatalogItemsProvider(selected)).value ?? const <audio.MusicTrack>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s8),
              child: SizedBox(
                height: 44,
                child: DsTabs<String>(
                  value: selected.id,
                  onChanged: onCatalog,
                  style: kMusicFeedTabsStyle,
                  tabs: [for (final board in boards) DsTab(value: board.id, label: Text(board.name))],
                ),
              ),
            ),
            MusicChartBoardHead(catalog: selected, songs: songs, onCollect: () => _collect(context, ref, selected)),
            Expanded(child: MusicChartItems(catalog: selected)),
          ],
        );
      },
    );
  }

  /// The reference's board 收藏: the board lands in the viewer's lists as a
  /// linked one (`board__<id>`), so a later pass can pull it afresh; a
  /// second collect of the same board offers to refresh what is there.
  /// The board's songs are fetched before any list is touched, and a failure
  /// anywhere toasts — an empty linked list left behind a dead fetch would
  /// only confuse.
  Future<void> _collect(BuildContext context, WidgetRef ref, audio.MusicCatalog catalog) async {
    final t = context.t;
    final controller = ref.read(musicPlaylistsProvider.notifier);
    final split = catalog.id.indexOf(':');
    if (split < 0) return;
    final sourceId = catalog.id.substring(0, split);
    final sourceListId = 'board__${catalog.id.substring(split + 1)}';
    try {
      final existing = controller.findLinked(sourceId, sourceListId);
      if (existing != null) {
        final confirmed = await showAppDialog<bool>(
          context: context,
          builder: (context) => AppDialog(
            title: Text(t.music.playlistUpdateOnline),
            description: Text(t.music.duplicateListTip(name: existing.name)),
            actions: [
              DsButton(
                variant: DsButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(t.common.cancel),
              ),
              DsButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.common.confirm)),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        final tracks = await ref.read(musicCatalogItemsProvider(catalog).future);
        final count = await ref.read(musicPlaylistsProvider.notifier).replaceTracks(existing.id, tracks);
        if (!context.mounted) return;
        showDsToast(
          context: context,
          title: t.music.onlineUpdatedToast(name: existing.name, count: count),
          status: DsStatus.success,
        );
        return;
      }
      final tracks = await ref.read(musicCatalogItemsProvider(catalog).future);
      final playlist = await controller.create(catalog.name);
      if (playlist == null || !context.mounted) return;
      await controller.linkSource(playlist.id, source: sourceId, sourceListId: sourceListId);
      final added = await controller.addTracks(playlist.id, tracks);
      if (!context.mounted) return;
      showDsToast(
        context: context,
        title: t.music.onlineImported(name: playlist.name, count: added),
        status: added > 0 ? DsStatus.success : DsStatus.warning,
      );
    } on Object catch (failure) {
      if (context.mounted) {
        showDsToast(
          context: context,
          title: t.music.playlistImportFailed(error: '$failure'),
          status: DsStatus.danger,
        );
      }
    }
  }
}

/// The board's own head, the layer the reference puts over a chart's rows
/// before the first numbered song: the cover its lead track carries, the
/// board named over how many it holds and how long they run, the source's own
/// description when it gives one, and the verbs that act on the whole board
/// rather than on one row.
///
/// The same layer 在线歌单's detail page already gives a playlist; a board was
/// the module's one list you could only play one song at a time. The collect
/// verb moved here from the board tabs above, where it was a bare glyph with
/// no word — it belongs beside the board it collects.
final class MusicChartBoardHead extends ConsumerStatefulWidget {
  const MusicChartBoardHead({required this.catalog, required this.songs, required this.onCollect, super.key});

  /// The board the rows under the head belong to.
  final audio.MusicCatalog catalog;

  /// Its songs as they were fetched. Empty while the board is still on its
  /// way, which leaves every verb out rather than leaving a button that
  /// answers nothing.
  final List<audio.MusicTrack> songs;

  /// Collects the board into the viewer's own lists; the head keeps the
  /// button busy until it settles.
  final Future<void> Function() onCollect;

  @override
  ConsumerState<MusicChartBoardHead> createState() => _MusicChartBoardHeadState();
}

final class _MusicChartBoardHeadState extends ConsumerState<MusicChartBoardHead> {
  /// The collect is running: the button shows it and takes no second ask.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return _HeadBody(
      catalog: widget.catalog,
      songs: widget.songs,
      collectBusy: _busy,
      onCollect: () async {
        setState(() => _busy = true);
        try {
          await widget.onCollect();
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      },
    );
  }
}

final class _HeadBody extends ConsumerWidget {
  const _HeadBody({required this.catalog, required this.songs, required this.collectBusy, required this.onCollect});

  final audio.MusicCatalog catalog;
  final List<audio.MusicTrack> songs;
  final bool collectBusy;
  final Future<void> Function() onCollect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final player = ref.read(musicPlayerProvider.notifier);
    // A board names no cover of its own, so the head wears its lead track's
    // art — the way the playlist detail page wears its first song's.
    final total = songs.fold<Duration>(Duration.zero, (sum, song) => sum + (song.duration ?? Duration.zero));
    return MusicDetailHero(
      coverUri: songs.firstOrNull?.coverUri,
      fallbackTitle: catalog.name,
      title: catalog.name,
      facts: [
        if (songs.isNotEmpty)
          [t.music.songsCount(count: songs.length), if (total > Duration.zero) musicDurationText(total)].join(' · '),
      ],
      description: catalog.description,
      onPlayAll: songs.isEmpty ? null : () => unawaited(player.playAll(songs)),
      playSemanticLabel: t.music.playAll,
      actions: [
        if (songs.isNotEmpty)
          DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            leading: const DsIcon(DsIcons.shuffle, size: 16),
            onPressed: () => unawaited(player.playAll([...songs]..shuffle(math.Random()))),
            child: Text(t.music.modeRandom),
          ),
        if (songs.isNotEmpty)
          DsButton(
            variant: DsButtonVariant.secondary,
            size: DsSize.sm,
            loading: collectBusy,
            leading: const DsIcon(DsIcons.listPlus, size: 16),
            onPressed: () => unawaited(onCollect()),
            child: Text(t.music.boardCollect),
          ),
      ],
    );
  }
}

/// One board's songs, playing the whole board from the chosen row.
final class MusicChartItems extends ConsumerWidget {
  const MusicChartItems({required this.catalog, super.key});

  final audio.MusicCatalog catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final items = ref.watch(musicCatalogItemsProvider(catalog));
    final playingKey = ref.watch(
      musicPlayerProvider.select((state) => (state.track == null ? null : musicTrackKey(state.track!))),
    );
    final playerController = ref.read(musicPlayerProvider.notifier);
    final favourites = ref.watch(musicFavouritesProvider);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    return items.when(
      loading: () => const Padding(padding: EdgeInsets.all(DsSpace.s16), child: SkeletonRows()),
      error: (error, _) => Center(
        child: DsEmptyState(
          icon: DsIcon(MusicView.toplists.icon),
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
                icon: DsIcon(MusicView.toplists.icon),
                title: Text(t.music.chartsEmptyTitle),
                description: Text(t.music.chartsEmptyDescription),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: LiveWindow.pageInset(MediaQuery.sizeOf(context).width)),
              itemCount: songs.length + 1,
              itemBuilder: (context, offset) {
                if (offset == 0) return const MusicSongTableHeader();
                final index = offset - 1;
                final song = songs[index];
                // The board is a ranking, not a plain list: the # column
                // prints the place, and the three first wear the accent —
                // the reference's 排名列进 # 列,前三名高亮.
                return MusicSongRow(
                  track: song,
                  number: index + 1,
                  ranked: true,
                  playing: playingKey == musicTrackKey(song),
                  favourite: favourites.contains(song),
                  onPlay: () => unawaited(playerController.playAll(songs, index: index)),
                  onFavourite: () => unawaited(favouriteController.toggle(song)),
                  onPlayNext: () => unawaited(playerController.playNext(song)),
                  onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
                  onDownload: () => unawaited(downloadTrackWithToast(context, ref, song, listName: catalog.name)),
                  onToggleSource: () => unawaited(showToggleSourceDialog(context, ref, song)),
                );
              },
            ),
    );
  }
}
