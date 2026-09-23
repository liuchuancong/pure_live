import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';
import 'package:pure_live/model/live_play_quality.dart';

enum TwitcastingFailure { transport, access, rateLimited, service, notFound, schema, cancelled, qualityUnavailable }

class TwitcastingException implements Exception {
  const TwitcastingException(this.kind);
  final TwitcastingFailure kind;
  @override
  String toString() => 'TwitCasting ${kind.name}';
}

typedef TwitcastingRequest = Future<({int status, String body})> Function(Uri uri, CancelToken? cancel);

/// Public website contracts, without account cookies, private-room passwords,
/// shared playback state or an external desktop downloader dependency.
class TwitcastingApi {
  TwitcastingApi({TwitcastingRequest? request}) : _request = request ?? _defaultRequest;
  static const origin = 'https://twitcasting.tv';
  static const directoryOrigin = 'https://frontendapi.twitcasting.tv';
  static const directoryWindow = 60;
  static const searchWindow = 50;
  static const responseLimit = 1024 * 1024;
  static const playHeaders = <String, String>{'Referer': '$origin/', 'Origin': origin, 'User-Agent': 'Mozilla/5.0'};
  final TwitcastingRequest _request;

  static Future<({int status, String body})> _defaultRequest(Uri uri, CancelToken? cancel) =>
      withRequestCancellation(cancel, (transport) async {
        final response = await HttpClient.instance.dio.get<ResponseBody>(
          uri.toString(),
          options: Options(responseType: ResponseType.stream, headers: playHeaders, validateStatus: (_) => true),
          cancelToken: transport,
        );
        final body = response.data;
        if (body == null) throw const TwitcastingException(TwitcastingFailure.schema);
        if (response.statusCode != 200) {
          await body.stream.listen((_) {}).cancel();
          return (status: response.statusCode ?? 0, body: '');
        }
        return (status: 200, body: await readBody(body.stream));
      });

