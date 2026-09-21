import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'steam_broadcast_link.dart';

enum SteamBroadcastFailure {
  transport,
  access,
  missing,
  rateLimited,
  service,
  schema,
  identity,
  cancelled,
  mediaUnavailable,
}

final class SteamBroadcastException implements Exception {
  const SteamBroadcastException(this.kind);

  final SteamBroadcastFailure kind;

  @override
  String toString() => 'Steam Broadcast ${kind.name}';
}

enum SteamBroadcastState { live, offline, restricted, unknown }

final class SteamBroadcastRoom {
  const SteamBroadcastRoom({
    required this.steamId,
    required this.broadcaster,
    required this.title,
    required this.game,
    required this.cover,
    required this.avatar,
    required this.currentViewers,
    required this.state,
    required this.master,
  });

  final String steamId;
  final String broadcaster;
  final String title;
  final String game;
  final String cover;
  final String avatar;
  final int? currentViewers;
  final SteamBroadcastState state;
  final Uri? master;

  SteamBroadcastRoom enrich(SteamBroadcastRoom known) => SteamBroadcastRoom(
    steamId: steamId,
    broadcaster: broadcaster == steamId || broadcaster == 'Steam broadcaster' ? known.broadcaster : broadcaster,
    title: title == 'Steam Broadcast' ? known.title : title,
    game: game.isEmpty ? known.game : game,
    cover: cover.isEmpty ? known.cover : cover,
    avatar: avatar.isEmpty ? known.avatar : avatar,
    currentViewers: currentViewers ?? known.currentViewers,
    state: state,
    master: master,
  );
}

final class SteamBroadcastPage {
  SteamBroadcastPage({required Iterable<SteamBroadcastRoom> rooms, required this.hasMore})
    : rooms = List.unmodifiable(rooms);

  final List<SteamBroadcastRoom> rooms;
  final bool hasMore;
}

typedef SteamBroadcastRequest = Future<({int status, String body})> Function(
  Uri uri,
  Map<String, String> headers,
  CancelToken cancel,
);

class SteamBroadcastApi {
  SteamBroadcastApi({SteamBroadcastRequest? request, this.deadline = const Duration(seconds: 25)})
    : _request = request ?? _defaultRequest;

  static const String origin = 'https://steamcommunity.com';
  static const int responseLimit = 4 * 1024 * 1024;
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
  static const Map<String, String> directoryHeaders = {
    'User-Agent': userAgent,
    'Accept': 'text/html, */*; q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': '$origin/?subsection=broadcasts',
    'X-Requested-With': 'XMLHttpRequest',
  };

  static Map<String, String> roomHeaders(String steamId, {bool json = false}) => {
    'User-Agent': userAgent,
    'Accept': json ? 'application/json, text/javascript, */*; q=0.8' : 'text/html,application/xhtml+xml,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': SteamBroadcastLink.watchUrl(steamId),
    if (json) 'X-Requested-With': 'XMLHttpRequest',
  };

  static Map<String, String> mediaHeaders(String steamId) => {
    'User-Agent': userAgent,
    'Origin': origin,
    'Referer': SteamBroadcastLink.watchUrl(steamId),
  };

  final SteamBroadcastRequest _request;
  final Duration deadline;

