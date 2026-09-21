import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'rumble_link.dart';

enum RumbleFailure { transport, access, missing, rateLimited, service, schema, identity, cancelled, mediaUnavailable }

final class RumbleException implements Exception {
  const RumbleException(this.kind);

  final RumbleFailure kind;

  @override
  String toString() => 'Rumble ${kind.name}';
}

enum RumbleState { live, offline }

final class RumbleQuality {
  const RumbleQuality({required this.id, required this.label, required this.sort, required this.url});

  final String id;
  final String label;
  final int sort;
  final Uri url;
}

final class RumbleRoom {
  RumbleRoom({
    required this.videoKey,
    required this.channel,
    required this.channelName,
    required this.title,
    required this.description,
    required this.cover,
    required this.avatar,
    required this.category,
    required this.followers,
    required this.currentViewers,
    required this.totalViews,
    required this.state,
    required this.embedId,
    required Iterable<RumbleQuality> qualities,
  }) : qualities = List.unmodifiable(qualities);

  final String videoKey;
  final String channel;
  final String channelName;
  final String title;
  final String description;
  final String cover;
  final String avatar;
  final String category;
  final int? followers;
  final int? currentViewers;
  final int? totalViews;
  final RumbleState state;
  final String embedId;
  final List<RumbleQuality> qualities;
}

final class RumblePage {
  RumblePage({required Iterable<RumbleRoom> items, required this.hasMore}) : items = List.unmodifiable(items);

  final List<RumbleRoom> items;
  final bool hasMore;
}

typedef RumbleRequest = Future<({int status, String body})> Function(
  Uri uri,
  Map<String, String> headers,
  CancelToken cancel,
);

final class RumbleApi {
  RumbleApi({RumbleRequest? request, this.deadline = const Duration(seconds: 25)})
    : _request = request ?? _defaultRequest;

  static const String origin = 'https://rumble.com';
  static const int responseLimit = 4 * 1024 * 1024;
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
  static const Map<String, String> headers = {
    'User-Agent': userAgent,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': '$origin/',
  };

  static Map<String, String> mediaHeaders(String videoKey) => {
    'User-Agent': userAgent,
    'Origin': origin,
    'Referer': RumbleLink.videoUrl(videoKey),
  };

  final RumbleRequest _request;
  final Duration deadline;

