// Module: lib/src/inke/inke_api.dart
// Purpose: 一直播(inke)的请求面:三份有限精选目录、房间详情、身份核对与那条不许改写的 flv 地址。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoints, the `error_code` envelope, the `1099999920` no-current-broadcast code, the showcase
// catalogue paths and the pull-host/path shape follow the v1-maintained Inke line
// (origin/master lib/shared/platforms/inke/inke_api.dart). Fresh implementation against the v2 capability
// contracts, not a file merge (UPSTREAM_REVIEW_POLICY.md).
//
// Two rules from that line are the whole value of this file, and both are the kind you cannot rediscover later:
//
//   1. **Only `1099999920` on `live_share_pc` means "not streaming now".** An unknown service code, an HTTP 5xx
//      or a catalogue with no verified stream all mean something else. Reading them as offline is what makes a
//      follow list announce a live anchor as finished.
//   2. **The pull url is taken verbatim.** Its host and path are checked, and its signed query is kept exactly:
//      no synthesising an hls address from the flv one, no rewriting to another broadcast that happens to belong
//      to the same uid. A url we assembled is a url we cannot explain when it 403s.

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../common/site_json.dart';

/// The source id every inke row carries.
const String inkeSourceId = 'inke.live';

const String inkeWebOrigin = 'https://www.inke.cn';
const String inkeApiOrigin = 'https://webapi.busi.inke.cn';

const String inkeTopPath = 'Live_top_pc';
const String inkeHotPath = 'Live_hot_pc';
const String inkeChannelPath = 'Live_channel_pc';
const String inkeSharePath = 'live_share_pc';

/// The code that, and only on the room endpoint, states "this anchor has no broadcast in progress".
const int inkeNoCurrentBroadcastCode = 1099999920;

const String inkeUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

const Map<String, String> inkeHeaders = <String, String>{'user-agent': inkeUserAgent, 'referer': '$inkeWebOrigin/'};

/// The only pull host the anonymous web catalogue ever names. Anything else is not an inke stream.
const String inkePullHost = 'live-pull-ws.ikstatic.cn';

/// One response body's ceiling. The catalogues are finite lists; a larger body is not a bigger list.
const int inkeResponseLimit = 1024 * 1024;

const int inkeRowLimit = 1000;
const int inkeGroupLimit = 100;

/// Why an inke call did not produce what it was asked for.
///
/// [inkeNotStreaming] is a fact about the anchor. [inkeMediaUnavailable] is a fact about **our** anonymous
/// catalogue and says nothing about whether they are live. Collapsing the two is how a site that is up gets
/// reported as finished.
final class InkeFailure implements Exception {
  const InkeFailure(this.message, {this.code, this.cause});

  final String message;
  final int? code;
  final Object? cause;

  @override
  String toString() =>
      'InkeFailure($message'
      '${code == null ? '' : ', code $code'}'
      '${cause == null ? '' : ': $cause'})';
}

/// One showcase row: the anchor, the broadcast they are in, and the pull url when the catalogue carries one.
final class InkeShowcaseRow {
  const InkeShowcaseRow({
    required this.uid,
    required this.broadcastId,
    required this.nick,
    this.avatar,
    this.streamUrl,
  });

  final String uid;
  final String broadcastId;
  final String nick;
  final String? avatar;

  /// The verbatim signed flv address, or null when the row's url was not one we are allowed to trust.
  final String? streamUrl;

  ContentSummary toSummary() => ContentSummary(
    ref: ContentRef(sourceId: inkeSourceId, contentId: uid, kind: ContentKind.liveRoom),
    title: nick,
    subtitle: 'uid $uid',
    cover: avatar,
  );
}

/// One category tab of the website showcase.
final class InkeChannel {
  const InkeChannel({required this.key, required this.name, required this.rows});

  final String key;
  final String name;
  final List<InkeShowcaseRow> rows;
}

