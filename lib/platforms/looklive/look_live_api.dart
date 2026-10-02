import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'look_live_link.dart';

enum LookLiveFailure { transport, access, missing, rateLimited, service, schema, identity, cancelled, mediaUnavailable }

final class LookLiveException implements Exception {
  const LookLiveException(this.kind);

  final LookLiveFailure kind;

  @override
  String toString() => 'LOOK Live ${kind.name}';
}

enum LookLiveKind { video, audio }

enum LookLiveState { live, offline, restricted, unknown }

final class LookLiveVariant {
  const LookLiveVariant({required this.id, required this.protocol, required this.uri});

  final String id;
  final String protocol;
  final Uri uri;
}

final class LookLiveRoom {
  LookLiveRoom({
    required this.roomId,
    required this.userId,
    required this.sessionId,
    required this.title,
    required this.nick,
    required this.avatar,
    required this.cover,
    required this.kind,
    required this.streamType,
    required this.state,
    required this.popularity,
    required this.currentViewers,
    required Iterable<LookLiveVariant> variants,
  }) : variants = List.unmodifiable(variants);

  final String roomId;
  final String userId;
  final String sessionId;
  final String title;
  final String nick;
  final String avatar;
  final String cover;
  final LookLiveKind kind;
  final int? streamType;
  final LookLiveState state;
  final int? popularity;
  final int? currentViewers;
  final List<LookLiveVariant> variants;

  bool get isAppOnly => streamType == 50 && variants.isEmpty;

  LookLiveRoom enrich(LookLiveRoom known) {
    final sameSession = sessionId.isNotEmpty && sessionId == known.sessionId;
    final effectiveStreamType = streamType ?? known.streamType;
    final keepKnownVariants =
        variants.isEmpty &&
        sameSession &&
        state == LookLiveState.live &&
        known.state == LookLiveState.live &&
        effectiveStreamType != 50;
    return LookLiveRoom(
      roomId: roomId,
      userId: userId.isEmpty ? known.userId : userId,
      sessionId: sessionId,
      title: title.isEmpty ? known.title : title,
      nick: nick.isEmpty ? known.nick : nick,
      avatar: avatar.isEmpty ? known.avatar : avatar,
      cover: cover.isEmpty ? known.cover : cover,
      kind: kind,
      streamType: effectiveStreamType,
      state: state,
      popularity: popularity ?? (sameSession ? known.popularity : null),
      currentViewers: currentViewers ?? (sameSession ? known.currentViewers : null),
      variants: keepKnownVariants ? known.variants : variants,
    );
  }
}

final class LookLivePage {
  LookLivePage({required Iterable<LookLiveRoom> rooms, required this.hasMore}) : rooms = List.unmodifiable(rooms);

  final List<LookLiveRoom> rooms;
  final bool hasMore;
}

typedef LookLiveRequest = Future<({int status, String body})> Function(
  Uri uri,
  Map<String, String> form,
  CancelToken? cancel,
);

/// Anonymous LOOK website contracts. The AES/RSA envelope is the public
/// browser request format shared by the current official web bundle.
class LookLiveApi {
  LookLiveApi({LookLiveRequest? request, this.deadline = const Duration(seconds: 20)})
    : _request = request ?? _defaultRequest;

  static const origin = 'https://look.163.com';
  static const apiOrigin = 'https://api.look.163.com';
  static const responseLimit = 2 * 1024 * 1024;
  static const serverPageSize = 20;
  static const _nonce = '0CoJUm6Qyw8W8jud';
  static const _secretKey = '0123456789abcdef';
  static const _iv = '0102030405060708';
  static const _publicKey = '010001';
  static const _modulus =
      '00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec'
      '4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813'
      'cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7';
  static const requestHeaders = <String, String>{
    'Accept': 'application/json, text/plain, */*',
    'Origin': origin,
    'Referer': '$origin/',
    'User-Agent': 'Mozilla/5.0',
  };

  final LookLiveRequest _request;
  final Duration deadline;

  static Map<String, String> encryptPayload(Map<String, Object?> payload) {
    final first = _aes(jsonEncode(payload), _nonce);
    final params = _aes(first, _secretKey);
    final reversed = Uint8List.fromList(utf8.encode(_secretKey).reversed.toList(growable: false));
    final text = reversed.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final encrypted = BigInt.parse(
      text,
      radix: 16,
    ).modPow(BigInt.parse(_publicKey, radix: 16), BigInt.parse(_modulus, radix: 16));
    return {'params': params, 'encSecKey': encrypted.toRadixString(16).padLeft(256, '0')};
  }

