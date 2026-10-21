import 'dart:convert' show jsonDecode;

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse;

/// One video a platform's search returned.
final class VodVideo {
  /// A video hit.
  const new({
    required this.id,
    required this.title,
    this.coverUrl,
    this.uploader,
    this.duration,
    this.playCount,
    this.bvid,
    this.aid,
  });

  /// The source's own id (the bvid on Bilibili).
  final String id;

  /// The video's title, with the search's highlight markup stripped.
  final String title;

  /// The cover address; null when the source gave none.
  final String? coverUrl;

  /// The uploader's name.
  final String? uploader;

  /// The length.
  final Duration? duration;

  /// How many times it was played.
  final int? playCount;

  /// The bvid, for a source that separates ids.
  final String? bvid;

  /// The numeric aid, for a source that separates ids.
  final int? aid;
}

/// A playable address and what it expects.
final class VodPlayInfo {
  /// A play address.
  const new({required this.url, this.headers = const {}, this.expiresAt, this.format = 'mp4', this.quality});

  /// The address handed to the player.
  final String url;

  /// Headers a CDN requires (a referer, a user agent).
  final Map<String, String> headers;

  /// When the address stops working; null keeps it indefinitely.
  final DateTime? expiresAt;

  /// The container, as the player wants it named (`mp4`, `m4s`, `hls`).
  final String format;

  /// The source's own label for the quality, when it named one.
  final String? quality;
}

/// The failure a VOD source reports.
final class VodFailure implements Exception {
  /// A failure with the source's [message].
  const new(this.message, {this.statusCode});

  /// What the source said.
  final String message;

  /// The HTTP status, when the failure came with one.
  final int? statusCode;

  @override
  String toString() => 'VodFailure($message)';
}

/// The result of a search: the hits and whether another page exists.
final class VodSearchPage {
  /// A page of hits.
  const new({required this.videos, this.hasMore = false});

  /// The hits, in the source's order.
  final List<VodVideo> videos;

  /// Whether the source says another page follows.
  final bool hasMore;
}

/// The Bilibili video source: search, the page list that names the first
/// part's cid, and the progressive play address.
///
/// The client speaks only [LiveHttp] and JSON, so the transport (proxies,
/// retries, cookies) stays the app's business. The address it resolves is the
/// progressive mp4 (`fnval=1`): it carries its audio with the picture, which
/// is what a single-surface player needs — the DASH streams would need the
/// audio and the video muxed separately, and that seam does not exist yet.
final class BilibiliVodClient {
  /// A client over [http].
  const new(this.http, {this.userAgent = _defaultUserAgent});

  /// The transport.
  final LiveHttp http;

  /// The browser string the endpoints expect.
  final String userAgent;

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

  /// The headers every Bilibili web endpoint wants.
  Map<String, String> get _headers => {'user-agent': userAgent, 'referer': 'https://www.bilibili.com'};