/// The room answer, before it becomes a LiveRoom: the broadcast id and the verified urls.
final class InkeRoom {
  const InkeRoom({
    required this.uid,
    required this.isStreaming,
    required this.title,
    required this.nick,
    this.broadcastId,
    this.avatar,
    this.cover,
    this.startedAt,
    this.streamUrls = const <String>[],
  });

  final String uid;

  /// False **only** when the endpoint said `1099999920`. A room we could not verify is not a room we know
  /// nothing about, but it is certainly not this field either - that path throws.
  final bool isStreaming;
  final String title;
  final String nick;
  final String? broadcastId;
  final String? avatar;
  final String? cover;
  final DateTime? startedAt;
  final List<String> streamUrls;

  LiveRoom toLiveRoom() => LiveRoom(
    ref: ContentRef(sourceId: inkeSourceId, contentId: uid, kind: ContentKind.liveRoom),
    state: isStreaming ? LiveRoomState.live : LiveRoomState.ended,
    title: title.isEmpty ? nick : title,
    anchorName: nick.isEmpty ? null : nick,
    anchorId: uid,
    avatar: avatar,
    cover: cover,
    startedAt: isStreaming ? startedAt : null,
    streamId: broadcastId,
    // Inke's anonymous path states no audience number at all; leaving `viewers` null is the honest reading, and
    // a page that wants a number has to get it from a broadcast that gives one.
    extra: <String, Object?>{if (broadcastId != null) 'broadcastId': broadcastId, 'audienceStated': false},
  );
}

/// The inke client.
final class InkeApi {
  InkeApi({NetworkClient? client}) : _client = client ?? NetworkClient(), _ownsClient = client == null;

  final NetworkClient _client;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// The two finite public showcases' union, de-duplicated by uid.
  Future<List<InkeShowcaseRow>> showcase() async {
    final top = _rows((await _get(inkeTopPath))['list']);
    final byUid = <String, InkeShowcaseRow>{};
    for (final row in top) {
      final parsed = _row(row);
      if (parsed != null) {
        byUid.putIfAbsent(parsed.uid, () => parsed);
      }
    }
    return byUid.values.toList(growable: false);
  }

  /// The website's category tabs, each carrying its own finite list.
  Future<List<InkeChannel>> channels() async {
    final groups = _rows((await _get(inkeChannelPath))['list']);
    if (groups.length > inkeGroupLimit) {
      throw InkeFailure('channel list answered more tabs than the page can hold', code: groups.length);
    }
    final keys = <String>{};
    final channels = <InkeChannel>[];
    for (final group in groups) {
      final key = _text(group['tab_key']);
      final name = _text(group['channel_name']);
      // A tab whose key is not a wire token, or repeats, or has no name, is not something we can browse by -
      // and `_rows` below is what makes an unreadable row list throw rather than come back empty.
      if (!_tabKeyPattern.hasMatch(key) || !keys.add(key) || name.isEmpty) {
        throw InkeFailure('channel list carries an unusable tab: "$key"/"$name"');
      }
      final rows = <InkeShowcaseRow>[
        for (final row in _rows(group['list']))
          if (_row(row) case final InkeShowcaseRow parsed) parsed,
      ];
      channels.add(InkeChannel(key: key, name: name, rows: rows));
    }
    return channels;
  }

