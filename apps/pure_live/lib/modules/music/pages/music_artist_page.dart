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
import 'package:pure_live/modules/music/widgets/music_actions.dart' show showAddTracksToPlaylistDialog;
import 'package:pure_live/modules/music/widgets/music_browse_links.dart' show openMusicAlbum;
import 'package:pure_live/modules/music/widgets/music_browse_widgets.dart';
import 'package:pure_live/modules/music/widgets/music_widgets.dart' show MusicSongTableHeader;
import 'package:pure_live/shared/shared.dart' show CoverFallback, cachedImage;

/// One artist's page: who they are, the songs the platform credits to them,
/// and their albums — each album opening its own page.
///
/// An empty answer on one half is said plainly (no songs for this artist,
/// no albums listed) instead of the page pretending the other half is all
/// there is.
final class MusicArtistPage extends ConsumerWidget {
  /// The artist called [name] on [sourceId]; [artistId] rides along when the
  /// route knew the platform's own id.
  const MusicArtistPage({required this.sourceId, required this.name, this.artistId, super.key});

  /// The platform that serves the page.
  final String sourceId;

  /// The artist's name, already the first credit of the song it came from.
  final String name;

  /// The platform's artist id, when known.
  final String? artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final request = (sourceId: sourceId, name: name, artistId: artistId);
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
                MusicBrowseHeader(title: t.music.artistPageTitle),
                Expanded(
                  child: musicArtistSourceIn(ref.watch(musicSourceListProvider), sourceId) == null
                      ? MusicBrowseUnsupported(
                          icon: DsIcons.userRound,
                          title: t.music.artistUnsupported,
                          sourceName: musicBrowseSourceLabel(ref, t, sourceId),
                        )
                      : _ArtistBody(request: request),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The artist once their platform has answered.
final class _ArtistBody extends ConsumerWidget {
  const _ArtistBody({required this.request});

  final MusicArtistRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return ref
        .watch(musicArtistProvider(request))
        .when(
          loading: MusicBrowseLoading.new,
          error: (error, _) => MusicBrowseFailure(
            title: t.music.artistLoadFailed,
            error: error,
            onRetry: () => ref.invalidate(musicArtistProvider(request)),
          ),
          data: (detail) {
            if (detail.songs.isEmpty && detail.albums.isEmpty) {
              return Center(
                child: DsEmptyState(
                  icon: const DsIcon(DsIcons.userRound),
                  title: Text(t.music.artistEmptyTitle),
                  description: Text(t.music.artistEmptyDescription),
                ),
              );
            }
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _ArtistHero(
                    name: detail.name,
                    avatarUri: detail.avatarUri,
                    songs: detail.songs,
                    albumCount: detail.albums.length,
                    sourceId: request.sourceId,
                  ),
                ),
                SliverToBoxAdapter(child: MusicBrowseSection(title: t.music.searchTypeSongs)),
                if (detail.songs.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20, vertical: DsSpace.s8),
                      child: Text(
                        t.music.artistSongsEmpty,
                        style: DsTheme.of(context).typography.body.copyWith(color: DsTheme.colorsOf(context).textMuted),
                      ),
                    ),
                  )
                else ...[
                  const SliverToBoxAdapter(child: MusicSongTableHeader()),
                  SliverList.builder(
                    itemCount: detail.songs.length,
                    itemBuilder: (context, index) =>
                        MusicBrowseRow(tracks: detail.songs, index: index, listName: detail.name),
                  ),
                ],
                if (detail.albums.isNotEmpty) ...[
                  SliverToBoxAdapter(child: MusicBrowseSection(title: t.music.albumPageTitle)),
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: DsSpace.s12,
                        children: [
                          for (final album in detail.albums)
                            MusicAlbumCard(
                              album: album,
                              onPressed: () => openMusicAlbum(context, sourceId: request.sourceId, albumId: album.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: DsSpace.s24)),
              ],
            );
          },
        );
  }
}

/// The artist's identity above their lists: the avatar at reading size, the
/// name, what the page holds, and the verbs that play it all.
final class _ArtistHero extends ConsumerWidget {
  const _ArtistHero({
    required this.name,
    required this.avatarUri,
    required this.songs,
    required this.albumCount,
    required this.sourceId,
  });

  final String name;
  final Uri? avatarUri;
  final List<audio.MusicTrack> songs;
  final int albumCount;
  final String sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final facts = [
      musicBrowseSourceLabel(ref, t, sourceId),
      if (songs.isNotEmpty) t.music.songsCount(count: songs.length),
      if (albumCount > 0) t.music.albumsCount(count: albumCount),
    ].join(' · ');
    final player = ref.read(musicPlayerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s20,
        children: [
          ClipOval(
            child: DsImage(
              image: avatarUri == null ? null : cachedImage(avatarUri.toString()),
              width: 112,
              height: 112,
              semanticLabel: name,
              fallback: CoverFallback(title: name, padding: const EdgeInsets.all(DsSpace.s12)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s8,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.heading.copyWith(color: colors.text),
                ),
                Text(
                  facts,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                ),
                if (songs.isNotEmpty)
                  Wrap(
                    spacing: DsSpace.s8,
                    runSpacing: DsSpace.s8,
                    children: [
                      DsButton(
                        leading: const DsIcon(DsIcons.play),
                        onPressed: () => unawaited(player.playAll(songs)),
                        child: Text(t.music.playAll),
                      ),
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        leading: const DsIcon(DsIcons.listPlus),
                        onPressed: () => unawaited(showAddTracksToPlaylistDialog(context, ref, songs)),
                        child: Text(t.music.addToPlaylist),
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
}
