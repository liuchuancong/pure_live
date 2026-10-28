// Dart port of hongguoTV's PublicComments (kotlin-tv/core); GPL-3.0-only.
// The website's own public reviews and ratings, read from the pages it serves
// to any browser: no account credential is ever forwarded here, and the
// pages are read as data only.
import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:crypto/crypto.dart' show sha256;
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest;

import 'package:pure_live/modules/hongguo/official/hongguo_official.dart'
    show HongguoOfficialClient, HongguoOfficialFailure;

/// One public review, as either page lists it.
final class HongguoPublicReview {
  /// Creates the review.
  const HongguoPublicReview({
    required this.id,
    required this.author,
    required this.avatar,
    required this.content,
    required this.created,
    required this.likes,
    required this.rating,
  });

  /// The review's stable id, hashed from its own fields.
  final String id;

  /// The reviewer's display name.
  final String author;

  /// The reviewer's avatar, when it is an https address.
  final String avatar;

  /// The review's text.
  final String content;

  /// When it was written, in seconds since the epoch.
  final int created;

  /// How many likes it carries.
  final int likes;

  /// The score the reviewer gave, when the row carries one.
  final double rating;
}

/// One list of public reviews.
final class HongguoPublicReviewPage {
  /// Creates the page.
  const HongguoPublicReviewPage({required this.total, required this.items});

  /// An empty page.
  static const HongguoPublicReviewPage empty = HongguoPublicReviewPage(total: 0, items: []);

  /// The number the platform reports, which can be larger than the list.
  final int total;

  /// The reviews themselves, newest first as the platform lists them.
  final List<HongguoPublicReview> items;
}

/// What the public pages say about one series and one episode.
final class HongguoPublicReviews {
  /// Creates the pair.
  const HongguoPublicReviews({
    required this.series,
    required this.episode,
    required this.rating,
    required this.ratingCount,
  });

  /// The series' reviews (整剧剧评).
  final HongguoPublicReviewPage series;

  /// The episode's comments (本集评论).
  final HongguoPublicReviewPage episode;

  /// The series' average score, 0 when the platform publishes none.
  final double rating;

  /// How many ratings the average is drawn from.
  final int ratingCount;
}

/// Reads the public player and detail pages. Never forwards account
/// credentials; a series' detail page is kept half a minute, as the
/// reference does.
final class HongguoPublicReviewsClient {
  /// Creates the client over [_http].
  HongguoPublicReviewsClient({required this._http});

  final LiveHttp _http;

  /// series id → (read at, loaderData) — sixteen at most, half a minute each.
  final Map<String, (DateTime, Map<String, Object?>)> _details = {};

  static const int _pageLimit = 8 * 1024 * 1024;

  /// Reads the series' and the episode's reviews together.
  Future<HongguoPublicReviews> read(String seriesId, String episodeVid) async {
    final pattern = RegExp(r'^[0-9]{6,30}$');
    if (!pattern.hasMatch(seriesId) || !pattern.hasMatch(episodeVid)) {
      throw const HongguoOfficialFailure('评论编号异常');
    }
    final player = await _page('https://hongguoduanju.com/player/$seriesId/$episodeVid');
    final playerData = _payload(player, '公开评论');
    if (_str(playerData, 'vid') != episodeVid) {
      throw const HongguoOfficialFailure('评论分集不匹配');
    }
    final detailData = await _detailData(seriesId);
    final detailRaw = detailData['seriesDetail'];
    if (detailRaw is! Map<String, Object?> || _str(detailRaw, 'series_id') != seriesId) {
      throw const HongguoOfficialFailure('剧评剧集不匹配');
    }
    final social = _map(detailData['seriesSocialInfo']);
    final episodeSocial = _map(playerData['episodeSocialInfo']);
    return HongguoPublicReviews(
      series: _list(_map(social?['reviews']), seriesId, episodeVid, 'series'),
      episode: _list(_map(episodeSocial?['reviews']), seriesId, episodeVid, 'episode'),
      rating: _finite(social?['rating']),
      ratingCount: _count(social?['rating_count']),
    );
  }

  Future<Map<String, Object?>> _detailData(String seriesId) async {
    final cached = _details[seriesId];
    if (cached != null && DateTime.now().difference(cached.$1) < const Duration(seconds: 30)) {
      return cached.$2;
    }
    final html = await _page('https://hongguoduanju.com/detail?series_id=$seriesId');
    final data = _payload(html, '公开剧评');
    _details[seriesId] = (DateTime.now(), data);
    while (_details.length > 16) {
      _details.remove(_details.keys.first);
    }
    return data;
  }

  Future<String> _page(String url) async {
    final response = await _http.send(
      LiveRequest.custom(
        method: 'GET',
        url: Uri.parse(url),
        headers: const {'User-Agent': 'Mozilla/5.0', 'Accept': 'text/html'},
        timeout: const Duration(seconds: 20),
      ),
    );
    if (!response.isOk) {
      throw HongguoOfficialFailure('公开评论读取失败（HTTP ${response.statusCode}）');
    }
    final bytes = Uint8List.fromList(response.bodyBytes);
    if (bytes.length > _pageLimit) {
      throw const HongguoOfficialFailure('公开评论页面过大');
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// The loaderData record carrying `seriesDetail`, checked as successful.
  static Map<String, Object?> _payload(String html, String what) {
    final loader = HongguoOfficialClient.extractRouter(html)['loaderData'];
    if (loader is! Map<String, Object?>) {
      throw HongguoOfficialFailure('$what格式已变化');
    }
    for (final value in loader.values) {
      if (value is Map<String, Object?> && value.containsKey('seriesDetail') && value['isSuccess'] != false) {
        return value;
      }
    }
    throw HongguoOfficialFailure('$what格式已变化');
  }

  /// One `reviews` block: at most fifty, deduplicated by their own fields.
  static HongguoPublicReviewPage _list(Map<String, Object?>? block, String seriesId, String episodeVid, String kind) {
    final rows = block?['reviews'];
    final items = <HongguoPublicReview>[];
    final seen = <String>{};
    for (final raw in rows is List<Object?> ? rows.take(100) : const <Object?>[]) {
      if (raw is! Map<String, Object?>) continue;
      final text = _str(raw, 'content');
      if (text.isEmpty) continue;
      final author = _str(raw, 'user_name');
      final created = _count(raw['create_time']);
      final digest = sha256
          .convert(utf8.encode('$seriesId\u0000$episodeVid\u0000$kind\u0000$author\u0000$created\u0000$text'))
          .toString();
      if (!seen.add(digest)) continue;
      final avatar = _str(raw, 'user_avatar');
      items.add(
        HongguoPublicReview(
          id: digest,
          author: author,
          avatar: avatar.startsWith('https://') ? avatar : '',
          content: text,
          created: created,
          likes: _count(raw['digg_count']),
          rating: _finite(raw['rating']),
        ),
      );
      if (items.length >= 50) break;
    }
    return HongguoPublicReviewPage(total: _count(block?['total_count']), items: items);
  }

  static Map<String, Object?>? _map(Object? value) => value is Map<String, Object?> ? value : null;

  static String _str(Map<String, Object?> json, String key) {
    final value = json[key];
    return value is String
        ? value.trim()
        : value == null
        ? ''
        : '$value';
  }

  static int _count(Object? value) {
    final number = value is num ? value.toInt() : int.tryParse('$value');
    return number == null || number < 0 ? 0 : number;
  }

  static double _finite(Object? value) {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return number == null || !number.isFinite ? 0 : number;
  }
}