  /// The room for one anchor. [withStream] decides whether the catalogue is consulted for a verified url; a
  /// caller that only wants to know if they are live should pass false and save three requests.
  Future<InkeRoom> room(String input, {bool withStream = true}) async {
    final uid = validateRoomId(input);
    final Map<String, Object?> info;
    try {
      info = await _get(inkeSharePath, query: <String, String>{'uid': uid});
    } on InkeFailure catch (failure) {
      if (failure.code == inkeNoCurrentBroadcastCode) {
        // The one honest "not streaming now" this site gives us.
        return InkeRoom(uid: uid, isStreaming: false, title: '', nick: '');
      }
      rethrow;
    }
    // The identity and status checks are not paranoia: an answer about another uid, or one whose status field
    // says "prepared" rather than "on air", would otherwise become a room page that plays someone else.
    if (_idOf(info['live_uid']) != uid || !_isOnAir(info['status'])) {
      throw InkeFailure('room answer does not confirm an on-air broadcast for $uid');
    }
    final media = jsonMap(info['media_info']) ?? const <String, Object?>{};
    final nick = _text(media['nick']);
    if (_idOf(media['inke_id']) != uid || nick.isEmpty) {
      throw const InkeFailure('room answer carries a broadcaster it does not name');
    }
    final broadcastId = _idOf(info['liveid']);
    final urls = withStream ? await _catalogueStreams(uid, broadcastId) : const <String>[];
    return InkeRoom(
      uid: uid,
      isStreaming: true,
      title: _text(info['live_name']),
      nick: nick,
      broadcastId: broadcastId,
      avatar: _picture(media['portrait']),
      cover: _picture(info['portrait']),
      startedAt: _startedAt(info['start_time']),
      // The broadcast is on air whether or not our anonymous catalogue happens to list a verified url; the
      // empty list is about us, so it must not flip the state above.
      streamUrls: urls,
    );
  }

  /// The pull urls the finite catalogues carry for this exact broadcast; empty when none of them does.
  ///
  /// An empty list is **not** "offline" and not an error either: the broadcast may be perfectly live and simply
  /// not be in the three public lists we are allowed to read. The caller turns it into a refusal with that
  /// explanation, which keeps the on-air fact and the can't-play fact in different places.
  Future<List<String>> _catalogueStreams(String uid, String broadcastId) async {
    for (final path in <String>[inkeTopPath, inkeHotPath, inkeChannelPath]) {
      final data = await _get(path);
      // The three catalogues wrap their rows differently: hot is a map of groups, channel is a list of tabs each
      // with its own list, top is one flat list. Reading them the same way is how a broadcast in the hot tab
      // stays invisible to resolve.
      final List<Object?> groups;
      if (path == inkeHotPath) {
        groups = jsonMap(data['list'])?.values.toList(growable: false) ?? const <Object?>[];
      } else if (path == inkeChannelPath) {
        groups = <Object?>[for (final group in _rows(data['list'])) jsonMap(group)?['list']];
      } else {
        groups = <Object?>[data['list']];
      }
      if (groups.length > inkeGroupLimit) {
        throw InkeFailure('$path answered more groups than the page can hold', code: groups.length);
      }
      final urls = <String>{};
      for (final group in groups) {
        for (final row in _rows(group)) {
          if (_idOf(row['uid']) != uid || _idOf(row['live_id']) != broadcastId) {
            continue;
          }
          final url = _pullUrl(row['stream_addr'], broadcastId: broadcastId);
          if (url != null) {
            urls.add(url);
          }
        }
      }
      if (urls.isNotEmpty) {
        return urls.toList(growable: false);
      }
    }
    return const <String>[];
  }

  Future<Map<String, Object?>> _get(String path, {Map<String, String>? query}) async {
    final response = await _client.getText('$inkeApiOrigin/web/$path', headers: inkeHeaders, queryParameters: query);
    final status = response.statusCode;
    if (status != 200) {
      // Named by status because "401/403 is a login we do not have" and "404 is gone" need different handling.
      throw InkeFailure('web/$path answered $status', code: status);
    }
    if (response.body.length > inkeResponseLimit) {
      throw const InkeFailure('response body is larger than the catalogues can be');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw InkeFailure('web/$path answered something that is not json', cause: error);
    }
    final envelope = jsonMap(decoded);
    if (envelope == null) {
      throw const InkeFailure('answer is not a json object');
    }
    final code = jsonInt(envelope['error_code']);
    if (code == null) {
      throw const InkeFailure('answer carries no error_code');
    }
    if (code == inkeNoCurrentBroadcastCode && path == inkeSharePath) {
      throw InkeFailure('this anchor has no broadcast in progress', code: code);
    }
    if (code != 0) {
      throw InkeFailure('inke refused the request', code: code);
    }
    return jsonMap(envelope['data']) ?? const <String, Object?>{};
  }

