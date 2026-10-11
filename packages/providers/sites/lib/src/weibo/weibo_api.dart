// Module: lib/src/weibo/weibo_api.dart
// Purpose: 微博直播的请求面:推荐快照、房间详情、身份核对与访问限制读法。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoints, the `code: 100000 / error_code: 0` envelope, the `status` / `watch_limit` /
// `play_switch` code tables and the two media url fields follow the v1-maintained Weibo line
// (origin/master lib/shared/platforms/weibo/). Fresh implementation against the v2 capability contracts, not a
// file merge (UPSTREAM_REVIEW_POLICY.md).
//
// A site is two files (package-architecture.md §2.1); the shapes a caller receives are the shared platform models,
// and the live facts go on LiveRoom as fields.
//
// The recommendation list is a **finite snapshot**: `pc_recommend/list.json` is not a pagination endpoint and not
// a search endpoint. Asking it for page 2 and getting page 1 again is how a feed becomes an endless loop of the
// same twelve rooms, so the reader says singleShot and the caller stops asking.

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';

import '../common/site_json.dart';

/// The source id every weibo row carries.
const String weiboSourceId = 'weibo.live';

const String weiboOrigin = 'https://weibo.com';
const String weiboDirectoryPath = '/l/!/2/wblive/pc_recommend/list.json';
const String weiboRoomPath = '/l/!/2/wblive/room/show_pc_live.json';

const String weiboUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

/// The web live player's own referer; the json endpoints answer 403 without it.
const Map<String, String> weiboHeaders = <String, String>{
  'user-agent': weiboUserAgent,
  'referer': 'https://weibo.com/l/wblive/',
};

/// The envelope's success code, and the `error_code` that has to be 0 alongside it.
const int weiboSuccessCode = 100000;

/// The row count the snapshot answered with that we refuse to believe.
const int weiboDirectoryRowLimit = 500;

/// Why a weibo call did not produce what it was asked for.
///
/// The split matters upstream: [weiboFailureAccess] is a login the app does not have, [weiboFailureMissing] is a
/// room that is gone, [weiboFailureRateLimited] is worth waiting on, and [weiboFailureSchema] is a bug in this
/// file. Collapsing them into one error is what turns "log in" and "the site changed" into the same message.
final class WeiboFailure implements Exception {
  const WeiboFailure(this.message, {this.code, this.cause});

  final String message;
  final int? code;
  final Object? cause;

  @override
  String toString() =>
      'WeiboFailure($message'
      '${code == null ? '' : ', code $code'}'
      '${cause == null ? '' : ': $cause'})';
}

/// What the room said about who may watch it.
enum WeiboAccess {
  /// Open to an anonymous viewer.
  public,

  /// Gated by `watch_limit`: app-only, friends-only, self-only or paid.
  restricted,

  /// `play_switch: 0` - the owner turned playback off while the room still lists.
  disabled,
}

/// The room's own broadcast state, in weibo's numbering rather than the platform's.
enum WeiboBroadcast { live, replay, offline, unknown }

/// One row of the recommendation snapshot.
final class WeiboRoomCard {
  const WeiboRoomCard({required this.liveId, required this.ownerId, required this.nickname, this.cover});

  final String liveId;
  final int ownerId;
  final String nickname;
  final String? cover;

  ContentSummary toSummary() => ContentSummary(
    ref: ContentRef(sourceId: weiboSourceId, contentId: liveId, kind: ContentKind.liveRoom),
    title: nickname.isEmpty ? liveId : nickname,
    subtitle: nickname.isEmpty ? null : 'uid $ownerId',
    cover: cover,
  );
}

/// The full room answer, including the gates and the urls the anonymous path may actually open.
final class WeiboRoomDetail {
  const WeiboRoomDetail({
    required this.liveId,
    required this.ownerId,
    required this.state,
    required this.access,
    required this.title,
    required this.nickname,
    required this.watchLimit,
    required this.reportedStatus,
    required this.mediaUrls,
    this.cover,
    this.avatar,
    this.width,
    this.height,
  });

  final String liveId;
  final int ownerId;
  final WeiboBroadcast state;
  final WeiboAccess access;
  final String title;
  final String nickname;
  final String? cover;
  final String? avatar;