  static Future<({int status, String body})> _defaultRequest(
    Uri uri,
    Map<String, String> headers,
    CancelToken cancel,
  ) async {
    final response = await HttpClient.instance.dio.get<ResponseBody>(
      uri.toString(),
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: headers,
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    return (status: response.statusCode ?? 0, body: await _readBody(body.stream));
  }

  static Future<String> _readBody(Stream<List<int>> source) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        if (bytes.length + iterator.current.length > responseLimit) {
          throw const SteamBroadcastException(SteamBroadcastFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    } finally {
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const SteamBroadcastException(SteamBroadcastFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const SteamBroadcastException(SteamBroadcastFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const SteamBroadcastException(SteamBroadcastFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true || transport.isCancelled) {
            throw const SteamBroadcastException(SteamBroadcastFailure.cancelled);
          }
          if (error is SteamBroadcastException) rethrow;
          throw const SteamBroadcastException(SteamBroadcastFailure.transport);
        }
      });

  Future<String> _get(Uri uri, Map<String, String> headers, CancelToken cancel) async {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) {
      throw const SteamBroadcastException(SteamBroadcastFailure.identity);
    }
    final response = await _request(uri, headers, cancel);
    _throwStatus(response.status);
    if (response.body.length > responseLimit) throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    return response.body;
  }

  Future<SteamBroadcastPage> directory({int page = 1, CancelToken? cancel}) => _scope(cancel, (token) async {
    if (page < 1 || page > 10000) throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    final uri = Uri.parse('$origin/apps/allcontenthome').replace(
      queryParameters: {
        'l': 'english',
        'browsefilter': 'trend',
        'appHubSubSection': '13',
        'forceanon': '1',
        'p': '$page',
        'broadcastsoffset': '${(page - 1) * 10}',
        'numperpage': '10',
      },
    );
    return parseDirectoryHtml(await _get(uri, directoryHeaders, token), page: page);
  });

  Future<SteamBroadcastRoom> room(String rawSteamId, {bool includeMedia = false, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        final steamId = SteamBroadcastLink.parseSteamId(rawSteamId);
        if (steamId == null) throw const SteamBroadcastException(SteamBroadcastFailure.identity);
        final watch = await _get(Uri.parse(SteamBroadcastLink.watchUrl(steamId)), roomHeaders(steamId), token);
        final metadata = parseWatchHtml(watch, expectedSteamId: steamId);
        final endpoint = Uri.parse('$origin/broadcast/getbroadcastmpd/')
            .replace(queryParameters: {'broadcastid': '0', 'steamid': steamId, 'viewertoken': '0', 'sessionid': ''});
        late final SteamBroadcastRoom room;
        try {
          room = parseBroadcastJson(
            jsonDecode(await _get(endpoint, roomHeaders(steamId, json: true), token)),
            steamId: steamId,
            broadcaster: metadata.broadcaster,
          );
        } on FormatException {
          throw const SteamBroadcastException(SteamBroadcastFailure.schema);
        }
        if (includeMedia && room.state == SteamBroadcastState.live) {
          final master = room.master;
          if (master == null) throw const SteamBroadcastException(SteamBroadcastFailure.mediaUnavailable);
          validateMaster(
            await _get(master, mediaHeaders(steamId), token),
            expectedSteamId: steamId,
            expectedMaster: master,
          );
        }
        return room;
      });

  static SteamBroadcastPage parseDirectoryHtml(String source, {required int page}) {
    if (source.length > responseLimit || page < 1) {
      throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    }
    final document = html_parser.parseFragment(source);
    final seen = <String>{};
    final rooms = <SteamBroadcastRoom>[];
    for (final card in document.querySelectorAll('.Broadcast_Card')) {
      final steamId = SteamBroadcastLink.parseSteamId(
        card.querySelector('a[href*="/broadcast/watch/"]')?.attributes['href'] ?? '',
      );
      if (steamId == null || !seen.add(steamId)) continue;
      final contentType = _text(card.querySelector('.apphub_CardContentType'));
      final game = _text(card.querySelector('.apphub_CardContentTitle'));
      final broadcaster = _firstText([
        card.querySelector('.apphub_CardContentAuthorName a')?.text,
        card.querySelector('.apphub_CardContentAuthorName')?.text,
        steamId,
      ]);
      final cover = _image(card.querySelector('.apphub_CardContentPreviewImage')?.attributes['src'], steamId: steamId);
      final avatar = _avatar(card.querySelector('.appHubIconHolder img')?.attributes['src']);
      rooms.add(
        SteamBroadcastRoom(
          steamId: steamId,
          broadcaster: broadcaster,
          title: _stripBroadcastSuffix(contentType.isEmpty ? game : contentType),
          game: game,
          cover: cover,
          avatar: avatar,
          currentViewers: parseViewerCount(_text(card.querySelector('.apphub_CardContentViewers'))),
          state: SteamBroadcastState.live,
          master: null,
        ),
      );
    }
    final nextPage = int.tryParse(document.querySelector('input[name="p"]')?.attributes['value'] ?? '');
    final nextOffset = int.tryParse(
      document.querySelector('input[name="broadcastsoffset"]')?.attributes['value'] ?? '',
    );
    return SteamBroadcastPage(
      rooms: rooms,
      hasMore: rooms.isNotEmpty && nextPage == page + 1 && nextOffset == page * 10,
    );
  }

  static ({String broadcaster}) parseWatchHtml(String source, {required String expectedSteamId}) {
    if (source.length > responseLimit) throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    final document = html_parser.parse(source);
    final config = document.querySelector('#application_config')?.attributes['data-broadcastsinfo'];
    if (config == null) throw const SteamBroadcastException(SteamBroadcastFailure.missing);
    late final Map<String, dynamic> decoded;
    try {
      decoded = _object(jsonDecode(config));
    } on FormatException {
      throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    }
    if (_string(decoded['steamid']) != expectedSteamId) {
      throw const SteamBroadcastException(SteamBroadcastFailure.identity);
    }
    final title =
        document.querySelector('meta[property="og:title"]')?.attributes['content'] ??
        document.querySelector('title')?.text ??
        '';
    final match = RegExp(r'^Steam Community\s*::\s*(.+?)\s*::\s*Broadcast$', caseSensitive: false).firstMatch(title);
    final broadcaster = match?.group(1)?.trim();
    return (broadcaster: broadcaster == null || broadcaster.isEmpty ? 'Steam broadcaster' : broadcaster);
  }

  static SteamBroadcastRoom parseBroadcastJson(Object? value, {required String steamId, required String broadcaster}) {
    final root = _object(value);
    final success = _string(root['success']).toLowerCase();
    final state = switch (success) {
      'ready' => SteamBroadcastState.live,
      'unavailable' || 'offline' || 'not_live' || 'no_broadcast' => SteamBroadcastState.offline,
      'user_restricted' => SteamBroadcastState.restricted,
      'waiting' || 'waiting_to_start' || 'waiting_for_start' => SteamBroadcastState.unknown,
      _ => SteamBroadcastState.unknown,
    };
    Uri? master;
    if (state == SteamBroadcastState.live) {
      final raw = _string(root['hls_url']);
      master = _mediaUri(raw, steamId);
      if (master == null) throw const SteamBroadcastException(SteamBroadcastFailure.schema);
      master = _appendCdnAuth(master, root['cdn_auth_url_parameters']);
    }
    final title = _optionalText(root['title']);
    return SteamBroadcastRoom(
      steamId: steamId,
      broadcaster: broadcaster,
      title: title.isEmpty ? 'Steam Broadcast' : title,
      game: '',
      cover: '',
      avatar: '',
      currentViewers: _nonNegativeInt(root['num_viewers']),
      state: state,
      master: master,
    );
  }

  static void validateMaster(String source, {required String expectedSteamId, required Uri expectedMaster}) {
    if (source.length > 1024 * 1024 || !source.trimLeft().startsWith('#EXTM3U')) {
      throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    }
    final lines = const LineSplitter().convert(source);
    var variants = 0;
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        variants++;
        var next = index + 1;
        while (next < lines.length && lines[next].trim().startsWith('#')) {
          next++;
        }
        if (next >= lines.length || !_validChild(lines[next].trim(), expectedSteamId, expectedMaster.host)) {
          throw const SteamBroadcastException(SteamBroadcastFailure.schema);
        }
      }
      if (line.startsWith('#EXT-X-MEDIA:')) {
        final match = RegExp(r'URI="([^"]+)"').firstMatch(line);
        if (match == null || !_validChild(match.group(1)!, expectedSteamId, expectedMaster.host)) {
          throw const SteamBroadcastException(SteamBroadcastFailure.schema);
        }
      }
    }
    if (variants < 1 || variants > 16) throw const SteamBroadcastException(SteamBroadcastFailure.schema);
  }

  static int? parseViewerCount(String text) {
    final match = RegExp(r'^\s*([0-9][0-9,._\s]*)\s+viewers?\b', caseSensitive: false).firstMatch(text);
    final normalized = match?.group(1)?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (normalized.isEmpty || normalized.length > 12) return null;
    return int.tryParse(normalized);
  }

  static Uri? _mediaUri(String raw, String steamId) {
    if (raw.length > 8192 || RegExp(r'[\s\x00-\x1f]').hasMatch(raw)) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !_isMediaHost(uri.host) ||
        (uri.hasPort && uri.port != 443)) {
      return null;
    }
    final escapedId = RegExp.escape(steamId);
    final path = RegExp('^/broadcast/$escapedId/[1-9][0-9]{0,19}/hls_manifest/0/([^/]+)/master[.]m3u8\$')
        .firstMatch(uri.path);
    if (path == null || path.group(1)?.toLowerCase() != uri.host.toLowerCase()) return null;
    if (!_validOrigin(uri.queryParameters['broadcast_origin'])) return null;
    return uri;
  }

  static Uri _appendCdnAuth(Uri uri, Object? value) {
    if (value == null) return uri;
    if (value is! String) throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    var raw = value.trim();
    if (raw.isEmpty) return uri;
    while (raw.startsWith('&') || raw.startsWith('?')) {
      raw = raw.substring(1);
    }
    if (raw.isEmpty || raw.length > 4096 || RegExp(r'[\s#]').hasMatch(raw)) {
      throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    }
    final parsed = Uri(query: raw).queryParametersAll;
    if (parsed.isEmpty || parsed.length > 16 || parsed.containsKey('broadcast_origin')) {
      throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    }
    for (final entry in parsed.entries) {
      if (!RegExp(r'^[A-Za-z0-9_.~-]{1,128}$').hasMatch(entry.key) ||
          entry.value.isEmpty ||
          entry.value.length > 8 ||
          entry.value.any((item) => item.isEmpty || item.length > 2048)) {
        throw const SteamBroadcastException(SteamBroadcastFailure.schema);
      }
    }
    return Uri.parse('${uri.toString()}&$raw');
  }

  static bool _validChild(String raw, String steamId, String host) {
    final uri = Uri.tryParse(raw);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment &&
        uri.host.toLowerCase() == host.toLowerCase() &&
        uri.path.startsWith('/broadcast/$steamId/') &&
        uri.path.contains('/hls_manifest/0/') &&
        _validOrigin(uri.queryParameters['broadcast_origin']);
  }

  static String _image(Object? value, {required String steamId}) {
    final raw = _optionalText(value);
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.host.toLowerCase() != 'steambroadcast.akamaized.net' ||
        !uri.path.startsWith('/broadcast/$steamId/')) {
      return '';
    }
    return uri.toString();
  }

  static String _avatar(Object? value) {
    final raw = _optionalText(value);
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.host.toLowerCase() != 'avatars.akamai.steamstatic.com') {
      return '';
    }
    return uri.toString();
  }

  static bool _isMediaHost(String host) {
    final value = host.toLowerCase();
    return value.endsWith('.steamcontent.com') || value == 'steamcontent.com';
  }

  static bool _validOrigin(String? value) {
    if (value == null || value.length > 255) return false;
    final host = value.toLowerCase();
    return host == 'steamserver.net' || host.endsWith('.steamserver.net');
  }

  static String _stripBroadcastSuffix(String value) =>
      value.replaceFirst(RegExp(r':\s*Broadcast\s*$', caseSensitive: false), '').trim();

  static String _text(Element? element) => element?.text.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = _optionalText(value);
      if (text.isNotEmpty) return text;
    }
    throw const SteamBroadcastException(SteamBroadcastFailure.schema);
  }

  static String _string(Object? value) {
    final result = _optionalText(value);
    if (result.isEmpty) throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    return result;
  }

  static String _optionalText(Object? value) {
    if (value == null) return '';
    if (value is! String || value.length > 65536) {
      throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    }
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static int? _nonNegativeInt(Object? value) {
    if (value == null) return null;
    final parsed = switch (value) {
      int number => number,
      num number when number.isFinite => number.toInt(),
      String text => int.tryParse(text.trim()),
      _ => null,
    };
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const SteamBroadcastException(SteamBroadcastFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static void _throwStatus(int status) {
    final failure = switch (status) {
      200 => null,
      400 || 422 => SteamBroadcastFailure.schema,
      401 || 403 => SteamBroadcastFailure.access,
      404 => SteamBroadcastFailure.missing,
      429 => SteamBroadcastFailure.rateLimited,
      >= 500 => SteamBroadcastFailure.service,
      _ => SteamBroadcastFailure.transport,
    };
    if (failure != null) throw SteamBroadcastException(failure);
  }
}