  /// Searches the site's videos for [keyword]; [page] starts at 1.
  Future<VodSearchPage> search(String keyword, {int page = 1, int pageSize = 20}) async {
    final response = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/web-interface/search/type', {
          'search_type': 'video',
          'keyword': keyword,
          'page': '$page',
          'page_size': '$pageSize',
        }),
        headers: _headers,
      ),
    );
    final json = _body(response);
    final data = json['data'];
    if (data is! Map) {
      return const VodSearchPage(videos: []);
    }
    final results = (data['result'] as List<Object?>?) ?? const [];
    final videos = [
      for (final hit in results)
        if (hit is Map) ?_videoOf(hit),
    ];
    final numResults = (data['numResults'] as num?)?.toInt() ?? videos.length;
    return VodSearchPage(videos: videos, hasMore: page * pageSize < numResults);
  }

  /// Resolves [video]'s first part to a progressive address.
  Future<VodPlayInfo> play(VodVideo video) async {
    final bvid = video.bvid ?? video.id;
    final pages = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/player/pagelist', {'bvid': bvid}),
        headers: _headers,
      ),
    );
    final pageList = _body(pages)['data'];
    if (pageList is! List || pageList.isEmpty) {
      throw const VodFailure('the video has no playable part');
    }
    final first = pageList.first;
    final cid = '${first is Map ? first['cid'] : ''}';
    if (cid.isEmpty) {
      throw const VodFailure('the first part names no cid');
    }
    final play = await http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.https('api.bilibili.com', '/x/player/playurl', {
          'bvid': bvid,
          'cid': cid,
          'qn': '64',
          'fnval': '1',
          'fourk': '1',
        }),
        headers: _headers,
      ),
    );
    final json = _body(play);
    final data = json['data'];
    if (data is! Map) {
      throw const VodFailure('the source returned no play data');
    }
    final durl = data['durl'];
    final firstPart = durl is List && durl.isNotEmpty ? durl.first : null;
    final address = firstPart is Map ? firstPart['url'] : null;
    if (address is String && address.isNotEmpty) {
      return VodPlayInfo(url: address, headers: _headers, quality: '${data['quality'] ?? ''}');
    }
    // A login-gated video (1080p and above) answers only DASH streams.
    final dash = data['dash'];
    if (dash is Map) {
      final videos = (dash['video'] as List<Object?>?) ?? const [];
      final audios = (dash['audio'] as List<Object?>?) ?? const [];
      final first = videos.isEmpty ? null : videos.first;
      final address = first is Map ? first['baseUrl'] : null;
      if (address is String && address.isNotEmpty) {
        // Without a mux seam the picture plays silently: the address is still
        // the best one the source offers, and the page says so.
        return VodPlayInfo(url: address, headers: _headers, format: 'm4s', quality: audios.isEmpty ? 'silent' : 'dash');
      }
    }
    throw const VodFailure('the video offered no address');
  }

  /// The first video a search returns for [keyword], or null.
  Future<VodVideo?> first(String keyword) async {
    final page = await search(keyword, pageSize: 1);
    return page.videos.isEmpty ? null : page.videos.first;
  }

  Map<String, Object?> _body(LiveResponse response) {
    if (response.statusCode != 200) {
      throw VodFailure('HTTP ${response.statusCode}', statusCode: response.statusCode);
    }
    final text = response.text;
    final decoded = _tryDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const VodFailure('the source answered something that is not JSON');
    }
    final code = (decoded['code'] as num?)?.toInt() ?? 0;
    if (code != 0) {
      throw VodFailure('${decoded['message'] ?? 'code $code'}');
    }
    return decoded;
  }

  VodVideo? _videoOf(Map<Object?, Object?> hit) {
    final bvid = '${hit['bvid'] ?? ''}';
    final title = _plain('${hit['title'] ?? ''}');
    if (bvid.isEmpty || title.isEmpty) {
      return null;
    }
    final duration = _durationOf('${hit['duration'] ?? ''}');
    final cover = '${hit['pic'] ?? ''}';
    return VodVideo(
      id: bvid,
      bvid: bvid,
      aid: (hit['aid'] as num?)?.toInt(),
      title: title,
      coverUrl: cover.isEmpty ? null : _https(cover),
      uploader: '${hit['author'] ?? ''}'.isEmpty ? null : '${hit['author']}',
      duration: duration,
      playCount: (hit['play'] as num?)?.toInt(),
    );
  }

  /// Strips the `<em class="keyword">` markup the search highlights with.
  static String _plain(String title) => title.replaceAll(RegExp('<[^>]*>'), '').trim();

  /// The search covers are `//i0.hdslb.com/...`; a player wants a scheme.
  static String _https(String url) => url.startsWith('//') ? 'https:$url' : url;

  /// "12:34" or "1:02:03" as a duration.
  static Duration? _durationOf(String text) {
    final parts = text.split(':');
    if (parts.isEmpty || parts.any((part) => int.tryParse(part) == null)) {
      return null;
    }
    var seconds = 0;
    for (final part in parts) {
      seconds = seconds * 60 + int.parse(part);
    }
    return Duration(seconds: seconds);
  }

  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on Object {
      return null;
    }
  }
}
