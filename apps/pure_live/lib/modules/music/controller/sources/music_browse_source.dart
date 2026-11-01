import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/modules/music/controller/sources/music_source_cache.dart' show CachedLyricSource;

/// One album as the browse pages present it: its identity, its artist and the
/// cover the platform gave.
final class MusicAlbum {
  /// An album page's identity.
  const MusicAlbum({
    required this.id,
    required this.name,
    required this.artist,
    this.artistId,
    this.coverUri,
    this.trackCount = 0,
    this.year,
  });

  /// The platform's album id.
  final String id;

  /// Display name.
  final String name;

  /// The artist line, as the platform credits it.
  final String artist;

  /// The artist's platform id, when the answer carried one.
  final String? artistId;

  /// Cover image.
  final Uri? coverUri;

  /// How many songs the album holds; 0 when the platform never said.
  final int trackCount;

  /// The release year, when the platform said.
  final int? year;
}

/// An album's page: its identity and its songs in the platform's order.
typedef MusicAlbumDetail = ({MusicAlbum album, List<audio.MusicTrack> tracks});

/// An artist's page: who they are, the songs the source credits to them, and
/// their albums.
typedef MusicArtistDetail = ({
  String name,
  String? artistId,
  Uri? avatarUri,
  List<audio.MusicTrack> songs,
  List<MusicAlbum> albums,
});

/// A platform that can answer an album's page beside the source contract.
///
/// Only a platform with a real album endpoint implements this; every other
/// source stays without it, so the pages can say so instead of showing an
/// empty album that looks like the platform's fault.
abstract interface class MusicAlbumSource {
  /// The album [albumId] and its songs.
  Future<MusicAlbumDetail> album(String albumId);
}

/// A platform that can answer an artist's page beside the source contract.
abstract interface class MusicArtistSource {
  /// The artist called [name], and [artistId] when the caller already knows
  /// it, with the songs and albums the platform credits to them.
  Future<MusicArtistDetail> artist(String name, {String? artistId});
}

/// The artist a credit line leads with — the module joins several names with
/// `、`, so the first one is the page's subject and the rest are features.
String musicMainArtist(String artist) {
  final separator = artist.indexOf('、');
  return (separator < 0 ? artist : artist.substring(0, separator)).trim();
}

/// The capability [source] carries, looked for underneath the lyric wrappers.
///
/// The module wraps every platform in [CachedLyricSource] (and the display
/// layer extends it), so the wrappers have to be walked or every decorated
/// source would look incapable.
T? musicCapabilityOf<T extends Object>(audio.MusicSource source) {
  audio.MusicSource? current = source;
  while (current != null) {
    if (current is T) return current as T;
    current = switch (current) {
      CachedLyricSource(:final inner) => inner,
      _ => null,
    };
  }
  return null;
}
