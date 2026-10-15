import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What a TikTok link or search keyword names.
enum TiktokLinkKind {
  /// `@<username>`: the room itself; the username is the room id.
  username,

  /// `share/live/<LIVE room id>`: its owner is the room, found by one
  /// request (`webcast/room/info`).
  liveRoom,
}

/// A parsed TikTok link or search keyword.
@immutable
final class TiktokLink {
  /// Creates a link.
  const TiktokLink(this.kind, this.id);

  /// What [id] names.
  final TiktokLinkKind kind;

  /// A normalized username or LIVE room id.
  final String id;

  static const Set<String> _hosts = {'tiktok.com', 'www.tiktok.com', 'm.tiktok.com'};
  static const Set<String> _shortHosts = {'vm.tiktok.com', 'vt.tiktok.com'};
  static final RegExp _username = RegExp(r'^[a-z0-9_](?:[a-z0-9._]{0,22}[a-z0-9_])?$');
  static final RegExp _liveRoomId = RegExp(r'^[1-9][0-9]{14,24}$');

  /// [raw] trimmed and lower case when it is a username (letters, digits,
  /// `_` and `.`, at most 24, not starting or ending with a dot), else null.
  static String? normalizeUsername(String raw) {
    final value = raw.trim().toLowerCase();
    return _username.hasMatch(value) ? value : null;
  }

  /// [raw] trimmed when it is a LIVE room id (15–25 digits), else null.
  static String? normalizeLiveRoomId(String raw) {
    final value = raw.trim();
    return _liveRoomId.hasMatch(value) ? value : null;
  }

  /// The TikTok web link [raw] is, or null: http(s) on `tiktok.com`,
  /// `www.tiktok.com` or `m.tiktok.com`, without user info or fragment,
  /// whose path is exactly `/@<user>`, `/@<user>/live` or
  /// `/share/live/<LIVE room id>` (a trailing slash allowed, dot segments
  /// refused). A video (`/@<user>/video/…`) is no room.
  static TiktokLink? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !_isWeb(uri) || uri.hasFragment || !_hosts.contains(uri.host.toLowerCase())) {
      return null;
    }
    final segments = _segments(uri);
    if (segments == null || segments.any((segment) => segment == '.' || segment == '..')) return null;
    if (segments case [final at] || [final at, _] when at.startsWith('@')) {
      if (segments.length == 2 && segments[1].toLowerCase() != 'live') return null;
      final user = normalizeUsername(at.substring(1));
      return user == null ? null : TiktokLink(TiktokLinkKind.username, user);
    }
    if (segments case [final share, final live, final room]
        when share.toLowerCase() == 'share' && live.toLowerCase() == 'live') {
      final id = normalizeLiveRoomId(room);
      return id == null ? null : TiktokLink(TiktokLinkKind.liveRoom, id);
    }
    return null;
  }

  /// What a search keyword names: a link (see [parse]), else a username with
  /// or without `@`; null for anything else.
  static TiktokLink? lookup(String keyword) {
    final link = parse(keyword);
    if (link != null) return link;
    final text = keyword.trim();
    final user = normalizeUsername(text.startsWith('@') ? text.substring(1) : text);
    return user == null ? null : TiktokLink(TiktokLinkKind.username, user);
  }

  /// The share short link [raw] is, whose redirect leads to the room:
  /// `vm.tiktok.com/<code>` and `vt.tiktok.com/<code>`, and the app's newer
  /// `www.tiktok.com/t/<code>` form; null for anything else.
  static Uri? shortLink(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !_isWeb(uri)) return null;
    final host = uri.host.toLowerCase();
    final segments = _segments(uri);
    if (segments == null || segments.isEmpty) return null;
    if (_shortHosts.contains(host)) return uri;
    return _hosts.contains(host) && segments.length == 2 && segments.first == 't' ? uri : null;
  }

  /// Whether [host] is one of TikTok's (so a link there that names no room
  /// is this platform's, not a foreign one).
  static bool ownsHost(String host) =>
      _hosts.contains(host) || _shortHosts.contains(host) || host.endsWith('.tiktok.com');

  static bool _isWeb(Uri uri) => (uri.scheme == 'http' || uri.scheme == 'https') && uri.userInfo.isEmpty;

  /// The non-empty path segments, or null when the path does not decode.
  static List<String>? _segments(Uri uri) {
    try {
      return uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    } on FormatException {
      return null;
    }
  }
}
