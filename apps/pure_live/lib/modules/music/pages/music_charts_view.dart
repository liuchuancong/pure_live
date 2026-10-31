import 'dart:async' show unawaited;

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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
              child: Row(
                spacing: DsSpace.s8,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: DsTopNav<String>(
                        value: selected.id,
                        onChanged: onCatalog,
                        items: [for (final board in boards) DsTopNavItem(value: board.id, label: Text(board.name))],
                      ),
                    ),
                  ),
                  DsButton.icon(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    semanticLabel: t.music.boardCollect,
                    onPressed: () => unawaited(_collect(context, ref, selected)),
                    icon: const DsIcon(DsIcons.listPlus, size: 16),
                  ),
                ],
              ),
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