  /// Total deadline, not an inactivity timeout restarted by each chunk.
  static Future<String> readBody(Stream<List<int>> stream, {Duration timeout = const Duration(seconds: 20)}) async {
    final iterator = StreamIterator(stream);
    final bytes = BytesBuilder(copy: false);
    final watch = Stopwatch()..start();
    try {
      while (true) {
        final remaining = timeout - watch.elapsed;
        if (remaining <= Duration.zero) throw TimeoutException('TwitCasting response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > responseLimit) throw const TwitcastingException(TwitcastingFailure.schema);
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const TwitcastingException(TwitcastingFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<String> read(Uri uri, {CancelToken? cancel}) async {
    if (cancel?.isCancelled == true) throw const TwitcastingException(TwitcastingFailure.cancelled);
    late final ({int status, String body}) response;
    try {
      response = await _request(uri, cancel);
    } catch (error) {
      if (cancel?.isCancelled == true) throw const TwitcastingException(TwitcastingFailure.cancelled);
      if (error is TwitcastingException) rethrow;
      throw const TwitcastingException(TwitcastingFailure.transport);
    }
    if (cancel?.isCancelled == true) throw const TwitcastingException(TwitcastingFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      401 || 403 => TwitcastingFailure.access,
      404 => TwitcastingFailure.notFound,
      429 => TwitcastingFailure.rateLimited,
      >= 500 => TwitcastingFailure.service,
      _ => TwitcastingFailure.transport,
    };
    if (failure != null) throw TwitcastingException(failure);
    if (response.body.length > responseLimit || utf8.encode(response.body).length > responseLimit) {
      throw const TwitcastingException(TwitcastingFailure.schema);
    }
    return response.body;
  }

  static Map<String, dynamic> object(Object? raw) {
    if (raw is String) {
      if (raw.length > responseLimit || utf8.encode(raw).length > responseLimit) {
        throw const TwitcastingException(TwitcastingFailure.schema);
      }
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        throw const TwitcastingException(TwitcastingFailure.schema);
      }
    }
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const TwitcastingException(TwitcastingFailure.schema);
    }
    return Map<String, dynamic>.from(raw);
  }

  static String text(Object? raw) => raw is String ? raw.trim() : '';
  static int? integer(Object? raw) => raw is int ? raw : (raw is String ? int.tryParse(raw) : null);
  static String picture(Object? raw) {
    var value = text(raw);
    if (value.startsWith('//')) value = 'https:$value';
    final uri = Uri.tryParse(value);
    return uri != null && {'http', 'https'}.contains(uri.scheme) && uri.host.isNotEmpty && uri.userInfo.isEmpty
        ? value
        : '';
  }

  static String channelName(String value) {
    final name = value.trim().toLowerCase();
    if (!RegExp(r'^(?:(?:c|g|f|ig):)?[a-z0-9_]{1,64}$').hasMatch(name) ||
        const {
          'search',
          'help',
          'login',
          'logout',
          'settings',
          'signup',
          'register',
          'terms',
          'privacy',
          'about',
          'index',
          'show',
          'categories',
        }.contains(name)) {
      throw const TwitcastingException(TwitcastingFailure.schema);
    }
    return name;
  }

  static String? channelFromUri(Uri uri) {
    if (!{'http', 'https'}.contains(uri.scheme) ||
        !{'twitcasting.tv', 'www.twitcasting.tv'}.contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      return null;
    }
    try {
      final parts = uri.pathSegments.toList();
      if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
      // Movie/archive links may identify an old broadcast, not this channel's
      // current live session. Do not silently substitute the latest broadcast.
      return parts.length == 1 ? channelName(parts.single) : null;
    } on FormatException {
      return null;
    } on TwitcastingException {
      return null;
    }
  }

  Future<List<LiveArea>> categories({CancelToken? cancel}) async {
    final document = html.parse(await read(Uri.parse('$origin/'), cancel: cancel));
    final result = <String, LiveArea>{};
    for (final element in document.querySelectorAll('a.tw-top-tab-item[data-channel]')) {
      final key = element.attributes['data-channel'] ?? '';
      if (!RegExp(r'^[a-zA-Z0-9_]{1,80}$').hasMatch(key) || element.text.trim().isEmpty) {
        throw const TwitcastingException(TwitcastingFailure.schema);
      }
      result.putIfAbsent(
        key,
        () => LiveArea(
          platform: 'twitcasting',
          areaId: key,
          areaType: 'directory',
          areaName: element.text.trim(),
          typeName: 'TwitCasting',
        ),
      );
    }
    if (result.isEmpty || result.length > 100) throw const TwitcastingException(TwitcastingFailure.schema);
    return List.unmodifiable(result.values);
  }

  Future<List<LiveRoom>> directory({int page = 1, int pageSize = 30, String category = '', CancelToken? cancel}) async {
    if (page < 1 ||
        page > 10000 ||
        pageSize < 1 ||
        pageSize > directoryWindow ||
        (category.isNotEmpty && !RegExp(r'^[a-zA-Z0-9_]{1,80}$').hasMatch(category))) {
      throw const TwitcastingException(TwitcastingFailure.schema);
    }
    final offset = (page - 1) * pageSize;
    // The website refreshes a bounded top window, not an offset/cursor API.
    // Expose that actual window in UI-sized pages; never invent another page.
    if (offset >= directoryWindow) return const [];
    final uri = Uri.parse('$directoryOrigin/top/category')
        .replace(queryParameters: {'id': category, 'count': '$directoryWindow'});
    final data = object(await read(uri, cancel: cancel));
    final rows = data['movies'];
    if (rows is! List || rows.length > directoryWindow) throw const TwitcastingException(TwitcastingFailure.schema);
    final rooms = <String, LiveRoom>{};
    for (final raw in rows.skip(offset).take(pageSize)) {
      final row = object(raw);
      for (final flag in ['is_live', 'is_locked', 'is_group', 'is_deleted']) {
        if (row[flag] is! bool) throw const TwitcastingException(TwitcastingFailure.schema);
      }
      if (row['is_live'] != true ||
          row['is_locked'] != false ||
          row['is_group'] != false ||
          row['is_deleted'] != false) {
        continue;
      }
      final channel = channelName(text(row['user_id']));
      final movie = integer(row['id']);
      final link = Uri.tryParse(text(row['live_url']));
      if (movie == null ||
          movie <= 0 ||
          link == null ||
          link.hasAuthority ||
          link.hasQuery ||
          link.hasFragment ||
          link.pathSegments.join('/') != '$channel/movie/$movie') {
        throw const TwitcastingException(TwitcastingFailure.schema);
      }
      final count = integer(row['current_viewer_count']);
      if (count == null || count < 0) throw const TwitcastingException(TwitcastingFailure.schema);
      rooms.putIfAbsent(
        channel,
        () => LiveRoom(
          platform: 'twitcasting',
          roomId: channel,
          userId: channel,
          title: text(row['telop']).isNotEmpty ? text(row['telop']) : text(row['title']),
          nick: text(row['user_name']),
          cover: picture(row['thumbnail_url']),
          avatar: picture(row['user_icon_url']),
          link: '$origin/$channel',
          watching: '$count',
          onlineViewers: '$count',
          audienceMetricType: AudienceMetricType.onlineViewers,
          status: true,
          liveStatus: LiveStatus.live,
        ),
      );
    }
    return List.unmodifiable(rooms.values);
  }

  /// The public text-search page exposes up to 50 live matches in one HTML
  /// window. User/recording/premier sections are distinct from current lives.
  Future<List<LiveRoom>> searchLives(String keyword, {int page = 1, int pageSize = 20, CancelToken? cancel}) async {
    final query = keyword.trim();
    if (page < 1 || page > 10000 || pageSize < 1 || pageSize > searchWindow || query.length > 100) {
      throw const TwitcastingException(TwitcastingFailure.schema);
    }
    if (query.isEmpty || (page - 1) * pageSize >= searchWindow) return const [];
    final uri = Uri(
      scheme: 'https',
      host: 'search.twitcasting.tv',
      pathSegments: ['search', 'text', query],
      queryParameters: {'hl': 'en'},
    );
    final document = html.parse(await read(uri, cancel: cancel));
    final section = document.querySelector('#tw-search-result-live');
    if (section == null) throw const TwitcastingException(TwitcastingFailure.schema);
    final rows = section.querySelectorAll('.tw-search-result-row');
    if (rows.length > searchWindow) throw const TwitcastingException(TwitcastingFailure.schema);
    final rooms = <String, LiveRoom>{};
    for (final row in rows.skip((page - 1) * pageSize).take(pageSize)) {
      final movieHref = row.querySelector('a.tw-movie-thumbnail2')?.attributes['href'] ?? '';
      final channelHref = row.querySelector('.tw-search-result-row-user-name .usertext a')?.attributes['href'] ?? '';
      final movieUri = Uri.tryParse(movieHref);
      final channelUri = Uri.tryParse(channelHref);
      if (movieUri == null ||
          channelUri == null ||
          movieUri.hasAuthority ||
          channelUri.hasAuthority ||
          movieUri.hasQuery ||
          movieUri.hasFragment ||
          channelUri.hasQuery ||
          channelUri.hasFragment ||
          channelUri.pathSegments.length != 1 ||
          movieUri.pathSegments.length != 3 ||
          row.querySelector('.tw-movie-thumbnail2-badge[data-status="live"]') == null ||
          row.querySelector('.tw-movie-thumbnail2-image-wrapper[data-can-play="true"]') == null) {
        throw const TwitcastingException(TwitcastingFailure.schema);
      }
      final channel = channelName(channelUri.pathSegments.single);
      final movie = integer(movieUri.pathSegments.last);
      if (movieUri.pathSegments[0].toLowerCase() != channel ||
          movieUri.pathSegments[1] != 'movie' ||
          movie == null ||
          movie <= 0) {
        throw const TwitcastingException(TwitcastingFailure.schema);
      }
      rooms.putIfAbsent(
        channel,
        () => LiveRoom(
          platform: 'twitcasting',
          roomId: channel,
          userId: channel,
          link: '$origin/$channel',
          title: row.querySelector('.tw-movie-thumbnail-title')?.text.trim() ?? '',
          nick: row.querySelector('.tw-search-result-row-user-name .username')?.text.trim() ?? channel,
          cover: picture(row.querySelector('.tw-movie-thumbnail2-image')?.attributes['src']),
          avatar: picture(row.querySelector('.userimage32 img')?.attributes['src']),
          watching: '',
          audienceMetricType: AudienceMetricType.unknown,
          status: true,
          liveStatus: LiveStatus.live,
        ),
      );
    }
    return List.unmodifiable(rooms.values);
  }

  Future<LiveRoom> detail(String input, {CancelToken? cancel}) async {
    final channel = channelName(input);
    final page = await read(Uri.parse('$origin/$channel'), cancel: cancel);
    if (page.contains('Enter the secret word to access')) throw const TwitcastingException(TwitcastingFailure.access);
    final document = html.parse(page);
    final creators = document.querySelectorAll('meta[name="twitter:creator"]');
    if (creators.length != 1 || channelName(creators.single.attributes['content'] ?? '') != channel) {
      throw const TwitcastingException(TwitcastingFailure.schema);
    }
    final header = document.querySelector('.tw-user-header');
    if (header == null || channelName(header.attributes['data-user-id'] ?? '') != channel) {
      throw const TwitcastingException(TwitcastingFailure.schema);
    }
    final stream = object(
      await read(
        Uri.parse('$origin/streamserver.php')
            .replace(queryParameters: {'target': channel, 'mode': 'client', 'player': 'pc_web'}),
        cancel: cancel,
      ),
    );
    final movie = object(stream['movie']);
    if (movie['live'] is! bool) throw const TwitcastingException(TwitcastingFailure.schema);
    final live = movie['live'] == true;
    final room = LiveRoom(
      platform: 'twitcasting',
      roomId: channel,
      userId: channel,
      link: '$origin/$channel',
      title: document.querySelector('meta[name="twitter:title"]')?.attributes['content'] ?? '',
      nick: document.querySelector('.tw-user-nav2-name')?.text.trim() ?? channel,
      avatar: picture(document.querySelector('.tw-user-nav2-icon img')?.attributes['src']),
      cover: picture(document.querySelector('meta[property="og:image"]')?.attributes['content']),
      watching: '',
      status: live,
      liveStatus: live ? LiveStatus.live : LiveStatus.offline,
    );
    // Observed offline responses contain stale HLS URLs for a DIFFERENT movie.
    // Only movie.live is authoritative; ignore every URL when it is false.
    if (!live) {
      room.data = const <LivePlayQuality>[];
      return room;
    }
    final movieId = integer(movie['id']);
    if (movieId == null || movieId <= 0) throw const TwitcastingException(TwitcastingFailure.schema);
    final streams = object(object(stream['tc-hls'])['streams']);
    final qualities = <LivePlayQuality>[];
    for (final key in ['high', 'medium', 'low']) {
      if (!streams.containsKey(key)) continue;
      final url = text(streams[key]);
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment ||
          (uri.hasPort && uri.port != 443) ||
          !(uri.host == 'twitcasting.tv' || uri.host.endsWith('.twitcasting.tv')) ||
          !RegExp('^/tc[.]livehls/v1/streams/$movieId/hls/[0-9]+[.][0-9]+/media[.]m3u8\$').hasMatch(uri.path)) {
        throw const TwitcastingException(TwitcastingFailure.schema);
      }
      qualities.add(
        LivePlayQuality(
          id: key,
          quality: 'HLS $key',
          sort: 3 - qualities.length,
          data: List<String>.unmodifiable([url]),
        ),
      );
    }
    if (qualities.isEmpty) throw const TwitcastingException(TwitcastingFailure.schema);
    room.data = List<LivePlayQuality>.unmodifiable(qualities);
    return room;
  }
}
