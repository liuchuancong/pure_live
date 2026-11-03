import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_library.dart' show musicFavouritesProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_playlists.dart' show musicPlaylistsProvider;
import 'package:pure_live/modules/music/controller/music_search.dart'
    show musicCatalogItemsProvider, musicCatalogsProvider;
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/shared.dart' show CoverFallback, cachedImage;

/// The charts: the source's own boards, each one answer rather than a feed.
final class MusicChartsView extends ConsumerWidget {
  const MusicChartsView({required this.catalogId, required this.onCatalog, super.key});

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
        // The head reads the board's songs from the same fetch the list under
        // it uses: the family provider is keyed on the board, so asking twice
        // is still one ask.
        final songs = ref.watch(musicCatalogItemsProvider(selected)).value ?? const <audio.MusicTrack>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
              child: SizedBox(
                height: 44,
                child: DsTabs<String>(
                  value: selected.id,
                  onChanged: onCatalog,
                  style: const DsTabsStyle(height: 44, padding: EdgeInsets.zero, dividerColor: Color(0x00000000)),
                  tabs: [for (final board in boards) DsTab(value: board.id, label: Text(board.name))],
                ),
              ),
            ),
            MusicChartBoardHead(
              catalog: selected,
              songs: songs,
              onCollect: () => unawaited(_collect(context, ref, selected)),
            ),
            Expanded(child: MusicChartItems(catalog: selected)),
          ],
        );
      },
    );
  }

  /// The reference's board 收藏: the board lands in the viewer's lists as a
  /// linked one (`board__<id>`), so a later pass can pull it afresh; a
  /// second collect of the same board offers to refresh what is there.
  Future<void> _collect(BuildContext context, WidgetRef ref, audio.MusicCatalog catalog) async {
    final t = context.t;
    final controller = ref.read(musicPlaylistsProvider.notifier);
    final split = catalog.id.indexOf(':');
    if (split < 0) return;
    final sourceId = catalog.id.substring(0, split);
    final sourceListId = 'board__${catalog.id.substring(split + 1)}';
    final existing = controller.findLinked(sourceId, sourceListId);
    if (existing != null) {
      final confirmed = await showDsDialog<bool>(
        context: context,
        builder: (context) => DsDialog(
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
      final count = await ref
          .read(musicPlaylistsProvider.notifier)
          .replaceTracks(existing.id, await ref.read(musicCatalogItemsProvider(catalog).future));
      if (!context.mounted) return;
      showDsToast(
        context: context,
        title: t.music.onlineUpdatedToast(name: existing.name, count: count),
        status: DsStatus.success,
      );
      return;
    }
    final playlist = await controller.create(catalog.name);
    if (playlist == null || !context.mounted) return;
    await controller.linkSource(playlist.id, source: sourceId, sourceListId: sourceListId);
    final added = await controller.addTracks(playlist.id, await ref.read(musicCatalogItemsProvider(catalog).future));
    if (!context.mounted) return;
    showDsToast(
      context: context,
      title: t.music.onlineImported(name: playlist.name, count: added),
      status: added > 0 ? DsStatus.success : DsStatus.warning,
    );
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
final class MusicChartBoardHead extends ConsumerWidget {
  const MusicChartBoardHead({required this.catalog, required this.songs, required this.onCollect, super.key});

  /// The board the rows under the head belong to.
  final audio.MusicCatalog catalog;

  /// Its songs as they were fetched. Empty while the board is still on its
  /// way, which leaves the two play verbs out rather than leaving a button
  /// that answers nothing.
  final List<audio.MusicTrack> songs;

  /// Collects the board into the viewer's own lists.
  final VoidCallback onCollect;

  /// The cover's side: the module's detail heads all draw it at 72.
  static const double _cover = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final player = ref.read(musicPlayerProvider.notifier);
    // A board names no cover of its own, so the head wears its lead track's
    // art — the way the playlist detail page wears its first song's.
    final coverUrl = songs.firstOrNull?.coverUri?.toString() ?? '';
    final total = songs.fold<Duration>(Duration.zero, (sum, song) => sum + (song.duration ?? Duration.zero));
    final description = catalog.description ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s16,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(theme.radii.card),
            child: SizedBox(
              width: _cover,
              height: _cover,
              child: coverUrl.isEmpty
                  ? CoverFallback(title: catalog.name)
                  : DsImage(
                      image: cachedImage(coverUrl),
                      aspectRatio: 1,
                      semanticLabel: catalog.name,
                      fallback: CoverFallback(title: catalog.name),
                    ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Text(
                  catalog.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.heading.copyWith(color: colors.text),
                ),
                if (songs.isNotEmpty)
                  Text(
                    total > Duration.zero
                        ? '${t.music.songsCount(count: songs.length)} · ${musicDurationText(total)}'
                        : t.music.songsCount(count: songs.length),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textSubtle),
                  ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: DsSpace.s4),
                  child: Wrap(
                    spacing: DsSpace.s8,
                    runSpacing: DsSpace.s8,
                    children: [
                      if (songs.isNotEmpty)
                        DsButton(
                          size: DsSize.sm,
                          leading: const DsIcon(DsIcons.play, size: 16),
                          onPressed: () => unawaited(player.playAll(songs)),
                          child: Text(t.music.playAll),
                        ),
                      if (songs.isNotEmpty)
                        DsButton(
                          variant: DsButtonVariant.secondary,
                          size: DsSize.sm,
                          leading: const DsIcon(DsIcons.shuffle, size: 16),
                          onPressed: () => unawaited(player.playAll([...songs]..shuffle(math.Random()))),
                          child: Text(t.music.modeRandom),
                        ),
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        leading: const DsIcon(DsIcons.listPlus, size: 16),
                        onPressed: onCollect,
                        child: Text(t.music.boardCollect),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
              itemCount: songs.length + 1,
              itemBuilder: (context, offset) {
                if (offset == 0) return const MusicSongTableHeader();
                final index = offset - 1;
                final song = songs[index];
                return MusicSongRow(
                  track: song,
                  number: index + 1,
                  playing: playingId == song.id,
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