  /// The raw `watch_limit`. Kept as a number because the meaning is the site's code table, not ours.
  final int watchLimit;
  final int reportedStatus;
  final int? width;
  final int? height;

  /// The playable urls, in the order the site ships them (flv first, then hls when both are present).
  final List<String> mediaUrls;

  bool get isLive => state == WeiboBroadcast.live;

  /// Whether this answer lets us open anything at all.
  bool get isPlayable => mediaUrls.isNotEmpty && access == WeiboAccess.public;

  String? get url {
    if (!isPlayable) {
      return null;
    }
    return mediaUrls.first;
  }

  /// The room as the live model, with the gate stated rather than hidden.
  LiveRoom toLiveRoom() {
    final title = this.title.trim();
    final nickname = this.nickname.trim();
    return LiveRoom(
      ref: ContentRef(sourceId: weiboSourceId, contentId: liveId, kind: ContentKind.liveRoom),
      state: switch (state) {
        WeiboBroadcast.live => LiveRoomState.live,
        WeiboBroadcast.replay => LiveRoomState.ended,
        // `offline` and an unrecognised code are deliberately not the same thing: one is "it finished", the
        // other is "we stopped understanding the field", and a follow list must not treat the second as the
        // first or it stops watching a room that is up.
        WeiboBroadcast.offline => LiveRoomState.ended,
        WeiboBroadcast.unknown => LiveRoomState.unknown,
      },
      title: title.isNotEmpty ? title : nickname,
      anchorName: nickname.isEmpty ? null : nickname,
      anchorId: ownerId == 0 ? null : '$ownerId',
      avatar: avatar,
      cover: cover,
      // A watch_limit is a statement about *who may watch*, and LiveRestriction is the field that lets a
      // surface explain a refused open instead of showing a black screen and a spinner. The code table is the
      // site's own: 8 = app-only, 10/11 = friends/self only, 12 = paid.
      restriction: switch (access) {
        WeiboAccess.public => LiveRestriction.none,
        WeiboAccess.disabled => LiveRestriction.unplayable,
        WeiboAccess.restricted => switch (watchLimit) {
          8 => LiveRestriction.appOnly,
          10 || 11 => LiveRestriction.private,
          12 => LiveRestriction.paid,
          _ => LiveRestriction.unknown,
        },
      },
      reportedStateCode: watchLimit,
      extra: <String, Object?>{
        'watchLimit': watchLimit,
        'reportedStatus': reportedStatus,
        'access': access.name,
        if (width != null && height != null) 'size': '${width}x$height',
      },
    );
  }
}

/// The weibo live client.
final class WeiboApi {
  WeiboApi({NetworkClient? client}) : _client = client ?? NetworkClient(), _ownsClient = client == null;

  final NetworkClient _client;
  final bool _ownsClient;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// The anonymous recommendation snapshot. One answer, no continuation.
  Future<List<WeiboRoomCard>> directory() async {
    final data = await _read(weiboDirectoryPath, <String, Object?>{'count': 100, 'uid': ''});
    final rows = jsonList(data['data']);
    if (rows.length > weiboDirectoryRowLimit) {
      throw WeiboFailure('directory answered more rows than the endpoint can hold', code: rows.length);
    }
    final seen = <String>{};
    final cards = <WeiboRoomCard>[];
    for (final row in rows) {
      final item = jsonMap(row);
      if (item == null) {
        continue;
      }
      final id = validateLiveId('${item['liveid'] ?? ''}');
      if (!seen.add(id)) {
        // A snapshot that lists the same room twice is not a list we can page or de-duplicate honestly later.
        throw WeiboFailure('directory listed $id twice');
      }
      cards.add(
        WeiboRoomCard(
          liveId: id,
          ownerId: _ownerId(item['uid']),
          nickname: '${item['nickname'] ?? ''}'.trim(),
          cover: _image(item['cover']),
        ),
      );
    }
    return cards;
  }