  static Future<({int status, String body})> _defaultRequest(
    Uri uri,
    Map<String, String> requestHeaders,
    CancelToken cancel,
  ) async {
    final response = await HttpClient.instance.dio.get<ResponseBody>(
      uri.toString(),
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: requestHeaders,
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const RumbleException(RumbleFailure.schema);
    return (status: response.statusCode ?? 0, body: await _readBody(body.stream));
  }

  static Future<String> _readBody(Stream<List<int>> source) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        if (bytes.length + iterator.current.length > responseLimit) {
          throw const RumbleException(RumbleFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const RumbleException(RumbleFailure.schema);
    } finally {
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const RumbleException(RumbleFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const RumbleException(RumbleFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const RumbleException(RumbleFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true || transport.isCancelled) {
            throw const RumbleException(RumbleFailure.cancelled);
          }
          if (error is RumbleException) rethrow;
          throw const RumbleException(RumbleFailure.transport);
        }
      });

  Future<String> _get(Uri uri, CancelToken token) async {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || !_isRumbleHost(uri.host)) {
      throw const RumbleException(RumbleFailure.identity);
    }
    final response = await _request(uri, headers, token);
    _throwStatus(response.status);
    if (response.body.length > responseLimit) throw const RumbleException(RumbleFailure.schema);
    return response.body;
  }

  Future<RumblePage> directory({int page = 1, CancelToken? cancel}) => _scope(cancel, (token) async {
    if (page < 1 || page > 10000) throw const RumbleException(RumbleFailure.schema);
    final uri = Uri.parse('$origin/browse/live').replace(queryParameters: page == 1 ? null : {'page': '$page'});
    return parseDirectoryHtml(await _get(uri, token), page: page);
  });

  Future<RumbleRoom> room(String rawVideoKey, {CancelToken? cancel}) => _scope(cancel, (token) async {
    final videoKey = RumbleLink.parseVideoKey(rawVideoKey);
    if (videoKey == null) throw const RumbleException(RumbleFailure.identity);
    return parseRoomHtml(await _get(Uri.parse(RumbleLink.videoUrl(videoKey)), token), expectedVideoKey: videoKey);
  });

  static RumblePage parseDirectoryHtml(String source, {required int page}) {
    if (source.length > responseLimit || page < 1) throw const RumbleException(RumbleFailure.schema);
    final document = html_parser.parse(source);
    final seen = <String>{};
    final rooms = <RumbleRoom>[];
    for (final card in document.querySelectorAll('.videostream.thumbnail__grid-item')) {
      final link = card.querySelector('a.videostream__link')?.attributes['href'] ?? '';
      final videoKey = RumbleLink.parseVideoKey(_absolute(link));
      if (videoKey == null || !seen.add(videoKey)) continue;
      final channelLink = card.querySelector('a.channel__link')?.attributes['href'] ?? '';
      final channel = RumbleLink.parseChannel(_absolute(channelLink)) ?? '';
      final channelName = _elementText(card.querySelector('.channel__name'));
      final title = _firstText([
        card.querySelector('.thumbnail__title')?.attributes['title'],
        card.querySelector('.thumbnail__image')?.attributes['alt'],
        card.querySelector('.thumbnail__title')?.text,
        channelName,
      ]);
      final cover = _image(card.querySelector('.thumbnail__image')?.attributes['src']);
      final avatar = _image(card.querySelector('.channel__image')?.attributes['src']);
      final currentViewers = parseAudience(_elementText(card.querySelector('.videostream__number')));
      final totalViews = _nonNegativeInt(card.querySelector('.videostream__views')?.attributes['data-views']);
      rooms.add(
        RumbleRoom(
          videoKey: videoKey,
          channel: channel,
          channelName: channelName.isEmpty ? channel : channelName,
          title: title,
          description: '',
          cover: cover,
          avatar: avatar.isEmpty ? cover : avatar,
          category: '',
          followers: null,
          currentViewers: currentViewers,
          totalViews: totalViews,
          state: RumbleState.live,
          embedId: '',
          qualities: const [],
        ),
      );
    }
    final next = document.querySelector('link[rel="next"]')?.attributes['href'];
    final hasMore = next != null && _isNextPage(next, page + 1) && rooms.isNotEmpty;
    return RumblePage(items: rooms, hasMore: hasMore);
  }

  static RumbleRoom parseRoomHtml(String source, {required String expectedVideoKey}) {
    final videoKey = RumbleLink.requireVideoKey(expectedVideoKey);
    if (source.length > responseLimit) throw const RumbleException(RumbleFailure.schema);
    final document = html_parser.parse(source);
    final video = _videoObject(document);
    final canonicalKey = RumbleLink.parseVideoKey(_text(video['url']));
    if (canonicalKey != videoKey) throw const RumbleException(RumbleFailure.identity);
    final embedUrl = Uri.tryParse(_optionalText(video['embedUrl']));
    final embedId = embedUrl == null ? '' : _embedId(embedUrl);
    final author = document.querySelector('a.media-by--a[rel="author"], a[rel="author"]');
    final channel = RumbleLink.parseChannel(_absolute(author?.attributes['href'] ?? '')) ?? '';
    final channelName = _firstText([
      document.querySelector('.media-heading-name')?.text,
      author?.attributes['title'],
      channel,
    ]);
    final coverValue = video['thumbnailUrl'];
    final cover = _image(coverValue is List && coverValue.isNotEmpty ? coverValue.first : coverValue);
    final liveText = _elementText(document.querySelector('.media-description-info-stream-time')).toLowerCase();
    final state = liveText.contains('streaming now') || liveText.contains('live now')
        ? RumbleState.live
        : RumbleState.offline;
    return RumbleRoom(
      videoKey: videoKey,
      channel: channel,
      channelName: channelName,
      title: _firstText([video['name'], document.querySelector('h1.h1')?.text, channelName]),
      description: _optionalText(video['description']),
      cover: cover,
      avatar: cover,
      category: _elementText(document.querySelector('.video-category-tag-primary')),
      followers: parseAudience(_elementText(document.querySelector('.media-heading-num-followers'))),
      currentViewers: null,
      totalViews: _interactionCount(video['interactionStatistic']),
      state: state,
      embedId: embedId,
      qualities: const [],
    );
  }

  static int? parseAudience(String raw) {
    final normalized = raw
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+(VIEWERS?|WATCHING|FOLLOWERS?)$'), '')
        .replaceAll(',', '');
    final match = RegExp(r'^(\d+(?:\.\d+)?)\s*([KMB])?$').firstMatch(normalized);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null || !value.isFinite || value < 0) return null;
    final multiplier = switch (match.group(2)) {
      'K' => 1000,
      'M' => 1000000,
      'B' => 1000000000,
      _ => 1,
    };
    final result = (value * multiplier).round();
    return result <= 0x7fffffff ? result : null;
  }

