import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/music_library.dart'
    show musicFavouritesProvider, musicRecentProvider;
import 'package:pure_live/modules/music/controller/music_source.dart' show musicSourceListProvider;
import 'package:pure_live/modules/music/controller/sources/music_browse_source.dart';

/// One album page's request: the platform that serves it and the album id.
typedef MusicAlbumRequest = ({String sourceId, String albumId});

/// One artist page's request.
typedef MusicArtistRequest = ({String sourceId, String name, String? artistId});

/// The album capability [sourceId] carries, or null when the platform has
/// none — the pages say so rather than asking for an album it cannot serve.
MusicAlbumSource? musicAlbumSourceIn(List<audio.MusicSource> sources, String sourceId) {
  for (final source in sources) {
    if (source.id == sourceId) return musicCapabilityOf<MusicAlbumSource>(source);
  }
  return null;
}

/// The artist capability [sourceId] carries, or null when the platform has
/// none.
MusicArtistSource? musicArtistSourceIn(List<audio.MusicSource> sources, String sourceId) {
  for (final source in sources) {
    if (source.id == sourceId) return musicCapabilityOf<MusicArtistSource>(source);
  }
  return null;
}

/// One album's page, read from the platform that serves it.
final FutureProviderFamily<MusicAlbumDetail, MusicAlbumRequest> musicAlbumProvider =
    FutureProvider.family<MusicAlbumDetail, MusicAlbumRequest>((ref, request) {
      final source = musicAlbumSourceIn(ref.watch(musicSourceListProvider), request.sourceId);
      if (source == null) throw StateError('${request.sourceId} has no album browsing');
      return source.album(request.albumId);
    });

/// One artist's page, read from the platform that serves it.
final FutureProviderFamily<MusicArtistDetail, MusicArtistRequest> musicArtistProvider =
    FutureProvider.family<MusicArtistDetail, MusicArtistRequest>((ref, request) {
      final source = musicArtistSourceIn(ref.watch(musicSourceListProvider), request.sourceId);
      if (source == null) throw StateError('${request.sourceId} has no artist browsing');
      return source.artist(request.name, artistId: request.artistId);
    });

/// One album a home rail can open: the platform that serves it and the album
/// as the viewer's own history named it.
typedef MusicAlbumLink = ({String sourceId, MusicAlbum album});

/// One artist a home rail can open.
typedef MusicArtistLink = ({String sourceId, String name, String? artistId});

/// How many cards one home rail holds, the playlist strip's taste.
const int kMusicBrowseRailSize = 12;

/// The albums the viewer's history names, newest first: recents before
/// favourites, one card per album, and only albums whose platform can serve a
/// page. The rails never ask for a "new releases" list the platforms do not
/// expose.
final Provider<List<MusicAlbumLink>> musicHistoryAlbumsProvider = Provider<List<MusicAlbumLink>>((ref) {
  final sources = ref.watch(musicSourceListProvider);
  final seen = <String>{};
  final albums = <MusicAlbumLink>[];
  for (final track in [...ref.watch(musicRecentProvider), ...ref.watch(musicFavouritesProvider)]) {
    if (albums.length >= kMusicBrowseRailSize) break;
    final id = (track.albumId ?? '').trim();
    final name = track.album.trim();
    if (id.isEmpty || name.isEmpty) continue;
    if (musicAlbumSourceIn(sources, track.sourceId) == null) continue;
    if (!seen.add('${track.sourceId}/$id')) continue;
    albums.add((
      sourceId: track.sourceId,
      album: MusicAlbum(id: id, name: name, artist: track.artist, coverUri: track.coverUri),
    ));
  }
  return albums;
});

/// The artists the viewer's history credits, newest first, one card per name
/// on its own platform, and only artists whose platform can serve a page.
final Provider<List<MusicArtistLink>> musicHistoryArtistsProvider = Provider<List<MusicArtistLink>>((ref) {
  final sources = ref.watch(musicSourceListProvider);
  final seen = <String>{};
  final artists = <MusicArtistLink>[];
  for (final track in [...ref.watch(musicRecentProvider), ...ref.watch(musicFavouritesProvider)]) {
    if (artists.length >= kMusicBrowseRailSize) break;
    final name = musicMainArtist(track.artist);
    if (name.isEmpty) continue;
    if (musicArtistSourceIn(sources, track.sourceId) == null) continue;
    if (!seen.add('${track.sourceId}/$name')) continue;
    final artistId = '${track.metadata['artistId'] ?? ''}'.trim();
    artists.add((sourceId: track.sourceId, name: name, artistId: artistId.isEmpty ? null : artistId));
  }
  return artists;
});