  /// The room answer for [liveId]. [expectedOwnerId] is the identity the caller already holds; a mismatch is
  /// refused rather than displayed, because an answer about someone else is how one anchor's room opens another.
  Future<WeiboRoomDetail> room(String liveId, {int? expectedOwnerId}) async {
    final id = validateLiveId(liveId);
    final data = await _read(weiboRoomPath, <String, Object?>{'live_id': id});
    final user = jsonMap(data['user']) ?? const <String, Object?>{};
    final answerId = validateLiveId('${data['liveId'] ?? ''}');
    final owner = _ownerId(user['uid']);
    if (answerId != id || (expectedOwnerId != null && owner != expectedOwnerId)) {
      throw WeiboFailure('room info answered for $answerId/uid $owner while asking about $id');
    }
    final status = _int(data['status']);
    final limit = _int(data['watch_limit']);
    final enabled = _int(data['play_switch']);
    final access = enabled == 0
        ? WeiboAccess.disabled
        : limit != 0
        ? WeiboAccess.restricted
        : WeiboAccess.public;
    final state = switch (status) {
      1 => WeiboBroadcast.live,
      3 => WeiboBroadcast.replay,
      5 => WeiboBroadcast.offline,
      _ => WeiboBroadcast.unknown,
    };
    // The presence of a trial media url is not permission: pay_live_status and play_switch decide what an
    // anonymous viewer may open. Exposing the url anyway is how a paid stream leaks into the player and then
    // stops mid-broadcast with nothing to show.
    final urls = <String>[
      if (state == WeiboBroadcast.live && access == WeiboAccess.public)
        for (final key in const <String>['live_origin_flv_url', 'live_origin_hls_url'])
          if (_mediaUrl(data[key], allowQuery: true) case final String url) url,
    ];
    return WeiboRoomDetail(
      liveId: answerId,
      ownerId: owner,
      state: state,
      access: access,
      title: '${data['title'] ?? ''}'.trim(),
      nickname: '${user['screenName'] ?? ''}'.trim(),
      cover: _image(data['cover']),
      avatar: _image(user['profileImageUrl']),
      watchLimit: limit,
      reportedStatus: status,
      mediaUrls: urls,
      width: _int(data['width']),
      height: _int(data['height']),
    );
  }

  Future<Map<String, Object?>> _read(String path, Map<String, Object?> query) async {
    Object? decoded;
    try {
      decoded = jsonDecode(
        (await _client.getText('$weiboOrigin$path', headers: weiboHeaders, queryParameters: query)).body,
      );
    } on FormatException catch (error) {
      // An edge that answers an HTML login wall instead of json says nothing about the room; it says we are
      // not the viewer it expected.
      throw WeiboFailure('$path answered something that is not json', cause: error);
    }
    final json = jsonMap(decoded);
    if (json == null) {
      throw WeiboFailure('$path answered a non-object body');
    }
    final code = _int(json['code']);
    final error = _int(json['error_code']);
    if (code != weiboSuccessCode || error != 0) {
      // Both numbers travel: `code` is what the endpoint said (0 when it said nothing at all), `error_code` is
      // what the risk layer added.
      throw WeiboFailure('weibo refused the request', code: code, cause: error == 0 ? null : 'error_code $error');
    }
    return jsonMap(json['data']) ?? const <String, Object?>{};
  }

  /// Both identifier shapes occur on official watch pages; neither is a uid.
  static String validateLiveId(String value) {
    final result = value.trim();
    if (!RegExp(r'^[0-9]{1,32}$').hasMatch(result)) {
      throw WeiboFailure('not a weibo live id: "$value"');
    }
    return result;
  }

  static int _int(Object? value) => jsonInt(value) ?? 0;

  static int _ownerId(Object? value) {
    final id = jsonInt(value) ?? 0;
    if (id <= 0) {
      throw const WeiboFailure('room answer carries no owner uid');
    }
    return id;
  }

  static String? _image(Object? value) {
    final url = _mediaUrl(value);
    if (url == null) {
      return null;
    }
    return Uri.parse(url).path.toLowerCase().contains('.gif') ? null : url;
  }

  /// A media url, or null when the field is not one.
  ///
  /// Covers and avatars must carry no query - a `?param=` on an image address is how a rewrite shows up, and the
  /// v1 line rejected those outright. Play urls are the opposite case: weibo signs them as
  /// `…/a.flv?sign=1&wsTime=…`, and dropping a signed url because it is signed would leave an on-air room with
  /// nothing to open. Both still refuse credentials and a fragment, which are not media addresses the player
  /// should be handed.
  static String? _mediaUrl(Object? value, {bool allowQuery = false}) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !const <String>{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (!allowQuery && uri.query.isNotEmpty)) {
      return null;
    }
    return text;
  }
}