  InkeShowcaseRow? _row(Map<String, Object?> row) {
    final uid = _idOf(row['uid']);
    final broadcastId = _idOf(row['live_id']);
    final nick = _text(row['nick']);
    if (uid.isEmpty || broadcastId.isEmpty || nick.isEmpty) {
      // A row that does not name its anchor is not a tile; dropping it keeps the page readable instead of
      // failing the whole catalogue over one entry.
      return null;
    }
    return InkeShowcaseRow(
      uid: uid,
      broadcastId: broadcastId,
      nick: nick,
      avatar: _picture(row['portrait']),
      streamUrl: _pullUrl(row['stream_addr'], broadcastId: broadcastId),
    );
  }

  static final RegExp _roomIdPattern = RegExp(r'^[1-9][0-9]{0,17}$');

  static final RegExp _tabKeyPattern = RegExp(r'^[a-zA-Z0-9]{1,64}$');

  /// An anchor's uid doubles as the room id on this site.
  static String validateRoomId(String value) {
    final result = value.trim();
    if (!_roomIdPattern.hasMatch(result)) {
      throw const InkeFailure('not an inke room id');
    }
    return result;
  }

  /// A room link from the watch page, or null when the url is not one. A `uid` that appears twice is not one uid.
  static String? roomFromUri(Uri uri) {
    if (!const <String>{'http', 'https'}.contains(uri.scheme) ||
        !const <String>{'inke.cn', 'www.inke.cn', 'inke.com', 'www.inke.com'}.contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.path != '/liveroom/index.html') {
      return null;
    }
    final values = uri.queryParametersAll['uid'];
    if (values == null || values.length != 1) {
      return null;
    }
    return _roomIdPattern.hasMatch(values.single.trim()) ? values.single.trim() : null;
  }

  static String _idOf(Object? value) => value is num ? '${value.toInt()}' : _text(value);

  static String _text(Object? value) => value is String ? value.trim() : '';

  static List<Map<String, Object?>> _rows(Object? value) {
    if (value is! List) {
      throw const InkeFailure('a list field was not a list');
    }
    if (value.length > inkeRowLimit) {
      throw InkeFailure('a list is longer than the site\'s own pages', code: value.length);
    }
    return <Map<String, Object?>>[
      for (final row in value)
        if (jsonMap(row) case final Map<String, Object?> m) m,
    ];
  }

  static bool _isOnAir(Object? value) => value == 1 || value == '1' || value == true;

  static String? _picture(Object? value) {
    final text = _text(value);
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !const <String>{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return text;
  }

  /// The pull url, accepted only in the exact shape the site ships.
  ///
  /// The host and the path are pinned to this broadcast's id, the port must be the scheme's default, and the
  /// signed query is kept byte-for-byte. Nothing here synthesises an hls address from an flv one or borrows a
  /// different broadcast under the same uid: both have shipped as "works in dev, 403 in the field", and a url we
  /// built ourselves is a url nobody can debug.
  static String? _pullUrl(Object? value, {required String broadcastId}) {
    final text = _text(value);
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !const <String>{'http', 'https'}.contains(uri.scheme) ||
        uri.host != inkePullHost ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.path != '/live/${validateRoomId(broadcastId)}_t.flv') {
      return null;
    }
    if (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) {
      return null;
    }
    return text;
  }

  static DateTime? _startedAt(Object? value) {
    final seconds = int.tryParse(_text(value));
    if (seconds == null || seconds <= 0) {
      return null;
    }
    final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    // A stamp outside this window is a field that meant something else; "已直播 56 年" is not information.
    return time.year >= 2000 && time.year <= 2100 ? time : null;
  }
}
