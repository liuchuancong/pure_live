import 'dart:convert' show jsonDecode;

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest;
import 'package:live_vod/src/lyric_query.dart';

/// One lyric a lookup found: raw LRC (or plain text) for the lyric module
/// to parse.
final class VodLyric {
  /// A lyric text.
  const new({required this.lyric});

  /// The raw text: timed LRC when the lookup found a synced lyric, plain
  /// lines otherwise. Parsing belongs to the caller.
  final String lyric;
}

/// A public lyric lookup (LRCLIB), for tracks the video platform itself has
/// no lyric endpoint for.
///
/// Bilibili's music entries are ordinary archives, so a track's title needs
/// [LyricQuery] to become a song name and an artist. The lookup asks with
/// those parts first and, when the index wants a free-text phrase, once more
/// with `q`.
final class LyricLookup {
  /// A lookup over [http].
  new(this.http, {this.userAgent = _defaultUserAgent});

  /// The transport.
  final LiveHttp http;

  /// The identifying string LRCLIB asks clients to send.
  final String userAgent;

  static const String _defaultUserAgent = 'PureLive/1.0 (music lyric lookup)';

  /// The lyric for [query], or null when the lookup knows none.
  ///
  /// [duration] breaks ties between versions (a live take, a remix) by
  /// choosing the candidate closest in length.
  Future<VodLyric?> search(LyricQuery query, {Duration? duration}) async {
    if (!query.isUsable) return null;
    final lyric = await _searchOnce({
      'track_name': query.title,
      if (query.artist.isNotEmpty) 'artist_name': query.artist,
    }, duration);
    if (lyric != null) return lyric;
    if (query.artist.isEmpty) return null;
    return await _searchOnce({'q': '${query.title} ${query.artist}'}, duration);
  }

  Future<VodLyric?> _searchOnce(Map<String, String> params, Duration? duration) async {
    try {
      final response = await http.send(
        LiveRequest.custom(
          method: 'GET',
          url: Uri.https('lrclib.net', '/api/search', params),
          headers: {'user-agent': userAgent, 'accept': 'application/json'},
        ),
      );
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.text);
      if (json is! List) return null;
      final candidates = [
        for (final item in json)
          if (item is Map) ?_candidateOf(item),
      ];
      if (candidates.isEmpty) return null;
      // A synced lyric beats plain text; among equals the closest length wins.
      final synced = candidates.where((candidate) => candidate.synced).toList();
      final pool = synced.isNotEmpty ? synced : candidates;
      final seconds = duration?.inSeconds;
      if (seconds != null) {
        pool.sort((a, b) => ((a.seconds ?? 0) - seconds).abs().compareTo(((b.seconds ?? 0) - seconds).abs()));
      }
      return VodLyric(lyric: pool.first.lyric);
    } on Object {
      // A lookup that cannot answer leaves the track without a lyric; it is
      // not a playback failure.
      return null;
    }
  }

  static ({String lyric, int? seconds, bool synced})? _candidateOf(Map<Object?, Object?> item) {
    final synced = '${item['syncedLyrics'] ?? ''}'.trim();
    final plain = '${item['plainLyrics'] ?? ''}'.trim();
    if (synced.isEmpty && plain.isEmpty) return null;
    return (
      lyric: synced.isNotEmpty ? synced : plain,
      seconds: (item['duration'] as num?)?.round(),
      synced: synced.isNotEmpty,
    );
  }
}