  static String _aes(String value, String key) {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        true,
        PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
          ParametersWithIV(KeyParameter(Uint8List.fromList(utf8.encode(key))), Uint8List.fromList(utf8.encode(_iv))),
          null,
        ),
      );
    return base64Encode(cipher.process(Uint8List.fromList(utf8.encode(value))));
  }

  static Future<({int status, String body})> _defaultRequest(Uri uri, Map<String, String> form, CancelToken? cancel) =>
      withRequestCancellation(cancel, (transport) async {
        final response = await HttpClient.instance.dio.post<ResponseBody>(
          uri.toString(),
          data: Uri(queryParameters: form).query,
          options: Options(
            responseType: ResponseType.stream,
            contentType: Headers.formUrlEncodedContentType,
            headers: requestHeaders,
            followRedirects: false,
            validateStatus: (_) => true,
          ),
          cancelToken: transport,
        );
        final body = response.data;
        if (body == null) throw const LookLiveException(LookLiveFailure.schema);
        if (response.statusCode != 200) {
          await body.stream.listen((_) {}).cancel();
          return (status: response.statusCode ?? 0, body: '');
        }
        return (status: 200, body: await _readBody(body.stream));
      });

  static Future<String> _readBody(Stream<List<int>> stream) async {
    final iterator = StreamIterator(stream);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        final chunk = iterator.current;
        if (bytes.length + chunk.length > responseLimit) {
          throw const LookLiveException(LookLiveFailure.schema);
        }
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const LookLiveException(LookLiveFailure.schema);
    } finally {
      await iterator.cancel();
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> payload, {CancelToken? cancel}) async {
    if (cancel?.isCancelled == true) throw const LookLiveException(LookLiveFailure.cancelled);
    late final ({int status, String body}) response;
    try {
      response = await _request(Uri.parse('$apiOrigin$path'), encryptPayload(payload), cancel).timeout(deadline);
    } on TimeoutException {
      throw const LookLiveException(LookLiveFailure.transport);
    } catch (error) {
      if (cancel?.isCancelled == true) throw const LookLiveException(LookLiveFailure.cancelled);
      if (error is LookLiveException) rethrow;
      throw const LookLiveException(LookLiveFailure.transport);
    }
    if (cancel?.isCancelled == true) throw const LookLiveException(LookLiveFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      401 || 403 => LookLiveFailure.access,
      404 => LookLiveFailure.missing,
      429 => LookLiveFailure.rateLimited,
      >= 500 => LookLiveFailure.service,
      _ => LookLiveFailure.transport,
    };
    if (failure != null) throw LookLiveException(failure);
    if (response.body.length > responseLimit || utf8.encode(response.body).length > responseLimit) {
      throw const LookLiveException(LookLiveFailure.schema);
    }
    late final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const LookLiveException(LookLiveFailure.schema);
    }
    final root = _object(decoded);
    final code = _integer(root['code']);
    if (code == 404) throw const LookLiveException(LookLiveFailure.missing);
    if (code == 424 || code == 520 || code == 522 || code == 555) {
      throw const LookLiveException(LookLiveFailure.access);
    }
    if (code != 200) throw const LookLiveException(LookLiveFailure.service);
    return _object(root['data']);
  }

  Future<LookLivePage> directory({required LookLiveKind kind, int page = 1, CancelToken? cancel}) async {
    if (page < 1 || page > 10000) throw const LookLiveException(LookLiveFailure.schema);
    final path = kind == LookLiveKind.audio
        ? '/weapi/livestream/listen/homepage/recommend/list'
        : '/weapi/livestream/homepage/recommend';
    final data = await _post(path, {'offset': (page - 1) * serverPageSize, 'limit': serverPageSize}, cancel: cancel);
    final rows = data['itemList'];
    final hasMore = data['hasMore'];
    if (rows is! List || rows.length > 100 || hasMore is! bool) {
      throw const LookLiveException(LookLiveFailure.schema);
    }
    final rooms = <String, LookLiveRoom>{};
    for (final raw in rows) {
      final item = _object(raw);
      if ('${item['type']}' != '1' || item['liveData'] == null) continue;
      final live = _object(item['liveData']);
      final liveType = _integer(live['liveType']);
      if (liveType != 1 && liveType != 2) throw const LookLiveException(LookLiveFailure.schema);
      // The official voice feed occasionally injects a video/multi-room card.
      // Preserve the category identity rather than failing or mislabelling it.
      if ((liveType == 2 ? LookLiveKind.audio : LookLiveKind.video) != kind) continue;
      final room = _directoryRoom(live, expectedKind: kind);
      rooms[room.roomId] = room;
    }
    return LookLivePage(rooms: rooms.values, hasMore: hasMore);
  }

  Future<LookLiveRoom> room(String input, {bool includeMedia = true, CancelToken? cancel}) async {
    final id = LookLiveLink.requireRoomId(input);
    final data = await _post('/weapi/livestream/room/get/v3', {'liveRoomNo': id}, cancel: cancel);
    final anchor = _object(data['anchor']);
    final returnedId = _identifier(anchor['liveRoomNo']);
    if (returnedId != id) throw const LookLiveException(LookLiveFailure.identity);
    final info = _object(data['roomInfo']);
    final liveType = _integer(info['liveType']);
    final state = switch (_integer(data['liveStatus'])) {
      1 => LookLiveState.live,
      0 || -1 => LookLiveState.offline,
      -10 => LookLiveState.restricted,
      _ => LookLiveState.unknown,
    };
    if (liveType != 1 && liveType != 2) throw const LookLiveException(LookLiveFailure.schema);
    return LookLiveRoom(
      roomId: id,
      userId: _identifier(anchor['userId']),
      sessionId: _identifier(info['id']),
      title: _text(info['title']),
      nick: _text(anchor['nickName']),
      avatar: _picture(anchor['avatarUrl']),
      cover: _picture(info['liveCoverUrl']),
      kind: liveType == 2 ? LookLiveKind.audio : LookLiveKind.video,
      streamType: _integer(info['liveStreamType']),
      state: state,
      popularity: null,
      currentViewers: null,
      variants: includeMedia && state == LookLiveState.live ? _variants(info['liveUrl']) : const [],
    );
  }

  static LookLiveRoom _directoryRoom(Map<String, dynamic> live, {required LookLiveKind expectedKind}) {
    final user = _object(live['userInfo']);
    final liveType = _integer(live['liveType']);
    if (liveType != 1 && liveType != 2) throw const LookLiveException(LookLiveFailure.schema);
    final actualKind = liveType == 2 ? LookLiveKind.audio : LookLiveKind.video;
    if (actualKind != expectedKind) throw const LookLiveException(LookLiveFailure.schema);
    final popularity = _nonNegative(live['popularity']);
    final currentViewers = _nonNegative(live['onlineNumber']);
    return LookLiveRoom(
      roomId: _identifier(user['liveRoomNo']),
      userId: _identifier(user['userId']),
      sessionId: _identifier(live['liveId']),
      title: _text(live['liveTitle']),
      nick: _text(user['nickname']),
      avatar: _picture(user['avatarUrl']),
      cover: _picture(live['liveCoverUrl']),
      kind: actualKind,
      streamType: _integer(live['liveStreamType']),
      state: LookLiveState.live,
      popularity: popularity,
      currentViewers: currentViewers,
      variants: _variants(live['liveUrl']),
    );
  }

  static List<LookLiveVariant> _variants(Object? raw) {
    if (raw == null) return const [];
    final data = _object(raw);
    final result = <LookLiveVariant>[];
    for (final entry in const [('hls', 'hlsPullUrl'), ('flv', 'httpPullUrl')]) {
      final value = _text(data[entry.$2]);
      if (value.isEmpty) continue;
      final uri = mediaUri(value, protocol: entry.$1);
      result.add(LookLiveVariant(id: '${entry.$1}:source', protocol: entry.$1, uri: uri));
    }
    return List.unmodifiable(result);
  }

  static Uri mediaUri(String raw, {required String protocol}) {
    final source = Uri.tryParse(raw.trim());
    if (source == null ||
        !const {'http', 'https'}.contains(source.scheme.toLowerCase()) ||
        source.userInfo.isNotEmpty ||
        source.hasPort ||
        source.fragment.isNotEmpty ||
        !RegExp(r'^[a-z0-9-]+\.live\.126\.net$').hasMatch(source.host.toLowerCase()) ||
        source.query.length > 2048) {
      throw const LookLiveException(LookLiveFailure.schema);
    }
    final validPath = switch (protocol) {
      'hls' => RegExp(r'^/live/[a-f0-9]{32}/playlist\.m3u8$').hasMatch(source.path),
      'flv' => RegExp(r'^/live/[a-f0-9]{32}\.flv$').hasMatch(source.path),
      _ => false,
    };
    if (!validPath) throw const LookLiveException(LookLiveFailure.schema);
    return source.replace(scheme: 'https');
  }

  static Map<String, String> mediaHeaders(String roomId) => {
    'Origin': origin,
    'Referer': LookLiveLink.watchUrl(roomId),
    'User-Agent': 'Mozilla/5.0',
  };

  static Map<String, dynamic> _object(Object? raw) {
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const LookLiveException(LookLiveFailure.schema);
    }
    return Map<String, dynamic>.from(raw);
  }

  static String _text(Object? raw) => raw is String ? raw.trim() : '';

  static int? _integer(Object? raw) => raw is int ? raw : (raw is String ? int.tryParse(raw) : null);

  static int? _nonNegative(Object? raw) {
    if (raw == null) return null;
    final value = _integer(raw);
    if (value == null || value < 0) throw const LookLiveException(LookLiveFailure.schema);
    return value;
  }

  static String _identifier(Object? raw) {
    final value = raw is int ? '$raw' : (raw is String ? raw.trim() : '');
    if (!RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(value)) {
      throw const LookLiveException(LookLiveFailure.schema);
    }
    return value;
  }

  static String _picture(Object? raw) {
    final value = _text(raw);
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.fragment.isNotEmpty) {
      return '';
    }
    return uri.replace(scheme: 'https').toString();
  }
}
