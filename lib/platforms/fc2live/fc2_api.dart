import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'fc2_link.dart';

enum Fc2Failure { transport, access, missing, rateLimited, service, schema, identity, cancelled, offline }

final class Fc2Exception implements Exception {
  const Fc2Exception(this.kind);

  final Fc2Failure kind;

  @override
  String toString() => 'FC2 Live ${kind.name}';
}

enum Fc2State { live, offline, restricted }

final class Fc2Room {
  const Fc2Room({
    required this.channelId,
    required this.userName,
    required this.title,
    required this.description,
    required this.cover,
    required this.categoryId,
    required this.categoryName,
    required this.currentViewers,
    required this.totalViewers,
    required this.state,
    required this.isAdult,
    required this.startedAt,
  });

  final String channelId;
  final String userName;
  final String title;
  final String description;
  final String cover;
  final int categoryId;
  final String categoryName;
  final int? currentViewers;
  final int? totalViewers;
  final Fc2State state;
  final bool isAdult;
  final DateTime? startedAt;
}

final class Fc2Directory {
  Fc2Directory({required Iterable<Fc2Room> rooms}) : rooms = List.unmodifiable(rooms);

  final List<Fc2Room> rooms;
}

final class Fc2ControlGrant {
  const Fc2ControlGrant({
    required this.channelId,
    required this.webSocket,
    required this.controlToken,
    required this.orz,
  });

  final String channelId;
  final Uri webSocket;
  final String controlToken;
  final String orz;
}

typedef Fc2Request = Future<({int status, String body})> Function(
  Uri uri,
  Map<String, String> headers,
  Map<String, String> form,
  CancelToken cancel,
);

class Fc2Api {
  Fc2Api({Fc2Request? request, this.deadline = const Duration(seconds: 25)}) : _request = request ?? _defaultRequest;

  static const String origin = 'https://live.fc2.com';
  static const int responseLimit = 4 * 1024 * 1024;
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
  static const Map<String, String> headers = {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Accept-Language': 'ja,en-US;q=0.9,en;q=0.8',
    'Origin': origin,
    'Referer': '$origin/',
    'X-Requested-With': 'XMLHttpRequest',
  };

  static Map<String, String> mediaHeaders(String channelId) => {
    'User-Agent': userAgent,
    'Origin': origin,
    'Referer': Fc2Link.channelUrl(channelId),
  };

  final Fc2Request _request;
  final Duration deadline;

