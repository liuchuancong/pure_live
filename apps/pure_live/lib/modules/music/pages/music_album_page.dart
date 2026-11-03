import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/music/controller/music_browse.dart';
import 'package:pure_live/modules/music/controller/music_playback.dart' show musicPlayerProvider;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceListProvider;
import 'package:pure_live/modules/music/controller/sources/music_browse_source.dart' show MusicAlbum;
import 'package:pure_live/modules/music/widgets/music_actions.dart' show showAddTracksToPlaylistDialog;
import 'package:pure_live/modules/music/widgets/music_browse_links.dart' show openMusicArtist;
import 'package:pure_live/modules/music/widgets/music_browse_widgets.dart';
import 'package:pure_live/modules/music/widgets/music_widgets.dart' show MusicSongTableHeader;
import 'package:pure_live/shared/shared.dart' show CoverFallback, LiveWindow, cachedImage;

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
                          icon: DsIcons.discAlbum,
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
            final tracks = detail.tracks;
            if (tracks.isEmpty) {
              return Center(
                child: DsEmptyState(
                  icon: const DsIcon(DsIcons.discAlbum),
                  title: Text(t.music.albumEmptyTitle),
                  description: Text(t.music.albumEmptyDescription),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: DsSpace.s24),
              itemCount: tracks.length + 1,
              itemBuilder: (context, offset) {
                if (offset == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AlbumHero(album: detail.album, sourceId: request.sourceId, tracks: tracks),
                      const SizedBox(height: DsSpace.s8),
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

/// The album's cover and credits above its songs: the cover large enough to
/// read, the artist a link into their page, and the two verbs the page
/// exists for — play it, or file it in a list.
final class _AlbumHero extends ConsumerWidget {
  const _AlbumHero({required this.album, required this.sourceId, required this.tracks});

  final MusicAlbum album;
  final String sourceId;
  final List<audio.MusicTrack> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    // The hero keeps the page's gutter, the live module's measure.
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    final sourceName = musicBrowseSourceLabel(ref, t, sourceId);
    final year = album.year;
    final facts = [
      sourceName,
      t.music.songsCount(count: album.trackCount > 0 ? album.trackCount : tracks.length),
      if (year != null) '$year',
    ].join(' · ');
    final player = ref.read(musicPlayerProvider.notifier);
    final actions = Wrap(
      spacing: DsSpace.s8,
      runSpacing: DsSpace.s8,
      children: [
        DsButton(
          leading: const DsIcon(DsIcons.play),
          onPressed: () => unawaited(player.playAll(tracks)),
          child: Text(t.music.playAll),
        ),
        DsButton(
          variant: DsButtonVariant.secondary,
          leading: const DsIcon(DsIcons.listPlus),
          onPressed: () => unawaited(showAddTracksToPlaylistDialog(context, ref, tracks)),
          child: Text(t.music.addToPlaylist),
        ),
      ],
    );
    final artist = album.artist.isEmpty
        ? null
        : DsLink(
            label: album.artist,
            style: DsLinkStyle(textStyle: theme.typography.body.copyWith(color: colors.textMuted)),
            onPressed: () =>
                openMusicArtist(context, sourceId: sourceId, artist: album.artist, artistId: album.artistId),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final cover = _AlbumCover(album: album, size: wide ? 200 : 148);
        final words = Column(
          crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          spacing: DsSpace.s8,
          children: [
            Text(
              album.name.isEmpty ? t.music.songAlbumUnknown : album.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: theme.typography.heading.copyWith(color: colors.text),
            ),
            ?artist,
            Text(
              facts,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: theme.typography.caption.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: DsSpace.s4),
            actions,
          ],
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s16),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: DsSpace.s20,
                  children: [
                    cover,
                    Expanded(child: words),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s12,
                  children: [
                    Center(child: cover),
                    words,
                  ],
                ),
        );
      },
    );
  }
}

/// The album's cover, rounded as every other cover in the module.
final class _AlbumCover extends StatelessWidget {
  const _AlbumCover({required this.album, required this.size});

  final MusicAlbum album;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DsImage(
      image: album.coverUri == null ? null : cachedImage(album.coverUri.toString()),
      width: size,
      height: size,
      semanticLabel: album.name,
      fallback: CoverFallback(title: album.name),
      style: DsImageStyle(borderRadius: BorderRadius.circular(theme.radii.overlay)),
    );
  }
}
