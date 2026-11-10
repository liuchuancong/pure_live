import 'package:meta/meta.dart';

/// An Xtream Codes account: the server's address and the credentials that
/// play its streams.
///
/// The three fields are everything the player API needs, and the address
/// helpers ([playerApi] and [liveStreamUrl]) build the two kinds of URL the
/// catalogue and the player ask for — so the ecosystem's path spellings
/// live here, next to the account they hang from, instead of being
/// reconstructed wherever a URL is needed.
@immutable
final class XtreamSource {
  /// An Xtream Codes source.
  const new({required this.url, required this.username, required this.password});

  /// The server's base address, such as `http://example.tv:8080`.
  final String url;

  /// The account's user name.
  final String username;

  /// The account's password.
  final String password;

  /// The player API address — `player_api.php` with the credentials in the
  /// query, and [action] appended when given.
  ///
  /// A base address that serves the panel from a sub-path keeps that prefix.
  /// Throws a [FormatException] when [url] is not an http(s) address.
  Uri playerApi({String? action}) {
    final base = _base;
    return Uri(
      scheme: base.scheme,
      userInfo: base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '${_directory(base)}player_api.php',
      queryParameters: {
        'username': username,
        'password': password,
        if (action != null && action.trim().isNotEmpty) 'action': action.trim(),
      },
    );
  }

  /// The playable address of live stream [streamId]:
  /// `/live/{user}/{pass}/{id}.m3u8`.
  ///
  /// HLS is the one spelling on purpose: the reference app does not
  /// distinguish `.m3u8` from `.ts`, and `.m3u8` is what every Xtream Codes
  /// server serves and what the player opens directly. The credentials are
  /// written as encoded path segments, because accounts with punctuation in
  /// them exist.
  ///
  /// Throws a [FormatException] when [url] is not an http(s) address, and
  /// an [ArgumentError] when [streamId] is empty.
  Uri liveStreamUrl(String streamId) {
    final id = streamId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(streamId, 'streamId', 'must not be empty');
    }
    final base = _base;
    return Uri(
      scheme: base.scheme,
      userInfo: base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path:
          '${_directory(base)}live/${Uri.encodeComponent(username.trim())}/'
          '${Uri.encodeComponent(password.trim())}/$id.m3u8',
    );
  }

  /// The parsed [url], judged rather than trusted.
  /// The account's live list as a playlist address: `get.php` with
  /// `type=m3u_plus`, the M3U every Xtream Codes panel serves its catalogue
  /// as, with HLS addresses ([output]) for the reason [liveStreamUrl] gives.
  ///
  /// The list is an address like any other, so it imports, syncs and
  /// survives a backup the way every playlist does. The panel lists its
  /// films and series in it too; [isXtreamLiveEntry] tells the importer which
  /// rows are live. Throws a [FormatException] when [url] is not an http(s)
  /// address.
  Uri playlistUrl({String output = 'm3u8'}) {
    final base = _base;
    return Uri(
      scheme: base.scheme,
      userInfo: base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '${_directory(base)}get.php',
      queryParameters: {'username': username.trim(), 'password': password.trim(), 'type': 'm3u_plus', 'output': output},
    );
  }

  Uri get _base {
    final parsed = Uri.parse(url.trim());
    if ((parsed.scheme != 'http' && parsed.scheme != 'https') || parsed.host.isEmpty) {
      throw FormatException('an Xtream source needs an http(s) server address', url);
    }
    return parsed;
  }

  /// The base path as a directory, so a sub-path prefix survives.
  static String _directory(Uri base) {
    final path = base.path;
    return path.endsWith('/') ? path : '$path/';
  }

  /// This source with one field replaced.
  XtreamSource copyWith({String? url, String? username, String? password}) =>
      XtreamSource(url: url ?? this.url, username: username ?? this.username, password: password ?? this.password);

  @override
  bool operator ==(Object other) =>
      other is XtreamSource && other.url == url && other.username == username && other.password == password;

  @override
  int get hashCode => Object.hash(url, username, password);

  @override
  String toString() => 'XtreamSource($url, user: $username)'; // the password stays out of logs.
}

/// Whether [url] is an Xtream Codes panel's playlist address
/// ([XtreamSource.playlistUrl]): `get.php` with an account in its query.
bool isXtreamPlaylistUrl(Uri url) {
  if (!url.path.endsWith('get.php')) {
    return false;
  }
  final query = url.queryParameters;
  return (query['username'] ?? '').isNotEmpty && (query['password'] ?? '').isNotEmpty;
}

/// Whether [url], a row of an Xtream Codes M3U, is a live channel.
///
/// The panels file their films under `/movie/` and their episodes under
/// `/series/`; everything else they list is live. A live library of fifty
/// thousand film rows is a library nobody can zap through, so the importer
/// keeps the live rows of an Xtream list and leaves the rest to the panel.
bool isXtreamLiveEntry(String url) {
  final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
  return !segments.contains('movie') && !segments.contains('series');
}
