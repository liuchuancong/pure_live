import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_library.dart'
    show musicFavouritesProvider, musicRecentProvider;
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/shared.dart' show CoverFallback, LiveWindow, cachedImage;

/// 我的列表: the songs this module collected and played, each section playing
/// its own list from the chosen row.
final class MusicMineView extends ConsumerWidget {
  const MusicMineView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    // The page's gutter, the same measure the live module's pages keep.
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
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
      bool caption = true,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        if (caption)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: Text(
              '$title · ${t.music.songsCount(count: songs.length)}',
              style: DsTheme.of(context).typography.caption.copyWith(color: DsTheme.colorsOf(context).textSubtle),
            ),
          ),
        DsListSection(
          children: [
            const MusicSongTableHeader(),
            for (final (index, song) in songs.indexed)
              MusicSongRow(
                track: song,
                number: index + 1,
                playing: playingId == song.id,
                favourite: favourites.contains(song),
                onPlay: () => unawaited(playerController.playAll(songs, index: index)),
                onFavourite: () => unawaited(favouriteController.toggle(song)),
                onRemove: () => unawaited(remove(song)),
                onPlayNext: () => unawaited(playerController.playNext(song)),
                onAddToPlaylist: () => unawaited(showAddToPlaylistDialog(context, ref, song)),
                onDownload: () => unawaited(downloadTrackWithToast(context, ref, song, listName: title)),
                onToggleSource: () => unawaited(showToggleSourceDialog(context, ref, song)),
              ),
          ],
        ),
      ],
    );
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    Widget favouritesHeader() {
      final first = favourites.first;
      final total = favourites.fold(Duration.zero, (sum, track) => sum + (track.duration ?? Duration.zero));
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s20, DsSpace.s8, DsSpace.s20, 0),
        child: Row(
          spacing: DsSpace.s16,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(theme.radii.card),
              child: SizedBox(
                width: 72,
                height: 72,
                child: first.coverUri == null
                    ? CoverFallback(title: first.title)
                    : DsImage(
                        image: cachedImage(first.coverUri.toString()),
                        aspectRatio: 1,
                        semanticLabel: t.music.mineFavourites,
                        fallback: CoverFallback(title: first.title),
                      ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s4,
                children: [
                  Text(
                    t.music.mineFavourites,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.heading.copyWith(color: colors.text),
                  ),
                  Text(
                    total > Duration.zero
                        ? '${t.music.songsCount(count: favourites.length)} · ${musicDurationText(total)}'
                        : t.music.songsCount(count: favourites.length),
                    style: theme.typography.caption.copyWith(color: colors.textSubtle),
                  ),
                  Row(
                    spacing: DsSpace.s8,
                    children: [
                      DsButton(
                        variant: DsButtonVariant.primary,
                        size: DsSize.sm,
                        leading: const DsIcon(DsIcons.play, size: 16),
                        onPressed: () => unawaited(playerController.playAll(favourites)),
                        child: Text(t.music.playAll),
                      ),
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        leading: const DsIcon(DsIcons.shuffle, size: 16),
                        onPressed: () => unawaited(playerController.playAll([...favourites]..shuffle(math.Random()))),
                        child: Text(t.music.modeRandom),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: DsSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s16,
        children: [
          if (favourites.isNotEmpty) favouritesHeader(),
          if (favourites.isNotEmpty)
            section(t.music.mineFavourites, favourites, remove: favouriteController.remove, caption: false),
          if (recent.isNotEmpty) ...[
            section(t.music.mineRecent, recent, remove: recentController.remove),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: DsButton(
                  variant: DsButtonVariant.secondary,
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
