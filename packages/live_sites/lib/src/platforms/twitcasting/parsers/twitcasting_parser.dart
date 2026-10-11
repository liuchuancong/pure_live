import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the TwitCasting channel pages and streamserver.
abstract final class TwitcastingParser {
  /// Web origin.
  static const String origin = 'https://twitcasting.tv';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': '$origin/',
  };

  /// Media headers of channel [channel].
  static Map<String, String> mediaHeaders(String channel) => {
    'user-agent': headers['user-agent']!,
    'referer': '$origin/$channel',
  };

  /// The lower-case channel of a reference: a bare name, or a
  /// `twitcasting.tv/<channel>` link.
  static String? channelName(String reference) {
    var value = reference.trim();
    final uri = Uri.tryParse(value);
    if (uri != null && uri.host.isNotEmpty) {
      if (uri.host != 'twitcasting.tv' && uri.host != 'www.twitcasting.tv') {
        return null;
      }
      final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
      if (segments.isEmpty) {
        return null;
      }
      value = segments.first;
    }
    final match = RegExp(r'^[A-Za-z0-9_]{1,64}$').firstMatch(value);
    return match == null ? null : value.toLowerCase();
  }

  static final RegExp _meta = RegExp(r'<meta\b[^>]*>', caseSensitive: false);
  static final RegExp _metaAttr = RegExp(r'([\w:-]+)\s*=\s*"([^"]*)"');

  static Map<String, String> _attributes(String source) => {
    for (final match in _metaAttr.allMatches(source)) match.group(1)!: match.group(2)!,
  };

  /// The channel page → the room. A redirect (>=300) is "not found"; a
  /// secret-word page marks the broadcast protected.
  static ({LiveRoom room, bool secretWord, int? movieId, DateTime? liveStartedAt}) channelPage(
    String body, {
    required String roomId,
    required String channel,
    int status = 200,
  }) {
    if (status >= 300 && status < 400) {
      throw SiteNotFoundError('twitcasting channel page of $channel: HTTP $status (sent home)');
    }
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('twitcasting channel page: HTTP $status');
    }
    if (body.contains('Enter the secret word to access')) {
      return (
        room: LiveRoom(platform: SiteIds.twitcasting, roomId: roomId),
        secretWord: true,
        movieId: null,
        liveStartedAt: null,
      );
    }
    String? meta(String attribute, String name) {
      for (final tag in _meta.allMatches(body)) {
        final attributes = _attributes(tag.group(0)!);
        if (attributes[attribute] == name) {
          return attributes['content'];
        }
      }
      return null;
    }

    final creator = meta('name', 'twitter:creator') ?? '';
    if (channelName(creator) != channel) {
      throw SiteApiChangedError('twitcasting channel page of $channel: creator "$creator"');
    }
    final title = meta('name', 'twitter:title') ?? '';
    final telop = _classText(body, 'tw-player-page-title-description');
    final name = _classText(body, 'tw-user-nav2-name');
    final avatar = _classAttribute(body, 'tw-user-nav2-icon', 'img', 'src');
    final movieMatch = RegExp(r'data-movie-id="(\d+)"').firstMatch(body);
    final timerMatch = RegExp('<[^>]*id="updatetimer"[^>]*>', caseSensitive: false).firstMatch(body);
    final timerAttributes = timerMatch == null ? const <String, String>{} : _attributes(timerMatch.group(0)!);
    final started = int.tryParse(timerAttributes['data-started-at'] ?? '');
    return (
      room: LiveRoom(
        platform: SiteIds.twitcasting,
        roomId: roomId,
        title: telop.isNotEmpty ? telop : title,
        nick: name.isEmpty ? channel : name,
        avatar: avatar,
        cover: meta('property', 'og:image'),
      ),
      secretWord: false,
      movieId: movieMatch == null ? null : int.tryParse(movieMatch.group(1)!),
      liveStartedAt: timerAttributes['data-live-type'] == 'live' && started != null && started > 0
          ? DateTime.fromMillisecondsSinceEpoch(started, isUtc: true)
          : null,
    );
  }

  /// The text of the first element carrying [className] (tags stripped).
  static String _classText(String body, String className) {
    final match = RegExp('<[^>]*class="[^"]*$className[^"]*"[^>]*>', caseSensitive: false).firstMatch(body);
    if (match == null) {
      return '';
    }
    final start = match.end;
    final end = body.indexOf('<', start);
    return _stripTags(body.substring(start, end < 0 ? body.length : end)).trim();
  }

  /// The [attribute] of the first [tag] inside the first element carrying
  /// [className].
  static String? _classAttribute(String body, String className, String tag, String attribute) {
    final match = RegExp('<[^>]*class="[^"]*$className[^"]*"[^>]*>', caseSensitive: false).firstMatch(body);
    if (match == null) {
      return null;
    }
    final rest = body.substring(match.end);
    final inner = RegExp('<' + tag + r'\b[^>]*>', caseSensitive: false).firstMatch(rest);
    if (inner == null) {
      return null;
    }
    final value = _attributes(inner.group(0)!)[attribute] ?? '';
    return value.isEmpty ? null : value;
  }

  static String _stripTags(String text) => text.replaceAll(RegExp('<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ');

  /// `streamserver.php` → the broadcast state, movie id and HLS tiers.
  /// `{}` is a channel that does not exist; a private broadcast is not
  /// live for an anonymous client.
  static ({bool live, int? movieId, Map<String, String> streams}) streamServer(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('twitcasting streamserver: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('twitcasting streamserver: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('twitcasting streamserver: body is not an object');
    }
    if (decoded.isEmpty) {
      throw const SiteNotFoundError('twitcasting streamserver: no such channel');
    }
    final movie = decoded['movie'];
    if (movie is! Map<String, Object?>) {
      throw const SiteApiChangedError('twitcasting streamserver: no movie');
    }
    final live = movie['live'];
    if (live is! bool) {
      throw const SiteApiChangedError('twitcasting streamserver: movie.live is not a boolean');
    }
    final streams = <String, String>{};
    final tc = decoded['tc-hls'];
    final rawStreams = tc is Map<String, Object?> ? tc['streams'] : null;
    if (rawStreams is Map<String, Object?>) {
      for (final key in const ['high', 'medium', 'low']) {
        final url = rawStreams[key]?.toString() ?? '';
        if (url.isNotEmpty) {
          streams[key] = url;
        }
      }
    }
    return (live: live, movieId: (movie['id'] as num?)?.toInt(), streams: streams);
  }

  /// The play lines of a live, unprotected broadcast: the HLS tiers with
  /// their labels, best first.
  static List<LivePlayLine> playLines(({bool live, int? movieId, Map<String, String> streams}) stream, String channel) {
    if (!stream.live) {
      throw const SiteNotFoundError('twitcasting streamserver: not broadcasting');
    }
    final movie = stream.movieId;
    if (movie == null || movie <= 0) {
      throw const SiteApiChangedError('twitcasting streamserver: no movie id');
    }
    final labels = {'high': 'HLS high', 'medium': 'HLS medium', 'low': 'HLS low'};
    final lines = <LivePlayLine>[];
    for (final key in const ['high', 'medium', 'low']) {
      final url = stream.streams[key];
      if (url == null || !url.startsWith('https://') || !url.contains('twitcasting.tv')) {
        continue;
      }
      lines.add(
        LivePlayLine(
          url: url,
          headers: mediaHeaders(channel),
          format: StreamFormat.hls,
          codec: 'avc',
          lineId: labels[key] ?? key,
        ),
      );
    }
    if (lines.isEmpty) {
      throw const SiteApiChangedError('twitcasting streamserver: no valid HLS tier');
    }
    return lines;
  }
}
