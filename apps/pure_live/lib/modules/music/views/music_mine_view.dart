import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/library/music_library.dart'
    show musicFavouritesProvider, musicRecentProvider, musicTrackKey;
import 'package:pure_live/modules/music/controller/playback/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/music_page.dart' show MusicView;
import 'package:pure_live/modules/music/widgets/music_actions.dart';
import 'package:pure_live/modules/music/widgets/music_widgets.dart';
import 'package:pure_live/shared/shared.dart' show CoverFallback, LiveWindow, cachedImage;
import 'package:pure_live/shared/widgets/app_dialog.dart';

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
    final playingKey = ref.watch(
      musicPlayerProvider.select((state) => (state.track == null ? null : musicTrackKey(state.track!))),
    );
    final playerController = ref.read(musicPlayerProvider.notifier);
    final favouriteController = ref.read(musicFavouritesProvider.notifier);
    final recentController = ref.read(musicRecentProvider.notifier);
    if (favourites.isEmpty && recent.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: DsIcon(MusicView.mine.icon),
          title: Text(t.music.mineEmptyTitle),
          description: Text(t.music.mineEmptyDescription),
        ),
      );
    }
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);

    /// Empties the favourites shelf after its confirmation, the recent list's
    /// own 清空 with the guard a whole-shelf wipe owes.
    Future<void> clearFavourites() async {
      final t = context.t;
      final confirmed = await showAppConfirm(
        context: context,
        title: t.music.favouritesClear,
        description: t.music.favouritesClearDesc,
        confirmLabel: t.common.delete,
        cancelLabel: t.common.cancel,
        destructive: true,
      );
      if (confirmed) await favouriteController.clear();
    }

    // One section as slivers: the caption over a card whose top carries the
    // table header and whose rows the SliverList builds as they scroll into
    // view — favourites are unbounded, and the eager Column built every one
    // of them at once. The card's look travels with the pieces: the header
    // and the cap wear the rounded corners and the shadow, the rows carry
    // the surface between them, dividers where the card's inner padding
    // starts.
    List<Widget> songSection(
      String title,
      List<audio.MusicTrack> songs, {
      required Future<void> Function(audio.MusicTrack track) remove,
      Widget? trailing,
      bool caption = true,
    }) => [
      if (caption)
        SliverPadding(
          padding: EdgeInsetsDirectional.fromSTEB(inset, 0, inset, DsSpace.s8),
          sliver: SliverToBoxAdapter(
            child: Row(
              spacing: DsSpace.s8,
              children: [
                Expanded(
                  child: Text(
                    '$title · ${t.music.songsCount(count: songs.length)}',
                    style: theme.typography.heading.copyWith(color: colors.text),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        sliver: SliverToBoxAdapter(
          child: DecoratedBox(
            decoration: DsBoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(theme.radii.card)),
              shadows: theme.shadows.surface,
            ),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(DsSpace.s5, DsSpace.s5, DsSpace.s5, 0),
              child: MusicSongTableHeader(),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        sliver: SliverList.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return Container(
              color: colors.surface,
              padding: const EdgeInsets.symmetric(horizontal: DsSpace.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: DsSpace.s12, end: 10),
                    child: DsLine(color: colors.border),
                  ),
                  MusicSongRow(
                    track: song,
                    number: index + 1,
                    playing: playingKey == musicTrackKey(song),
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
            );
          },
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: inset),
        sliver: SliverToBoxAdapter(
          child: DecoratedBox(
            decoration: DsBoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(theme.radii.card)),
              shadows: theme.shadows.surface,
            ),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(DsSpace.s5, 0, DsSpace.s5, DsSpace.s5),
              child: SizedBox.shrink(),
            ),
          ),
        ),
      ),
    ];
    Widget favouritesHeader() {
      final first = favourites.first;
      final total = favourites.fold(Duration.zero, (sum, track) => sum + (track.duration ?? Duration.zero));
      // The head keeps the page's gutter and the module's top measure, the
      // same head the boards and the playlist details draw: the cover at 72,
      // the list named over its facts, the verbs beside the text.
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(inset, DsSpace.s4, inset, 0),
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
                        image: cachedImage(first.coverUri.toString(), policy: ImageCachePolicies.albumCover),
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
                    style: theme.typography.caption.copyWith(color: colors.textMuted),
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
                      // The whole-shelf wipe rides beside the other header
                      // verbs: with the caption row off, the section's own
                      // tool line never rendered it.
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        onPressed: () => unawaited(clearFavourites()),
                        child: Text(t.music.favouritesClear),
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

    return CustomScrollView(
      slivers: [
        if (favourites.isNotEmpty) SliverToBoxAdapter(child: favouritesHeader()),
        if (favourites.isNotEmpty)
          ...songSection(t.music.mineFavourites, favourites, remove: favouriteController.remove, caption: false),
        if (favourites.isNotEmpty && recent.isNotEmpty) const SliverToBoxAdapter(child: SizedBox(height: DsSpace.s16)),
        if (recent.isNotEmpty)
          // The 清空 verb belongs on the section's own tool line, at its end
          // where the rest of the module puts the verbs that act on the
          // whole list.
          ...songSection(
            t.music.mineRecent,
            recent,
            remove: recentController.remove,
            trailing: DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: () => unawaited(recentController.clear()),
              child: Text(t.music.clearRecent),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: DsSpace.s16)),
      ],
    );
  }
}
