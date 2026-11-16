import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/browse/music_browse.dart';
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceListProvider;
import 'package:pure_live/modules/music/controller/playback/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/sources/music_browse_source.dart' show MusicAlbum;
import 'package:pure_live/modules/music/music_page.dart' show MusicView;
import 'package:pure_live/modules/music/widgets/music_actions.dart' show showAddTracksToPlaylistDialog;
import 'package:pure_live/modules/music/widgets/music_browse_links.dart' show openMusicArtist;
import 'package:pure_live/modules/music/widgets/music_browse_widgets.dart';
import 'package:pure_live/modules/music/widgets/music_detail_hero.dart' show MusicDetailHero;
import 'package:pure_live/modules/music/widgets/music_widgets.dart' show MusicSongTableHeader;
import 'package:pure_live/shared/shared.dart' show LiveWindow;

/// One album's page: its cover and credits, its songs, and the way into its
/// artist — the reference's album browse, read from the platform's own album
/// answer.
///
/// A platform without an album endpoint never reaches the loader: the page
/// says the platform does not support album browsing rather than showing an
/// empty album as if the platform had answered one.
final class MusicAlbumPage extends ConsumerWidget {
  /// The album [albumId] on [sourceId].
  const MusicAlbumPage({required this.sourceId, required this.albumId, super.key});

  /// The platform that serves the album.
  final String sourceId;

  /// The platform's album id.
  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final request = (sourceId: sourceId, albumId: albumId);
    // Escape walks back, the way it leaves the player.
    return CallbackShortcuts(
      bindings: <SingleActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: ColoredBox(
          color: colors.canvas,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MusicBrowseHeader(title: t.music.albumPageTitle),
                Expanded(
                  child: musicAlbumSourceIn(ref.watch(musicSourceListProvider), sourceId) == null
                      ? MusicBrowseUnsupported(
                          icon: MusicView.library.icon,
                          title: t.music.albumUnsupported,
                          sourceName: musicBrowseSourceLabel(ref, t, sourceId),
                        )
                      : _AlbumBody(request: request),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The album once its platform has answered.
final class _AlbumBody extends ConsumerWidget {
  const _AlbumBody({required this.request});

  final MusicAlbumRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return ref
        .watch(musicAlbumProvider(request))
        .when(
          loading: MusicBrowseLoading.new,
          error: (error, _) => MusicBrowseFailure(
            title: t.music.albumLoadFailed,
            error: error,
            onRetry: () => ref.invalidate(musicAlbumProvider(request)),
          ),
          data: (detail) {
            final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
            final tracks = detail.tracks;
            if (tracks.isEmpty) {
              return Center(
                child: DsEmptyState(
                  icon: DsIcon(MusicView.library.icon),
                  title: Text(t.music.albumEmptyTitle),
                  description: Text(t.music.albumEmptyDescription),
                ),
              );
            }
            return ListView.builder(
              padding: EdgeInsets.fromLTRB(inset, 0, inset, DsSpace.s16),
              itemCount: tracks.length + 1,
              itemBuilder: (context, offset) {
                if (offset == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AlbumHero(album: detail.album, sourceId: request.sourceId, tracks: tracks),
                      MusicBrowseSection(title: t.music.songsSection(count: tracks.length)),
                      const MusicSongTableHeader(),
                    ],
                  );
                }
                return MusicBrowseRow(tracks: tracks, index: offset - 1, listName: detail.album.name);
              },
            );
          },
        );
  }
}

/// The album's cover and credits above its songs: the cover at the design's
/// measure, the artist a link inside the one muted facts line — artist,
/// year, count, runtime — and the two verbs the page exists for — play it,
/// or file it in a list.
final class _AlbumHero extends ConsumerWidget {
  const _AlbumHero({required this.album, required this.sourceId, required this.tracks});

  final MusicAlbum album;
  final String sourceId;
  final List<audio.MusicTrack> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final sourceName = musicBrowseSourceLabel(ref, t, sourceId);
    final year = album.year;
    // The runtimes the platform did size add up to the line's about-N-minutes;
    // an unsized track simply doesn't count toward it.
    final knownSeconds = tracks.fold<int>(0, (total, track) {
      final duration = track.duration;
      return total + (duration == null || duration.inMilliseconds <= 0 ? 0 : duration.inSeconds);
    });
    final player = ref.read(musicPlayerProvider.notifier);
    // The facts line reads as the design's one muted row, the artist a
    // word of that line — the link that opens their page.
    final artistName = album.artist;
    return MusicDetailHero(
      coverUri: album.coverUri,
      fallbackTitle: album.name.isEmpty ? t.music.songAlbumUnknown : album.name,
      title: album.name.isEmpty ? t.music.songAlbumUnknown : album.name,
      subtitle: artistName.isEmpty
          ? null
          : DsLink(
              label: artistName,
              inline: true,
              style: DsLinkStyle(textStyle: theme.typography.caption.copyWith(color: colors.textMuted)),
              onPressed: () =>
                  openMusicArtist(context, sourceId: sourceId, artist: artistName, artistId: album.artistId),
            ),
      facts: [
        if (year != null) '$year',
        t.music.songsCount(count: album.trackCount > 0 ? album.trackCount : tracks.length),
        if (knownSeconds > 0) t.music.albumTotalDuration(count: (knownSeconds / 60).ceil()),
        sourceName,
      ],
      onPlayAll: () => unawaited(player.playAll(tracks)),
      playSemanticLabel: t.music.playAll,
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          leading: const DsIcon(DsIcons.listPlus, size: 16),
          onPressed: () => unawaited(showAddTracksToPlaylistDialog(context, ref, tracks)),
          child: Text(t.music.addToPlaylist),
        ),
      ],
    );
  }
}
