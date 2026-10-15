import 'package:live_sites/src/platforms/liveme/api/liveme_endpoints.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What a LiveMe link names.
enum LivemeLinkKind {
  /// A room: the anchor's short id, the room identity.
  shortId,

  /// An anchor's user id (`/u/<uid>`); its short id is in `user/getinfo`.
  userId,

  /// One broadcast (`/v/<vid>`, the share page `/m/v/<vid>/index.html`);
  /// its short id is in `live/queryinfosimple`.
  videoId,
}

/// A LiveMe link: a room page, an anchor page or a broadcast's share page on
/// `liveme.com` or `www.liveme.com`.
@immutable
final class LivemeLink {
  /// Creates a link.
  const LivemeLink(this.kind, this.id);

  /// Room, anchor or broadcast.
  final LivemeLinkKind kind;

  /// The short id, user id or video id.
  final String id;

  static final RegExp _locale = RegExp(r'^[a-z]{2}(?:-[a-z]{2,4})?$', caseSensitive: false);

  /// The link [raw] is, exactly as the reference read it, or null: http(s)
  /// on `liveme.com` or `www.liveme.com` (any port, no user info), an
  /// optional locale segment first (`us`, `zh-tw`), then
  /// - `livehot/streaming/<short id>`: a room;
  /// - `u/<user id>`: an anchor;
  /// - `v/<video id>` or `m/v/<video id>/index.html`: a broadcast.
  ///
  /// Words are matched in any case; query and fragment are ignored. A path
  /// that does not decode is no link.
  static LivemeLink? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        (uri.host.toLowerCase() != 'liveme.com' && uri.host.toLowerCase() != 'www.liveme.com')) {
      return null;
    }
    final List<String> segments;
    try {
      segments = uri.pathSegments.where((value) => value.isNotEmpty).toList(growable: false);
    } on FormatException {
      return null;
    }
    if (segments.isEmpty || segments.any((value) => value == '.' || value == '..')) return null;
    final tail = _locale.hasMatch(segments.first) ? segments.sublist(1) : segments;
    final words = [for (final segment in tail) segment.toLowerCase()];
    switch (words) {
      case ['livehot', 'streaming', _]:
        final id = LivemeEndpoints.normalizeShortId(tail[2]);
        return id == null ? null : LivemeLink(LivemeLinkKind.shortId, id);
      case ['u', _]:
        final id = LivemeEndpoints.normalizeLongId(tail[1]);
        return id == null ? null : LivemeLink(LivemeLinkKind.userId, id);
      case ['v', _]:
        final id = LivemeEndpoints.normalizeLongId(tail[1]);
        return id == null ? null : LivemeLink(LivemeLinkKind.videoId, id);
      case ['m', 'v', _, 'index.html']:
        final id = LivemeEndpoints.normalizeLongId(tail[2]);
        return id == null ? null : LivemeLink(LivemeLinkKind.videoId, id);
    }
    return null;
  }

  /// [parse], else a bare short id (what search looks up directly).
  static LivemeLink? parseOrShortId(String raw) {
    final parsed = parse(raw);
    if (parsed != null) return parsed;
    final id = LivemeEndpoints.normalizeShortId(raw);
    return id == null ? null : LivemeLink(LivemeLinkKind.shortId, id);
  }

  @override
  bool operator ==(Object other) => other is LivemeLink && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'LivemeLink(${kind.name}, $id)';
}
