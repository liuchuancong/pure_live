import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';
import 'package:pure_live/core/interface/live_directory.dart';

enum PicartoFailure { transport, access, rateLimited, service, notFound, schema, cancelled, qualityUnavailable }

class PicartoException implements Exception {
  const PicartoException(this.kind);
  final PicartoFailure kind;
  @override
  String toString() => 'Picarto ${kind.name}';
}

typedef PicartoRequest = Future<({int status, String body})> Function(Uri uri, CancelToken? cancel);

/// Anonymous requests use the application's existing proxy and timeout policy.
/// No shared room, pagination, credential or playback state is retained.
class PicartoApi {
  PicartoApi({PicartoRequest? request}) : _request = request ?? _defaultRequest;
  static const origin = 'https://picarto.tv';
  static const apiOrigin = 'https://ptvintern.picarto.tv';
  static const responseLimit = 1024 * 1024;
  static const serverPageSize = 30;
  static const playHeaders = <String, String>{'Referer': '$origin/', 'Origin': origin};
  final PicartoRequest _request;

  static Future<({int status, String body})> _defaultRequest(Uri uri, CancelToken? cancel) =>
      withRequestCancellation(cancel, (transport) async {
        final result = await HttpClient.instance.dio.get<ResponseBody>(
          uri.toString(),
          options: Options(responseType: ResponseType.stream, headers: playHeaders, validateStatus: (_) => true),
          cancelToken: transport,
        );
        final response = result.data;
        if (response == null) throw const PicartoException(PicartoFailure.schema);
        if (result.statusCode != 200) {
          await response.stream.listen((_) {}).cancel();
          return (status: result.statusCode ?? 0, body: '');
        }
        return (status: 200, body: await readBody(response.stream));
      });

