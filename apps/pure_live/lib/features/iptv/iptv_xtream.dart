import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show IptvLibrary, PlaylistParseResult, XtreamCatalogService, XtreamSource;
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/iptv/iptv_preferences.dart';

/// The prefix every Xtream playlist record's [IptvLibrary] url key carries.
///
/// The playlist record an Xtream import writes is ordinary — the channels
/// are ordinary entries, so groups, favourites and zapping treat them like
/// any M3U's — but its `url` field is not a download address, it is the key
/// a refresh finds the record by and the mark the source chips read to tell
/// an Xtream source from a playlist file.
const String _xtreamUrlScheme = 'xtream:';

/// Whether [url] is the key of a playlist record an Xtream import wrote.
bool isXtreamPlaylistUrl(String? url) => (url ?? '').startsWith('$_xtreamUrlScheme//');

/// The stable playlist url key of [source]: same account in, same key out,
/// so a refresh replaces the record the first import wrote instead of
/// adding a second one, and the credentials are never part of it in the
/// clear.
String xtreamPlaylistUrl(IptvXtreamSource source) {
  final parsed = Uri.tryParse(source.url.trim());
  final host = (parsed == null || parsed.host.isEmpty) ? source.url.trim() : parsed.host;
  final port = parsed != null && parsed.hasPort ? ':${parsed.port}' : '';
  final user = Uri.encodeComponent(source.username.trim());
  return '$_xtreamUrlScheme//$user@$host$port';
}

/// The playlist record [source]'s imports own, null when none has landed
/// yet — a source whose first fetch failed has channels nowhere.
String? xtreamPlaylistId(IptvLibrary library, IptvXtreamSource source) {
  final key = xtreamPlaylistUrl(source);
  for (final playlist in library.playlists) {
    if (playlist.url == key) {
      return playlist.id;
    }
  }
  return null;
}

/// Reads [source]'s live catalogue through the player API and writes it
/// into [library] as an ordinary playlist, replacing the record of the
/// source's own previous import.
///
/// The channels are reconciled by their stream address exactly as an M3U
/// re-import is, so favourites and numbers survive a refresh. Answers the
/// number of channels the account served; a rejected account, an answer
/// that is no stream list, or a transport failure throws, and a genuinely
/// empty catalogue fails the import the way an empty playlist file would.
Future<int> importXtreamChannels({
  required IptvLibrary library,
  required XtreamCatalogService catalog,
  required IptvXtreamSource source,
}) async {
  final channels = await catalog.fetchChannels(
    XtreamSource(url: source.url, username: source.username, password: source.password),
  );
  await library.importResult(
    PlaylistParseResult(entries: [for (final channel in channels) channel.entry]),
    name: source.name,
    url: xtreamPlaylistUrl(source),
    replaceId: xtreamPlaylistId(library, source),
  );
  return channels.length;
}

/// The catalogue reader of the session, over the app's shared HTTP client.
final xtreamCatalogProvider = Provider<XtreamCatalogService>(
  (ref) => XtreamCatalogService(http: ref.watch(httpProvider)),
);

/// Whether [error] is the player API saying no to the credentials.
///
/// The catalogue service reports a refused account as the `FormatException`
/// whose message names the credentials — the one failure a user can fix by
/// retyping, so it gets its own words on screen.
bool isXtreamCredentialError(Object error) => error is FormatException && error.message.contains('credentials');
