enum RumbleLinkKind { video, channel }

final class RumbleReference {
  const RumbleReference(this.kind, this.id);

  final RumbleLinkKind kind;
  final String id;
}

/// Strict parser for durable Rumble video pages and channel pages.
///
/// Rumble's public page identity (for example `v7fngda-title`) is different
/// from the embedded player identity (`v7dh3fs`). Only the public identity is
/// persisted by the app; the embedded identity is resolved from the page at
/// playback time.
abstract final class RumbleLink {
  static final RegExp _videoKey = RegExp(r'^v[0-9a-z]+(?:-[0-9a-z][0-9a-z-]*)?$', caseSensitive: false);
  static final RegExp _channel = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,79}$');

  static String requireVideoKey(String raw) {
    final key = parseVideoKey(raw);
    if (key == null) throw const FormatException('Invalid Rumble video identity');
    return key;
  }

  static String videoUrl(String raw) => 'https://rumble.com/${requireVideoKey(raw)}.html';

  static String channelUrl(String raw) => 'https://rumble.com/c/${requireChannel(raw)}';

  static String requireChannel(String raw) {
    final channel = parseChannel(raw);
    if (channel == null) throw const FormatException('Invalid Rumble channel identity');
    return channel;
  }

  static String? parseVideoKey(String raw) {
    final input = raw.trim();
    if (_videoKey.hasMatch(input)) return input.toLowerCase();
    final reference = parse(input);
    return reference?.kind == RumbleLinkKind.video ? reference!.id : null;
  }

  static String? parseChannel(String raw) {
    final input = raw.trim();
    final reference = parse(input);
    if (reference?.kind == RumbleLinkKind.channel) return reference!.id;
    if (_channel.hasMatch(input) && !_videoKey.hasMatch(input)) return input;
    return null;
  }

  static RumbleReference? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null ||
        (uri.scheme.toLowerCase() != 'https' && uri.scheme.toLowerCase() != 'http') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return null;
    }
    final host = uri.host.toLowerCase();
    if (host != 'rumble.com' && host != 'www.rumble.com') return null;
    late final List<String> segments;
    try {
      segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    } on FormatException {
      return null;
    }
    if (segments.length == 1 && segments.single.toLowerCase().endsWith('.html')) {
      final segment = segments.single;
      final key = segment.substring(0, segment.length - '.html'.length);
      if (!_videoKey.hasMatch(key)) return null;
      return RumbleReference(RumbleLinkKind.video, key.toLowerCase());
    }
    if (segments.length == 2 && const {'c', 'user'}.contains(segments.first.toLowerCase())) {
      final channel = segments[1];
      if (!_channel.hasMatch(channel)) return null;
      return RumbleReference(RumbleLinkKind.channel, channel);
    }
    return null;
  }
}
