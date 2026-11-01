import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:media_core_audio/media_core_audio.dart' as audio;

import 'package:pure_live/app/routing/navigation/route_names.dart' show RouteNames;
import 'package:pure_live/modules/music/controller/sources/music_browse_source.dart' show musicMainArtist;

/// The ways into the music module's album and artist pages.
///
/// Kept apart from the pages' own widgets so a row, a stage line and a
/// detail sheet can all open them without the widgets importing each other.

/// The artist id a track carries, when its platform attached one.
String? musicTrackArtistId(audio.MusicTrack track) {
  final id = '${track.metadata['artistId'] ?? ''}'.trim();
  return id.isEmpty ? null : id;
}

/// Opens [albumId]'s page on the platform that serves it.
void openMusicAlbum(BuildContext context, {required String sourceId, required String albumId}) {
  if (albumId.trim().isEmpty) return;
  unawaited(context.push(RouteNames.musicAlbumFor(sourceId, albumId)));
}

/// Opens the page of [artist]'s first credit on the platform that serves it.
///
/// A credit naming several artists is the module's own `、` join; the page
/// belongs to the first name, the one the song is really credited to.
void openMusicArtist(BuildContext context, {required String sourceId, required String artist, String? artistId}) {
  final name = musicMainArtist(artist);
  if (name.isEmpty) return;
  unawaited(context.push(RouteNames.musicArtistFor(sourceId, name, artistId: artistId)));
}