  static Future<({int status, String body})> _defaultRequest(
    Uri uri,
    Map<String, String> requestHeaders,
    Map<String, String> form,
    CancelToken cancel,
  ) async {
    final encoded = form.entries
        .map((entry) => '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    final response = await HttpClient.instance.dio.post<ResponseBody>(
      uri.toString(),
      data: encoded,
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: {...requestHeaders, 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'},
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const Fc2Exception(Fc2Failure.schema);
    return (status: response.statusCode ?? 0, body: await _readBody(body.stream));
  }

  static Future<String> _readBody(Stream<List<int>> source) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        if (bytes.length + iterator.current.length > responseLimit) {
          throw const Fc2Exception(Fc2Failure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const Fc2Exception(Fc2Failure.schema);
    } finally {
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const Fc2Exception(Fc2Failure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const Fc2Exception(Fc2Failure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const Fc2Exception(Fc2Failure.transport);
        } catch (error) {
          if (caller?.isCancelled == true || transport.isCancelled) {
            throw const Fc2Exception(Fc2Failure.cancelled);
          }
          if (error is Fc2Exception) rethrow;
          throw const Fc2Exception(Fc2Failure.transport);
        }
      });

  Future<Map<String, dynamic>> _post(String path, Map<String, String> form, CancelToken token) async {
    final uri = Uri.parse('$origin$path');
    final response = await _request(uri, headers, form, token);
    _throwStatus(response.status);
    if (response.body.length > responseLimit) throw const Fc2Exception(Fc2Failure.schema);
    try {
      return _object(jsonDecode(response.body));
    } on FormatException {
      throw const Fc2Exception(Fc2Failure.schema);
    }
  }

  Future<Fc2Directory> directory({CancelToken? cancel}) => _scope(cancel, (token) async {
    final root = await _post('/contents/allchannellist.php', const {}, token);
    return parseDirectory(root);
  });

  Future<Fc2Room> room(String rawChannelId, {CancelToken? cancel}) => _scope(cancel, (token) async {
    final channelId = Fc2Link.parseChannelId(rawChannelId);
    if (channelId == null) throw const Fc2Exception(Fc2Failure.identity);
    final root = await _member(channelId, token);
    return parseMember(root, expectedChannelId: channelId).room;
  });

  Future<Fc2ControlGrant> controlGrant(String rawChannelId, {CancelToken? cancel}) => _scope(cancel, (token) async {
    final channelId = Fc2Link.parseChannelId(rawChannelId);
    if (channelId == null) throw const Fc2Exception(Fc2Failure.identity);
    final member = parseMember(await _member(channelId, token), expectedChannelId: channelId);
    if (member.room.state == Fc2State.offline) throw const Fc2Exception(Fc2Failure.offline);
    if (member.room.state == Fc2State.restricted) throw const Fc2Exception(Fc2Failure.access);
    final root = await _post('/api/getControlServer.php', {
      'channel_id': channelId,
      'mode': 'play',
      'orz': '',
      'channel_version': member.version,
      'client_version': '2.1.0\n [1]',
      'client_type': 'pc',
      'client_app': 'browser_hls',
      'ipv6': '',
    }, token);
    return parseControlGrant(root, expectedChannelId: channelId);
  });

  Future<Map<String, dynamic>> _member(String channelId, CancelToken token) =>
      _post('/api/memberApi.php', {'channel': '1', 'profile': '1', 'user': '1', 'streamid': channelId}, token);

  static Fc2Directory parseDirectory(Map<String, dynamic> root) {
    _positiveInt(root['time']);
    final seen = <String>{};
    final rooms = <Fc2Room>[];
    for (final value in _list(root['channel'], max: 1000)) {
      final data = _object(value);
      // Open chat and private two-shot entries are not public media rooms.
      if (_int(data['type']) != 1) continue;
      final room = _directoryRoom(data);
      if (seen.add(room.channelId)) rooms.add(room);
    }
    return Fc2Directory(rooms: rooms);
  }

  static Fc2Room _directoryRoom(Map<String, dynamic> data) {
    final id = _channelId(data['id']);
    final restricted = _int(data['pay']) != 0 || _int(data['login']) != 0 || _int(data['tid']) != 0;
    final categoryId = _boundedInt(data['category'], min: 0, max: 99);
    return Fc2Room(
      channelId: id,
      userName: _firstText([data['name'], id]),
      title: _firstText([data['title'], data['name'], id]),
      description: '',
      cover: _image(data['image']),
      categoryId: categoryId,
      categoryName: categoryName(categoryId),
      currentViewers: _nonNegativeInt(data['count']),
      totalViewers: _nonNegativeInt(data['total']),
      state: restricted ? Fc2State.restricted : Fc2State.live,
      isAdult: false,
      startedAt: _epochMillis(data['start_time']),
    );
  }

  static ({Fc2Room room, String version}) parseMember(Map<String, dynamic> root, {required String expectedChannelId}) {
    if (_int(root['status']) != 1) throw const Fc2Exception(Fc2Failure.missing);
    final data = _object(root['data']);
    final channel = _object(data['channel_data']);
    final profile = _optionalObject(data['profile_data']);
    final id = _channelId(channel['channelid']);
    if (id != expectedChannelId) throw const Fc2Exception(Fc2Failure.identity);
    final published = _int(channel['is_publish']) == 1;
    final restricted =
        _int(channel['fee']) != 0 ||
        _int(channel['login_only']) != 0 ||
        _int(channel['ticketid']) != 0 ||
        _int(channel['ticket_only']) != 0 ||
        _int(channel['is_limited']) != 0;
    final categoryId = _boundedInt(channel['category'], min: 0, max: 99);
    final version = _boundedToken(channel['version'], max: 256);
    return (
      room: Fc2Room(
        channelId: id,
        userName: _firstText([profile?['name'], channel['tname'], id]),
        title: _firstText([channel['title'], profile?['name'], id]),
        description: _optionalText(channel['info']),
        cover: _image(channel['image']),
        categoryId: categoryId,
        categoryName: _firstOptionalText([channel['category_name'], categoryName(categoryId)]),
        currentViewers: _nonNegativeInt(channel['count']),
        totalViewers: _nonNegativeInt(channel['total']),
        state: !published
            ? Fc2State.offline
            : restricted
            ? Fc2State.restricted
            : Fc2State.live,
        isAdult: _int(channel['adult']) == 1,
        startedAt: _epochMillis(channel['start']),
      ),
      version: version,
    );
  }

  static Fc2ControlGrant parseControlGrant(Map<String, dynamic> root, {required String expectedChannelId}) {
    final status = _int(root['status']);
    if (status != 0) throw const Fc2Exception(Fc2Failure.offline);
    final rawUri = _boundedToken(root['url'], max: 2048);
    final token = _boundedToken(root['control_token'], max: 4096);
    final orz = _boundedToken(root['orz_raw'], max: 256);
    final uri = Uri.tryParse(rawUri);
    if (uri == null ||
        uri.scheme != 'wss' ||
        uri.userInfo.isNotEmpty ||
        !_isFc2Host(uri.host) ||
        uri.path != '/control/channels/$expectedChannelId' ||
        uri.hasQuery ||
        uri.hasFragment ||
        !RegExp(r'^[A-Za-z0-9._~-]+$').hasMatch(orz)) {
      throw const Fc2Exception(Fc2Failure.schema);
    }
    return Fc2ControlGrant(channelId: expectedChannelId, webSocket: uri, controlToken: token, orz: orz);
  }

  static String categoryName(int category) => switch (category) {
    1 => 'Idle Chat',
    2 || 3 => 'Game / Work',
    4 => 'Video',
    5 => 'Other',
    9 => 'Audio',
    _ => 'FC2 Live',
  };

  static bool _isFc2Host(String host) {
    final value = host.toLowerCase();
    return value == 'live.fc2.com' || value.endsWith('.live.fc2.com');
  }

  static String _channelId(Object? value) {
    final result = Fc2Link.parseChannelId(_text(value));
    if (result == null) throw const Fc2Exception(Fc2Failure.schema);
    return result;
  }

  static String _image(Object? value) {
    final raw = _optionalText(value);
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(uri.host.toLowerCase() == 'fc2.com' || uri.host.toLowerCase().endsWith('.fc2.com'))) {
      return '';
    }
    return uri.toString();
  }

  static DateTime? _epochMillis(Object? value) {
    final millis = switch (value) {
      int number => number,
      num number when number.isFinite => number.toInt(),
      String text => int.tryParse(text.trim()),
      _ => null,
    };
    if (millis == null || millis < 946684800000 || millis > 4102444800000) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  static String _boundedToken(Object? value, {required int max}) {
    final result = _text(value);
    if (result.length > max) throw const Fc2Exception(Fc2Failure.schema);
    return result;
  }

  static int _boundedInt(Object? value, {required int min, required int max}) {
    final result = _int(value);
    if (result < min || result > max) throw const Fc2Exception(Fc2Failure.schema);
    return result;
  }

  static int _positiveInt(Object? value) {
    final result = _int(value);
    if (result < 1) throw const Fc2Exception(Fc2Failure.schema);
    return result;
  }

  static int _int(Object? value) {
    final result = switch (value) {
      int number => number,
      num number when number.isFinite => number.toInt(),
      String text => int.tryParse(text.trim()),
      _ => null,
    };
    if (result == null || result < -0x7fffffff || result > 0x7fffffff) {
      throw const Fc2Exception(Fc2Failure.schema);
    }
    return result;
  }

  static int? _nonNegativeInt(Object? value) {
    if (value == null) return null;
    final result = _int(value);
    return result >= 0 ? result : null;
  }

  static String _text(Object? value) {
    final result = _optionalText(value);
    if (result.isEmpty) throw const Fc2Exception(Fc2Failure.schema);
    return result;
  }

  static String _firstText(Iterable<Object?> values) {
    final result = _firstOptionalText(values);
    if (result.isEmpty) throw const Fc2Exception(Fc2Failure.schema);
    return result;
  }

  static String _firstOptionalText(Iterable<Object?> values) {
    for (final value in values) {
      final result = _optionalText(value);
      if (result.isNotEmpty) return result;
    }
    return '';
  }

  static String _optionalText(Object? value) {
    if (value == null) return '';
    if (value is! String) throw const Fc2Exception(Fc2Failure.schema);
    final result = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (result.length > 65536) throw const Fc2Exception(Fc2Failure.schema);
    return result;
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const Fc2Exception(Fc2Failure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static Map<String, dynamic>? _optionalObject(Object? value) => value == null ? null : _object(value);

  static List<Object?> _list(Object? value, {required int max}) {
    if (value is! List || value.length > max) throw const Fc2Exception(Fc2Failure.schema);
    return value;
  }

  static void _throwStatus(int status) {
    final failure = switch (status) {
      200 => null,
      400 || 422 => Fc2Failure.schema,
      401 || 403 => Fc2Failure.access,
      404 => Fc2Failure.missing,
      429 => Fc2Failure.rateLimited,
      >= 500 => Fc2Failure.service,
      _ => Fc2Failure.transport,
    };
    if (failure != null) throw Fc2Exception(failure);
  }
}