  static Map<String, dynamic> _videoObject(Document document) {
    for (final script in document.querySelectorAll('script[type="application/ld+json"]')) {
      final raw = script.text.trim();
      if (raw.isEmpty || raw.length > 1024 * 1024) continue;
      try {
        final value = jsonDecode(raw);
        final items = value is List ? value : [value];
        for (final item in items) {
          if (item is Map && item['@type'] == 'VideoObject') {
            return item.map((key, value) => MapEntry(key.toString(), value));
          }
        }
      } on FormatException {
        continue;
      }
    }
    throw const RumbleException(RumbleFailure.schema);
  }

  static int? _interactionCount(Object? value) {
    final values = value is List ? value : [value];
    for (final item in values) {
      if (item is! Map) continue;
      final count = _nonNegativeInt(item['userInteractionCount']);
      if (count != null) return count;
    }
    return null;
  }

  static String _embedId(Uri uri) {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || !_isRumbleHost(uri.host)) return '';
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
    if (segments.length != 2 || segments.first.toLowerCase() != 'embed') return '';
    return RegExp(r'^v[0-9a-z]+$', caseSensitive: false).hasMatch(segments[1]) ? segments[1].toLowerCase() : '';
  }

  static bool _isNextPage(String raw, int expected) {
    final uri = Uri.tryParse(_absolute(raw));
    if (uri == null || uri.scheme != 'https' || !_isRumbleHost(uri.host) || uri.path != '/browse/live') return false;
    return int.tryParse(uri.queryParameters['page'] ?? '') == expected;
  }

  static String _absolute(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    try {
      return Uri.parse(origin).resolve(value).toString();
    } on FormatException {
      return '';
    }
  }

  static String _elementText(Element? element) => element?.text.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';

  static String _text(Object? value) {
    final result = _optionalText(value);
    if (result.isEmpty) throw const RumbleException(RumbleFailure.schema);
    return result;
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final result = _optionalText(value);
      if (result.isNotEmpty) return result;
    }
    throw const RumbleException(RumbleFailure.schema);
  }

  static String _optionalText(Object? value) {
    if (value == null) return '';
    if (value is! String) throw const RumbleException(RumbleFailure.schema);
    final result = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (result.length > 65536) throw const RumbleException(RumbleFailure.schema);
    return result;
  }

  static String _image(Object? value) {
    final raw = _optionalText(value);
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) return '';
    final host = uri.host.toLowerCase();
    if (!_isRumbleHost(host) &&
        host != 'rumble.cloud' &&
        !host.endsWith('.rumble.cloud') &&
        host != 'rmbl.ws' &&
        !host.endsWith('.rmbl.ws')) {
      return '';
    }
    return uri.toString();
  }

  static int? _nonNegativeInt(Object? value) {
    final result = switch (value) {
      int number => number,
      num number when number.isFinite => number.toInt(),
      String text => int.tryParse(text.trim().replaceAll(',', '')),
      _ => null,
    };
    return result != null && result >= 0 && result <= 0x7fffffff ? result : null;
  }

  static bool _isRumbleHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'rumble.com' || normalized == 'www.rumble.com';
  }

  static void _throwStatus(int status) {
    final failure = switch (status) {
      200 => null,
      400 || 422 => RumbleFailure.schema,
      401 || 403 => RumbleFailure.access,
      404 => RumbleFailure.missing,
      429 => RumbleFailure.rateLimited,
      >= 500 => RumbleFailure.service,
      _ => RumbleFailure.transport,
    };
    if (failure != null) throw RumbleException(failure);
  }
}