  /// Bound total body consumption even while a slow source keeps sending data.
  static Future<String> readBody(Stream<List<int>> stream, {Duration timeout = const Duration(seconds: 20)}) async {
    final iterator = StreamIterator(stream);
    final bytes = BytesBuilder(copy: false);
    final watch = Stopwatch()..start();
    try {
      while (true) {
        final remaining = timeout - watch.elapsed;
        if (remaining <= Duration.zero) throw TimeoutException('Picarto response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > responseLimit) throw const PicartoException(PicartoFailure.schema);
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const PicartoException(PicartoFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<String> read(Uri uri, {CancelToken? cancel}) async {
    if (cancel?.isCancelled ?? false) throw const PicartoException(PicartoFailure.cancelled);
    late final ({int status, String body}) response;
    try {
      response = await _request(uri, cancel);
    } catch (error) {
      if (cancel?.isCancelled == true) throw const PicartoException(PicartoFailure.cancelled);
      if (error is PicartoException) rethrow;
      throw const PicartoException(PicartoFailure.transport);
    }
    if (cancel?.isCancelled ?? false) throw const PicartoException(PicartoFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      401 || 403 => PicartoFailure.access,
      404 => PicartoFailure.notFound,
      429 => PicartoFailure.rateLimited,
      >= 500 => PicartoFailure.service,
      _ => PicartoFailure.transport,
    };
    if (failure != null) throw PicartoException(failure);
    if (response.body.length > responseLimit || utf8.encode(response.body).length > responseLimit) {
      throw const PicartoException(PicartoFailure.schema);
    }
    return response.body;
  }

  static Map<String, dynamic> object(Object? raw) {
    if (raw is String) {
      if (raw.length > responseLimit || utf8.encode(raw).length > responseLimit) {
        throw const PicartoException(PicartoFailure.schema);
      }
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        throw const PicartoException(PicartoFailure.schema);
      }
    }
    if (raw is! Map || raw.keys.any((key) => key is! String)) throw const PicartoException(PicartoFailure.schema);
    return Map<String, dynamic>.from(raw);
  }

  static String text(Object? raw) => raw is String ? raw.trim() : '';
  static int? integer(Object? raw) => raw is int ? raw : (raw is String ? int.tryParse(raw) : null);
  static String imageUrl(Object? raw) {
    final value = text(raw);
    final uri = Uri.tryParse(value);
    return uri != null && {'https', 'http'}.contains(uri.scheme) && uri.host.isNotEmpty && uri.userInfo.isEmpty
        ? value
        : '';
  }

  static String channelName(String value) {
    final name = value.trim();
    if (!RegExp(r'^[a-zA-Z0-9_]{1,50}$').hasMatch(name) ||
        const {
          'explore',
          'search',
          'settings',
          'login',
          'signup',
          'register',
          'password',
          'terms',
          'privacy',
          'help',
          'about',
        }.contains(name.toLowerCase())) {
      throw const PicartoException(PicartoFailure.schema);
    }
    return name;
  }

  static String? channelFromUri(Uri uri) {
    if (!{'http', 'https'}.contains(uri.scheme) ||
        !{'picarto.tv', 'www.picarto.tv'}.contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      return null;
    }
    try {
      final parts = uri.pathSegments.toList();
      if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
      if (parts.length != 1) return null;
      return channelName(parts.single);
    } on FormatException {
      return null;
    } on PicartoException {
      return null;
    }
  }

  Future<List<LiveArea>> categories({CancelToken? cancel}) async {
    final data = object(await read(Uri.parse('$apiOrigin/api/languages-categories'), cancel: cancel));
    final rows = data['categories'];
    if (rows is! List || rows.isEmpty || rows.length > 200) throw const PicartoException(PicartoFailure.schema);
    final result = <String, LiveArea>{};
    for (final raw in rows) {
      final category = object(raw);
      final id = integer(category['id']);
      final label = text(category['label']);
      if (id == null || id <= 0 || label.isEmpty || label.length > 100 || result.containsKey('$id')) {
        throw const PicartoException(PicartoFailure.schema);
      }
      result['$id'] = LiveArea(
        platform: 'picarto',
        areaType: 'category',
        areaId: '$id',
        areaName: label,
        typeName: 'Picarto',
      );
    }
    return List.unmodifiable(result.values);
  }

  Future<List<LiveRoom>> directory({int page = 1, int pageSize = 30, LiveArea? category, CancelToken? cancel}) async =>
      (await directoryPage(page: page, pageSize: pageSize, category: category, cancel: cancel)).rooms;

  Future<LiveDirectoryPage> directoryPage({
    int page = 1,
    int pageSize = serverPageSize,
    LiveArea? category,
    CancelToken? cancel,
  }) async {
    if (page < 1 || page > 10000 || pageSize < 1 || pageSize > 60) throw const PicartoException(PicartoFailure.schema);
    int? categoryId;
    if (category != null) {
      if (category.platform != 'picarto' || category.areaType != 'category') {
        throw const PicartoException(PicartoFailure.schema);
      }
      categoryId = int.tryParse(category.areaId ?? '');
      if (categoryId == null || categoryId <= 0 || '$categoryId' != category.areaId) {
        throw const PicartoException(PicartoFailure.schema);
      }
    }
    final query = <String, String>{
      'first': '$pageSize',
      'page': '$page',
      'filter_params[adult]': 'false',
      'order_by[field]': 'viewers',
      'order_by[order]': 'DESC',
      'type': 'stream',
    };
    if (categoryId != null) {
      query['filter_params[languages]'] = '';
      query['filter_params[categories]'] = '$categoryId: true';
    }
    final uri = Uri.parse('$apiOrigin/api/explore').replace(queryParameters: query);
    final data = object(await read(uri, cancel: cancel));
    final rows = data['data'];
    final last = integer(data['last_page']);
    if (rows is! List ||
        rows.length > pageSize ||
        integer(data['current_page']) != page ||
        integer(data['per_page']) != pageSize ||
        last == null ||
        last < 1 ||
        integer(data['total']) == null ||
        integer(data['total'])! < 0 ||
        (page > last && rows.isNotEmpty)) {
      throw const PicartoException(PicartoFailure.schema);
    }
    final rooms = <String, LiveRoom>{};
    for (final raw in rows) {
      final row = object(raw);
      if (row['adult'] is! bool) throw const PicartoException(PicartoFailure.schema);
      if (categoryId != null) {
        final categories = row['categories'];
        if (categories is! List || !categories.any((value) => integer(object(value)['id']) == categoryId)) {
          throw const PicartoException(PicartoFailure.schema);
        }
      }
      final room = parseChannel(row);
      // Explicit filtering is not a fabricated offline status. Do not fetch
      // more pages to fill a short page or follow the API's arbitrary next URL.
      if (row['adult'] != false || !room.isPlayableNow) continue;
      rooms.putIfAbsent(room.roomId!.toLowerCase(), () => room);
    }
    return LiveDirectoryPage(rooms: rooms.values, page: page, hasMore: page < last);
  }

  static LiveRoom parseChannel(Map<String, dynamic> channel, {String? expectedName, bool detail = false}) {
    final name = channelName(text(channel['name']));
    final id = integer(channel['id']);
    if (id == null ||
        id <= 0 ||
        channel['online'] is! bool ||
        (expectedName != null && name.toLowerCase() != expectedName.toLowerCase()) ||
        (detail && channel['private'] is! bool)) {
      throw const PicartoException(PicartoFailure.schema);
    }
    if (channel['private'] == true) throw const PicartoException(PicartoFailure.access);
    final online = channel['online'] == true;
    final viewers = integer(channel['viewers']);
    final total = integer(channel['total_views']);
    final categories = channel['categories'];
    return LiveRoom(
      platform: 'picarto',
      roomId: name,
      userId: '$id',
      nick: name,
      title: text(channel['title']),
      link: '$origin/${Uri.encodeComponent(name)}',
      avatar: imageUrl(channel['avatar']),
      cover: imageUrl(channel['image_thumbnail']),
      area: categories is List
          ? categories.whereType<Map>().map((c) => text(c['name'])).where((s) => s.isNotEmpty).join(' / ')
          : '',
      watching: viewers != null && viewers >= 0 ? '$viewers' : '',
      onlineViewers: viewers != null && viewers >= 0 ? '$viewers' : '',
      totalViewers: total != null && total >= 0 ? '$total' : '',
      audienceMetricType: AudienceMetricType.onlineViewers,
      status: online,
      liveStatus: online ? LiveStatus.live : LiveStatus.offline,
    );
  }

  Future<({LiveRoom room, Uri? master})> detail(String input, {CancelToken? cancel}) async {
    final name = channelName(input);
    final data = object(await read(Uri.parse('$apiOrigin/api/channel/detail/$name'), cancel: cancel));
    final room = parseChannel(object(data['channel']), expectedName: name, detail: true);
    if (!room.isPlayableNow) return (room: room, master: null);
    final origin = text(object(data['getLoadBalancerUrl'])['origin']);
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(origin) || origin.length > 63) {
      throw const PicartoException(PicartoFailure.schema);
    }
    final streams = object(data['getMultiStreams'])['streams'];
    if (streams is! List || streams.length > 100) throw const PicartoException(PicartoFailure.schema);
    final matches = streams.map(object).where((s) => '${integer(s['channelId'])}' == room.userId).toList();
    if (matches.length != 1) throw const PicartoException(PicartoFailure.schema);
    final stream = matches.single;
    final streamName = text(stream['stream_name']);
    if (!RegExp(r'^[a-zA-Z0-9_+-]{1,150}$').hasMatch(streamName)) throw const PicartoException(PicartoFailure.schema);
    room.cover = imageUrl(stream['thumbnail_image']);
    return (room: room, master: Uri.parse('https://$origin.picarto.tv/stream/hls/$streamName/index.m3u8'));
  }
}
