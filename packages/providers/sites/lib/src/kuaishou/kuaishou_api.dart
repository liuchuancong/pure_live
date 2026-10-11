// Module: lib/src/kuaishou/kuaishou_api.dart
// Purpose: 快手直播的请求面:静态分区与其子分区、gameboard/non-gameboard 目录、推荐页、主播搜索、房间页内嵌状态与按 codec 分组的播放清单。
// Author: liuchuancong
// Created: 2026-10-11
//
// Provenance: endpoint knowledge, the `gameId` length rule, the per-codec manifest reading, the poster extension
// fix and the anonymous-session ladder follow the v1-maintained Kuaishou line (origin/master
// lib/shared/platforms/kuaishou/kuaishou_site.dart). Fresh implementation against the v2 capability contracts,
// not a file merge (UPSTREAM_REVIEW_POLICY.md).
//
// A site is two files (docs/architecture/package-architecture.md §2.1): this one owns the requests and how their
// answers are read, kuaishou_site.dart owns the capability answers. No model file - a room is the shared
// `LiveRoom`, and the intermediate shapes here are what the endpoints actually return.
//
// The rules that are worth more than the endpoint list:
//   * **the room is the streamer**. Kuaishou keys a live room on the anchor's id (`/u/<authorId>`), while the
//     `liveStreamId` is per broadcast. The ref is the author id; the stream id is a field. Keying the ref on the
//     stream id would orphan every favourite the moment the anchor goes off air and comes back with a new one.
//   * **the id's length picks the endpoint**: `gameboard/list` for short ids, `non-gameboard/list` for long ones.
//     That is the site's own split between a game and a non-game tag, and both take the id as `gameId`.
//   * **the manifest is read per codec, and codecs never merge**. An h264 row and an hevc row of the same name
//     are two menu entries, because a player that cannot decode H.265 has to be able to see and avoid it. Rows of
//     one name *and* one codec are one quality carrying several cdn lines (the site ships them as siblings).
//   * **a page that stopped counting reports no number**. v1 wrote `'0'` for an offline room's viewer count; here
//     a room that is not on air has `audience == null`, because "0 人看过" is a figure the site did not state.
//   * **`isLiving` that is neither true nor false is unknown**, not offline. A follow list that reads a missing
//     flag as "ended" stops polling a broadcast that is still up.
//   * **pull urls are kept byte for byte**. Only "absolute http(s) with no credentials" is required of them: the
//     v1 line never pinned a cdn host, and pinning one we have not sampled would drop real streams.

import 'dart:convert';
import 'dart:math';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import '../common/site_json.dart';

const String kuaishouSourceId = 'kuaishou.live';
const String kuaishouOrigin = 'https://live.kuaishou.com';
const String kuaishouApiPrefix = '$kuaishouOrigin/live_api/';

/// The device-registration ping the site's own web client fires once it holds a `did`. Best-effort in v1 and still
/// best-effort here: nothing reads its answer, and a failure of this endpoint never costs a room.
const String kuaishouTelemetryUrl = 'https://log-sdk.ksapisrv.com/rest/wd/common/log/collect/misc2';

/// The list endpoints' own page size. v1 sends `pageSize: 20` and the site answers 20 whatever the caller asked
/// for, so the number a pager does its arithmetic with is this one, not the request's.
const int kuaishouServerPageSize = 20;

/// The page size the sub-category listing is asked for, and the fill test that ends its paging loop - both the
/// site's own, carried over from v1.
const int kuaishouCategoryPageSize = 30;

/// An id this long or longer is a non-game tag and goes to the other endpoint. Not a guess about the id's shape:
/// it is the rule the v1 line used to pick between the two lists.
const int kuaishouGameBoardIdMax = 6;

/// How long a harvested anonymous session is kept. The site's own client does not refresh mid-session; reusing
/// one past its server-side life is what makes a room page answer without its state block.
const Duration kuaishouSessionLifetime = Duration(minutes: 30);

const String kuaishouUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36';

/// The json endpoints.
const Map<String, String> kuaishouApiHeaders = <String, String>{
  'user-agent': kuaishouUserAgent,
  'accept': 'application/json, text/plain, */*',
  'referer': '$kuaishouOrigin/',
};

/// The room page is a document and is only served complete to a client that asks for it as one. These are the
/// navigation headers the site's own page sends; the list endpoints do not use them.
const Map<String, String> kuaishouPageHeaders = <String, String>{
  'user-agent': kuaishouUserAgent,
  'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3',
  'sec-ch-ua': 'Google Chrome;v=107, Chromium;v=107, Not=A?Brand;v=24',
  'sec-ch-ua-platform': 'macOS',
  'sec-fetch-dest': 'document',
  'sec-fetch-mode': 'navigate',
  'sec-fetch-site': 'same-origin',
  'sec-fetch-user': '?1',
};

/// The extensions the image cdn answers for. Used only to decide whether to append `.jpg` to a poster the site
/// stored without one.
const Set<String> kuaishouImageExtensions = <String>{
  'svgz',
  'pjp',
  'png',
  'ico',
  'avif',
  'tiff',
  'tif',
  'jfif',
  'svg',
  'xbm',
  'pjpeg',
  'webp',
  'jpg',
  'jpeg',
  'bmp',
  'gif',
};

/// A kuaishou answer that is not the answer we asked for.
///
/// Named rather than a bare StateError because "the room does not exist", "the shape changed" and "the edge
/// refused us" need different handling upstream: the first is a fact to show, the second is a bug to chase, the
/// third is a retry.
final class KuaishouFailure implements Exception {
  const KuaishouFailure(this.message, {this.code, this.cause});

  final String message;
  final int? code;
  final Object? cause;

  @override
  String toString() =>
      'KuaishouFailure($message${code == null ? '' : ', code $code'}${cause == null ? '' : ': $cause'})';
}

/// One of the site's eight live groups. They are static in the site's own web client, so a page that fails to
/// read does not erase the menu.
final class KuaishouTopCategory {
  const KuaishouTopCategory({required this.id, required this.name});

  final String id;
  final String name;
}

const List<KuaishouTopCategory> kuaishouTopCategories = <KuaishouTopCategory>[
  KuaishouTopCategory(id: '1', name: '热门'),
  KuaishouTopCategory(id: '2', name: '网游'),
  KuaishouTopCategory(id: '3', name: '单机'),
  KuaishouTopCategory(id: '4', name: '手游'),
  KuaishouTopCategory(id: '5', name: '棋牌'),
  KuaishouTopCategory(id: '6', name: '娱乐'),
  KuaishouTopCategory(id: '7', name: '综合'),
  KuaishouTopCategory(id: '8', name: '文化'),
];

/// A browsable row under a group. Its [id] is what the directory endpoint wants as `gameId`, and [top] is where
/// that row sits in the site's own tree.
final class KuaishouSubCategory {
  const KuaishouSubCategory({required this.id, required this.name, required this.top, this.poster});

  final String id;
  final String name;
  final KuaishouTopCategory top;
  final String? poster;

  ContentCategory toContentCategory() => ContentCategory(id: id, name: name, parentId: top.id, icon: poster);
}

/// One quality of one codec, with its cdn urls.
///
/// [id] is the site's own words (the row's name) plus its ordering number and codec, so two codecs that the site
/// named alike still get different ids - and [SelectionRef] can therefore ask for the one the menu showed.
final class KuaishouVariant {
  const KuaishouVariant({
    required this.name,
    required this.sort,
    required this.codecRank,
    required this.urls,
    this.bitrateKbps,
  });

  /// The label as the site wrote it, with the codec suffix added for the H.265 rows.
  final String name;

  /// `level` when the row states one, else `bitrate`: the site's own ordering weight.
  final int sort;

  /// 0 for h264/avc, 1 for hevc/h265. The manifest's key says which, so this is evidence, not inference.
  final int codecRank;

  final List<String> urls;

  /// The bitrate only when the row carried one. A [sort] taken from `level` is not a bitrate and is not reported
  /// as one.
  final int? bitrateKbps;

  String get codec => codecRank == 1 ? 'hevc' : 'h264';

  bool get isHevc => codecRank == 1;

  String get id => name;

  bool get isPlayable => urls.isNotEmpty;
}

/// One room as an endpoint described it.
///
/// Three endpoints answer room-shaped rows (the two directory lists, the recommendation block, the room page) and
/// each states a different subset, so the fields are nullable rather than filled with a guess.
final class KuaishouRoom {
  const KuaishouRoom({
    required this.authorId,
    required this.state,
    this.liveStreamId,
    this.title,
    this.nick,
    this.avatar,
    this.cover,
    this.area,
    this.viewers,
    this.followers,
    this.introduction,
    this.notice,
    this.banned = false,
    this.variants = const <KuaishouVariant>[],
    this.emotes = const <String, String>{},
    this.cookie = '',
    this.restriction,
  });

  /// The streamer id the room is keyed on. Also what [toLiveRoom] puts in the ref.
  final String authorId;
  final LiveRoomState state;

  /// `liveStream.id` - per broadcast, so it travels as [LiveRoom.streamId] and never as the ref.
  final String? liveStreamId;
  final String? title;
  final String? nick;
  final String? avatar;
  final String? cover;
  final String? area;

  /// `watchingCount`: concurrent viewers, stated as such by the site's own field name.
  final int? viewers;
  final int? followers;
  final String? introduction;
  final String? notice;

  /// A banned account: the search endpoint reports it, and it is not the same fact as "offline".
  final bool banned;

  /// The parsed manifest. Empty means the answer carried nothing we are willing to open - which for a room that
  /// says it is on air is [LiveRestriction.unplayable], not offline.
  final List<KuaishouVariant> variants;

  /// The emoji panel from the room page, as `[code] -> url`. The socket sends the code; the surface draws the
  /// picture, so the table has to travel with the handshake material.
  final Map<String, String> emotes;

  /// The anonymous session in force when this answer was read. Not a credential: the same cookie the site hands
  /// any visitor, needed by the danmaku socket and by the media request.
  final String cookie;

  /// Computed by the reader that knows whether it looked at the manifest at all, rather than derived from
  /// [variants]: an answer that deliberately skipped the addresses (`withMedia: false`) has an empty list and must
  /// not be reported as a room that cannot be played.
  final LiveRestriction? restriction;

  LiveRoom toLiveRoom() => LiveRoom(
    ref: ContentRef(sourceId: kuaishouSourceId, contentId: authorId, kind: ContentKind.liveRoom),
    state: state,
    title: title ?? '',
    anchorName: nick,
    // Kuaishou does not distinguish the two: the room is the streamer. Leaving anchorId null says that out loud
    // instead of copying the same id into both slots.
    avatar: avatar,
    cover: cover,
    area: area,
    link: kuaishouRoomUrl(authorId),
    introduction: introduction,
    notice: notice,
    followers: followers,
    // An unstated count stays absent from the model rather than arriving as an audience of nobody.
    audience: viewers == null ? null : LiveAudience.ofMetric(viewers, LiveAudienceMetric.onlineViewers),
    restriction: restriction,
    streamId: liveStreamId,
    danmakuPayload: <String, Object?>{
      if (liveStreamId != null && !banned) 'liveStreamId': liveStreamId,
      if (cookie.isNotEmpty) 'cookie': cookie,
      if (emotes.isNotEmpty) 'emotes': emotes,
    },
    headers: <String, String>{if (cookie.isNotEmpty) 'cookie': cookie},
    sitePayload: const <String, Object?>{},
    extra: <String, Object?>{if (banned) 'banned': true},
  );

  AnchorSummary toAnchorSummary() {
    final room = ref();
    return AnchorSummary(
      ref: ContentRef(sourceId: kuaishouSourceId, contentId: authorId, kind: ContentKind.anchor),
      name: nick ?? '',
      avatar: avatar,
      fans: followers,
      currentRoom: state == LiveRoomState.live ? room : null,
      description: introduction,
      extra: <String, Object?>{if (banned) 'banned': true},
    );
  }

  ContentRef ref() => ContentRef(sourceId: kuaishouSourceId, contentId: authorId, kind: ContentKind.liveRoom);
}

/// The watch page for a streamer id.
String kuaishouRoomUrl(String authorId) => '$kuaishouOrigin/u/$authorId';

/// A streamer id: what the site puts in `/u/<id>`. Alphanumerics with `-`/`_`, 3..64 long.
String kuaishouAuthorId(String value) {
  final id = value.trim();
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_\-]{2,63}$').hasMatch(id)) {
    throw KuaishouFailure('not a kuaishou streamer id: "$id"');
  }
  return id;
}

/// The streamer id in a kuaishou url, or null when the url is not one. `/u/<id>` and nothing else - a profile or
/// a short-video link is not a live room and must not be resolved as one.
String? kuaishouRoomFromUri(Uri uri) {
  if (!const <String>{'http', 'https'}.contains(uri.scheme) ||
      uri.host != 'live.kuaishou.com' ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
    return null;
  }
  final parts = <String>[
    for (final part in uri.pathSegments)
      if (part.isNotEmpty) part,
  ];
  if (parts.length != 2 || parts.first != 'u') {
    return null;
  }
  try {
    return kuaishouAuthorId(parts.last);
  } on KuaishouFailure {
    return null;
  }
}

/// A category id the directory endpoints accept. Short ids are games, long ones are non-game tags; both are the
/// site's own tokens, so anything else (a name, an empty string) is refused here rather than sent and mis-read.
String kuaishouCategoryId(String value) {
  final id = value.trim();
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_\-]{0,63}$').hasMatch(id)) {
    throw KuaishouFailure('not a kuaishou category id: "$id"');
  }
  return id;
}

/// A poster url as the site stores it.
///
/// The room page keeps a bare url with no extension and the image cdn only answers once one is appended. The
/// extension is read off the **path**: v1 split the whole url on `.` and so judged `…/cover.jpg?x=1` to have no
/// extension, appending a second one to a url that already had it.
String? kuaishouPoster(Object? raw) {
  final value = kuaishouPicture(raw);
  if (value == null) {
    return null;
  }
  final path = Uri.parse(value).path;
  final dot = path.lastIndexOf('.');
  final slash = path.lastIndexOf('/');
  final extension = dot > slash ? path.substring(dot + 1).toLowerCase() : '';
  return kuaishouImageExtensions.contains(extension) ? value : '$value.jpg';
}

/// An absolute http(s) image url, or null. `//host/x` becomes `https://host/x`.
String? kuaishouPicture(Object? raw) {
  final value = _text(raw);
  if (value.isEmpty) {
    return null;
  }
  final candidate = value.startsWith('//') ? 'https:$value' : value;
  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      !const <String>{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return candidate;
}

/// The manifest as either shape the site ships it.
///
/// A room page sends `{h264: {...}, hevc: {...}}`; list and replay rows send one bare adaptation-set descriptor
/// in a list. Both arrive here, and both are read per codec: rows of the same name *and* codec merge into one
/// quality whose urls are cdn alternatives, while an h264 and an hevc row of the same name stay two qualities -
/// merging them would hand a viewer one label whose url their decoder cannot open.
List<KuaishouVariant> kuaishouQualities(Object? raw) {
  final descriptors = raw is List ? raw : <Object?>[raw];
  final merged = <String, _KuaishouDraft>{};

  for (final rawDescriptor in descriptors) {
    final descriptor = jsonMap(rawDescriptor);
    if (descriptor == null) {
      continue;
    }
    final sets = <_KuaishouCodecSet>[];
    final h264 = _firstRepresentations(descriptor, const <String>['h264', 'avc']);
    if (h264 != null) {
      sets.add(_KuaishouCodecSet(suffix: '', codecRank: 0, representations: h264));
    }
    final hevc = _firstRepresentations(descriptor, const <String>['hevc', 'h265']);
    if (hevc != null) {
      sets.add(_KuaishouCodecSet(suffix: ' · H.265', codecRank: 1, representations: hevc));
    }
    if (sets.isEmpty) {
      final bare = _representationsOf(descriptor);
      if (bare.isNotEmpty) {
        sets.add(_KuaishouCodecSet(suffix: '', codecRank: 0, representations: bare));
      }
    }

    for (final set in sets) {
      for (final rawRow in set.representations) {
        final row = jsonMap(rawRow);
        if (row == null) {
          continue;
        }
        final url = _pullUrl(row['url']);
        if (url == null) {
          continue;
        }
        final level = jsonInt(row['level']);
        final bitrate = jsonInt(row['bitrate']);
        final sort = level ?? bitrate ?? 0;
        final rawName = _firstText(<Object?>[row['name'], row['shortName'], row['qualityType']]) ?? '清晰度 $sort';
        final name = set.suffix.isEmpty ? rawName : '$rawName${set.suffix}';
        final draft = merged['$name\u0000$sort'];
        if (draft == null) {
          merged['$name\u0000$sort'] = _KuaishouDraft(
            name: name,
            sort: sort,
            codecRank: set.codecRank,
            bitrateKbps: bitrate,
            urls: <String>[url],
          );
        } else if (!draft.urls.contains(url)) {
          draft.urls.add(url);
        }
      }
    }
  }

  final drafts = merged.values.toList(growable: false)
    ..sort((_KuaishouDraft a, _KuaishouDraft b) {
      if (a.codecRank != b.codecRank) {
        return a.codecRank.compareTo(b.codecRank);
      }
      return b.sort.compareTo(a.sort);
    });
  return List<KuaishouVariant>.unmodifiable(<KuaishouVariant>[
    for (final draft in drafts)
      KuaishouVariant(
        name: draft.name,
        sort: draft.sort,
        codecRank: draft.codecRank,
        bitrateKbps: draft.bitrateKbps,
        urls: List<String>.unmodifiable(draft.urls),
      ),
  ]);
}

/// The representations of the first codec key the descriptor actually fills.
///
/// "First that has rows" matters: the site has shipped `h264` present-but-empty alongside a populated `avc`, and
/// reading the first key by name alone loses the stream.
List<Object?>? _firstRepresentations(Map<String, Object?> descriptor, List<String> keys) {
  for (final key in keys) {
    final rows = _representationsOf(jsonMap(descriptor[key]) ?? const <String, Object?>{});
    if (rows.isNotEmpty) {
      return rows;
    }
  }
  return null;
}

List<Object?> _representationsOf(Map<String, Object?> descriptor) {
  final adaptationSet = jsonMap(descriptor['adaptationSet']);
  final rows = adaptationSet == null ? descriptor['representation'] : adaptationSet['representation'];
  return rows is List ? rows : const <Object?>[];
}

/// A pull address. Absolute http(s) with no credentials, kept verbatim because the signature is in the query.
String? _pullUrl(Object? raw) {
  final value = _text(raw);
  if (value.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !const <String>{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return value;
}

/// `isLiving` as the page sends it: a bool, a 0/1 number, or the string of either. Anything else is the page not
/// saying, which is [LiveRoomState.unknown] rather than a room that stopped.
LiveRoomState kuaishouPageState(Object? raw) {
  if (raw is bool) {
    return raw ? LiveRoomState.live : LiveRoomState.ended;
  }
  final text = raw == null ? '' : '${raw}'.trim().toLowerCase();
  if (text == 'true' || text == '1') {
    return LiveRoomState.live;
  }
  if (text == 'false' || text == '0') {
    return LiveRoomState.ended;
  }
  return LiveRoomState.unknown;
}

/// One directory row. A row that names no streamer is dropped: it is not a room card, and one odd row must not
/// lose the page with it.
KuaishouRoom? kuaishouDirectoryRow(Object? raw) {
  final row = jsonMap(raw);
  if (row == null) {
    return null;
  }
  final author = jsonMap(row['author']) ?? const <String, Object?>{};
  final authorId = _optionalAuthorId(author['id']);
  if (authorId == null) {
    return null;
  }
  final gameInfo = jsonMap(row['gameInfo']) ?? const <String, Object?>{};
  final variants = kuaishouQualities(row['playUrls']);
  return KuaishouRoom(
    authorId: authorId,
    // A live grid row is on air by construction - that is what the endpoint lists.
    state: LiveRoomState.live,
    liveStreamId: _emptyToNull(_text(row['id'])),
    title: _oneLine(_text(row['caption'])),
    nick: _emptyToNull(_text(author['name'])),
    avatar: kuaishouPicture(author['avatar']),
    cover: kuaishouPoster(row['poster']),
    area: _emptyToNull(_text(gameInfo['name'])),
    viewers: jsonInt(row['watchingCount']),
    variants: variants,
    restriction: kuaishouGridRestriction(variants),
  );
}

/// What a live row says about being opened.
///
/// An empty manifest on a row the site itself lists as on air is a refusal by shape, not an ended broadcast -
/// which is the difference a room page has to show rather than a tile that spins.
LiveRestriction? kuaishouGridRestriction(List<KuaishouVariant> variants) =>
    variants.isEmpty ? LiveRestriction.unplayable : LiveRestriction.none;

/// One card of the recommendation block, which nests three deep: list → gameLiveInfo → liveInfo.
List<KuaishouRoom> kuaishouHomeCards(Map<String, Object?> info) {
  final groups = info['list'];
  if (groups is! List) {
    throw const KuaishouFailure('the recommendation answer carries no list');
  }
  final rooms = <KuaishouRoom>[];
  final seen = <String>{};
  for (final rawGroup in groups) {
    for (final rawGame in jsonList(jsonMap(rawGroup)?['gameLiveInfo'])) {
      for (final rawCard in jsonList(jsonMap(rawGame)?['liveInfo'])) {
        final card = jsonMap(rawCard);
        if (card == null) {
          continue;
        }
        final author = jsonMap(card['author']) ?? const <String, Object?>{};
        final gameInfo = jsonMap(card['gameInfo']) ?? const <String, Object?>{};
        final authorId = _optionalAuthorId(author['id']);
        if (authorId == null || !seen.add(authorId)) {
          continue;
        }
        final description = _text(author['description']);
        final variants = kuaishouQualities(card['playUrls']);
        rooms.add(
          KuaishouRoom(
            authorId: authorId,
            state: LiveRoomState.live,
            liveStreamId: _emptyToNull(_text(card['id'])),
            title: _emptyToNull(_oneLine(description)),
            nick: _emptyToNull(_text(author['name'])),
            avatar: kuaishouPicture(author['avatar']),
            cover: kuaishouPoster(gameInfo['poster']),
            area: _emptyToNull(_text(gameInfo['name'])),
            viewers: jsonInt(card['watchingCount']),
            introduction: _emptyToNull(description),
            notice: _emptyToNull(description),
            variants: variants,
            restriction: kuaishouGridRestriction(variants),
          ),
        );
      }
    }
  }
  return rooms;
}

/// A sub-category row under one of the static groups.
KuaishouSubCategory? kuaishouSubCategoryRow(Object? raw, KuaishouTopCategory top) {
  final row = jsonMap(raw);
  final id = _text(row?['id']);
  final name = _text(row?['name']);
  if (row == null || id.isEmpty || name.isEmpty || !RegExp(r'^[A-Za-z0-9][A-Za-z0-9_\-]{0,63}$').hasMatch(id)) {
    return null;
  }
  return KuaishouSubCategory(id: id, name: name, top: top, poster: kuaishouPoster(row['poster']));
}

/// The streamer search rows. The endpoint indexes people and reports whether each is live; it states no viewer
/// count, and an absent one stays absent rather than rendering as "0 人在看".
List<KuaishouRoom> kuaishouAuthorRows(Object? json) {
  final list = jsonMap(jsonMap(json)?['data'])?['list'];
  if (list is! List) {
    throw const KuaishouFailure('the streamer search carries no list');
  }
  final seen = <String>{};
  return <KuaishouRoom>[
    for (final raw in list)
      if (_authorRow(raw) case final KuaishouRoom room when seen.add(room.authorId)) room,
  ];
}

KuaishouRoom? _authorRow(Object? raw) {
  final author = jsonMap(raw);
  if (author == null) {
    return null;
  }
  final authorId = _optionalAuthorId(author['id']);
  if (authorId == null) {
    return null;
  }
  final banned = jsonMap(author['bannedStatus'])?['banned'] == true;
  final counts = jsonMap(author['counts']);
  final description = _emptyToNull(_text(author['description']));
  return KuaishouRoom(
    authorId: authorId,
    state: switch ((banned, author['living'])) {
      (true, _) => LiveRoomState.ended,
      (_, true) => LiveRoomState.live,
      // A row that does not carry `living` told us nothing; unknown keeps a follow list polling it.
      (_, null) => LiveRoomState.unknown,
      _ => LiveRoomState.ended,
    },
    // A search row has no title of its own; the surface shows the name, which is what v1 did.
    title: _text(author['name']),
    nick: _emptyToNull(_text(author['name'])),
    avatar: kuaishouPicture(author['avatar']),
    cover: kuaishouPicture(author['avatar']),
    introduction: description,
    followers: jsonInt(counts?['fan']),
    banned: banned,
    // The search row states no manifest, so the only refusal it can report is the account's own.
    restriction: banned ? LiveRestriction.unplayable : null,
  );
}

/// The room page's embedded state, read by matching brackets instead of by cutting at the first `;`.
///
/// v1 used `window\.__INITIAL_STATE__=(.*?);`, whose lazy stop is the **first** semicolon anywhere after the
/// marker - including one inside a streamer's own title - which truncated the literal and made such a room
/// unreadable. Here the assignment's opening object is closed by counting brackets, string contents skipped.
///
/// The site serialises a JS object literal, so bare `undefined` appears where json needs null. It is replaced
/// only in value position (`:`/`,`/`[` before it, `,`/`]`/`}` after it): v1 replaced every occurrence, which also
/// rewrote the word inside a title as `null`.
Map<String, Object?> kuaishouInitialState(String html) {
  const marker = 'window.__INITIAL_STATE__=';
  final at = html.indexOf(marker);
  if (at < 0) {
    throw const KuaishouFailure('the room page carries no embedded state block');
  }
  final start = html.indexOf('{', at + marker.length);
  if (start < 0) {
    throw const KuaishouFailure('the room page state block does not open');
  }
  var depth = 0;
  var inString = false;
  var escaped = false;
  var end = -1;
  for (var index = start; index < html.length; index++) {
    final char = html[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{' || char == '[') {
      depth++;
    } else if (char == '}' || char == ']') {
      depth--;
      if (depth == 0) {
        end = index + 1;
        break;
      }
    }
  }
  if (end < 0) {
    throw const KuaishouFailure('the room page state block never closes');
  }
  final literal = html.substring(start, end);
  Object? decoded;
  try {
    decoded = jsonDecode(
      literal.replaceAllMapped(
        RegExp(r'([:\[,])\s*undefined(\s*[,\]}])'),
        (Match match) => '${match.group(1)} null${match.group(2)}',
      ),
    );
  } on FormatException catch (error) {
    throw KuaishouFailure('the room page state is not readable json', cause: error);
  }
  final state = jsonMap(decoded);
  if (state == null) {
    throw const KuaishouFailure('the room page state is not an object');
  }
  return state;
}

/// The room row inside the page state. `liveroom.playList` is the whole answer; a page that lists no broadcast is
/// a page about a room we cannot describe, and v1's crash-on-empty was right to refuse it silently.
Map<String, Object?> kuaishouPageRoom(Map<String, Object?> state) {
  final liveRoom = jsonMap(state['liveroom']);
  if (liveRoom == null) {
    throw const KuaishouFailure('the room page has no liveroom block');
  }
  final playList = liveRoom['playList'];
  if (playList is! List || playList.isEmpty) {
    throw const KuaishouFailure('the room page lists no broadcast');
  }
  final entry = jsonMap(playList.first);
  if (entry == null) {
    throw const KuaishouFailure('the first playList row is not an object');
  }
  return entry;
}

/// The emoji panel `[{code}] -> url` from the page state.
///
/// Codes shorter than `[x]` and non-urls are skipped rather than thrown away loudly: the panel is a display
/// nicety, and a room whose emoji config changed shape is still a room you can watch.
Map<String, String> kuaishouEmotes(Map<String, Object?> state) {
  final inner = jsonMap(jsonMap(state['pcConfig'])?['pcConfig']);
  final panel = jsonMap(jsonMap(inner?['config'])?['pcLive.webConfig.emojiPanel']);
  if (panel == null || panel.isEmpty) {
    return const <String, String>{};
  }
  final table = <String, String>{};
  for (final entry in panel.entries) {
    final code = '${entry.key}';
    if (code.length <= 2 || !code.startsWith('[') || !code.endsWith(']')) {
      continue;
    }
    if (kuaishouPicture(entry.value) case final String url) {
      table[code] = url;
    }
  }
  return Map<String, String>.unmodifiable(table);
}

/// The device-registration body the site's logger posts once it holds a `did`.
///
/// v1's payload also carried a fabricated page view of 王者荣耀 with two hardcoded uuids. We send the device and
/// app blocks and no invented page: a telemetry row that claims the visitor opened a game they never opened is
/// worse than not claiming anything, and the endpoint is best-effort either way.
Map<String, Object?> kuaishouTelemetry({required String did, required DateTime now, required String sessionId}) {
  if (did.isEmpty) {
    throw const KuaishouFailure('no device id to register');
  }
  return <String, Object?>{
    'common': <String, Object?>{
      'identity_package': <String, Object?>{'device_id': did, 'global_id': ''},
      'app_package': <String, Object?>{
        'language': 'zh-CN',
        'platform': 10,
        'container': 'WEB',
        'product_name': 'KS_GAME_LIVE_PC',
      },
      'device_package': <String, Object?>{
        'os_version': 'NT 6.1',
        'model': 'Windows',
        'ua': 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36',
      },
      'need_encrypt': 'false',
      'network_package': <String, Object?>{'type': 3},
      'h5_extra_attr': '{"sdk_name":"webLogger","sdk_version":"3.9.49","sdk_bundle":"log.common.js","domain":"https://live.kuaishou.com"}',
      'global_attr': '{}',
    },
    'logs': <Object?>[
      <String, Object?>{
        'client_timestamp': now.millisecondsSinceEpoch,
        'client_increment_id': 1000 + now.millisecondsSinceEpoch % 9000,
        'session_id': sessionId,
        'time_zone': 'GMT+08:00',
      },
    ],
  };
}

/// A `Cookie:` header built from a response's `set-cookie` values.
///
/// Attributes (`Expires`, `Path`, `HttpOnly`, …) are not cookies and are skipped; the same name twice means the
/// later write won, which is what RFC 6265 says a client stores.
String kuaishouCookieHeader(List<String> setCookie) {
  final byName = <String, String>{};
  for (final raw in setCookie) {
    final pair = raw.split(';').first;
    final split = pair.indexOf('=');
    if (split <= 0) {
      continue;
    }
    final name = pair.substring(0, split).trim();
    final value = pair.substring(split + 1).trim();
    if (name.isEmpty || value.isEmpty) {
      continue;
    }
    byName[name] = value;
  }
  return <String>[for (final entry in byName.entries) '${entry.key}=${entry.value}'].join('; ');
}

String? _optionalAuthorId(Object? raw) {
  final value = _text(raw);
  if (value.isEmpty) {
    return null;
  }
  try {
    return kuaishouAuthorId(value);
  } on KuaishouFailure {
    return null;
  }
}

String? _firstText(List<Object?> values) {
  for (final value in values) {
    final text = _text(value);
    if (text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

String _text(Object? raw) => raw is String ? raw.trim() : (raw == null ? '' : '${raw}'.trim());

String? _emptyToNull(String value) => value.isEmpty ? null : value;

String _oneLine(String value) => value.replaceAll(RegExp(r'\s*\n\s*'), ' ');

final class _KuaishouCodecSet {
  const _KuaishouCodecSet({required this.suffix, required this.codecRank, required this.representations});

  final String suffix;
  final int codecRank;
  final List<Object?> representations;
}

final class _KuaishouDraft {
  _KuaishouDraft({
    required this.name,
    required this.sort,
    required this.codecRank,
    required this.bitrateKbps,
    required this.urls,
  });

  final String name;
  final int sort;
  final int codecRank;
  final int? bitrateKbps;
  final List<String> urls;
}

final class _KuaishouPage {
  const _KuaishouPage(this.state, this.cookie);

  final Map<String, Object?> state;
  final String cookie;
}

/// The Kuaishou live client.
final class KuaishouApi {
  KuaishouApi({NetworkClient? client, String? cookie, Clock? clock, Random? random})
    : _client = client ?? NetworkClient(),
      _ownsClient = client == null,
      _configuredCookie = (cookie ?? '').trim(),
      _clock = clock ?? systemClock,
      _random = random ?? Random.secure();

  final NetworkClient _client;
  final bool _ownsClient;

  /// A cookie an operator pasted, which wins over whatever the site handed out.
  final String _configuredCookie;
  final Clock _clock;
  final Random _random;

  String _sessionCookie = '';
  DateTime? _sessionUpdatedAt;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// The cookie requests go out with. A harvested session is only used inside its own lifetime.
  String get _cookie {
    if (_configuredCookie.isNotEmpty) {
      return _configuredCookie;
    }
    final updated = _sessionUpdatedAt;
    if (updated == null || _sessionCookie.isEmpty) {
      return '';
    }
    return _clock().difference(updated) < kuaishouSessionLifetime ? _sessionCookie : '';
  }

  /// The browsable categories: every static group's sub-categories.
  ///
  /// A group whose listing fails still contributes nothing rather than an error, because its children are
  /// additive - but when *every* group fails the menu is a schema change, not a site with no categories, and
  /// that is reported as one.
  Future<List<KuaishouSubCategory>> categories() async {
    final found = <String, KuaishouSubCategory>{};
    Object? firstError;
    var failures = 0;
    for (final top in kuaishouTopCategories) {
      try {
        for (final category in await _subCategories(top)) {
          found.putIfAbsent(category.id, () => category);
        }
      } on Object catch (error) {
        failures++;
        firstError ??= error;
      }
    }
    if (failures == kuaishouTopCategories.length) {
      throw firstError is KuaishouFailure
          ? firstError
          : KuaishouFailure('no group answered its sub-category listing', cause: firstError);
    }
    return found.values.toList(growable: false);
  }

  Future<List<KuaishouSubCategory>> _subCategories(KuaishouTopCategory top, {int maxPages = 20}) async {
    final rows = <KuaishouSubCategory>[];
    for (var page = 1; page <= maxPages; page++) {
      final info = await _data(
        'category/data',
        query: <String, String>{'type': top.id, 'page': '$page', 'size': '$kuaishouCategoryPageSize'},
      );
      final list = info['list'];
      if (list is! List) {
        throw KuaishouFailure('group ${top.id} answered without a sub-category list');
      }
      for (final raw in list) {
        if (kuaishouSubCategoryRow(raw, top) case final KuaishouSubCategory category) {
          rows.add(category);
        }
      }
      // The v1 loop condition, kept: a short page is the end of the group.
      if (list.length < kuaishouCategoryPageSize) {
        break;
      }
    }
    return rows;
  }

  /// One page of a category's live grid.
  Future<List<KuaishouRoom>> directory({required String categoryId, int page = 1}) async {
    if (page < 1 || page > 10000) {
      throw const KuaishouFailure('directory pages are 1..10000');
    }
    final id = kuaishouCategoryId(categoryId);
    final api = id.length <= kuaishouGameBoardIdMax ? 'gameboard/list' : 'non-gameboard/list';
    final info = await _data(
      api,
      query: <String, String>{'filterType': '0', 'pageSize': '$kuaishouServerPageSize', 'gameId': id, 'page': '$page'},
    );
    final rows = info['list'];
    if (rows is! List) {
      throw KuaishouFailure('$api answered without a list');
    }
    final seen = <String>{};
    return <KuaishouRoom>[
      for (final raw in rows)
        if (kuaishouDirectoryRow(raw) case final KuaishouRoom room when seen.add(room.authorId)) room,
    ];
  }

  /// The recommendation block. The endpoint takes no page parameter, so this is one shot rather than a paged
  /// list, and a caller asking for a second page gets no request and no items.
  Future<List<KuaishouRoom>> home() async {
    final info = await _data('home/list');
    return kuaishouHomeCards(info);
  }

  /// Streamer search. Rows carry an on-air flag but no manifest, so they are listed with their state and nothing
  /// to play until the room page is read.
  Future<List<KuaishouRoom>> search(String keyword, {int page = 1}) async {
    final term = keyword.trim();
    if (term.isEmpty || term.length > 100 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(term)) {
      throw const KuaishouFailure('a search term must be 1-100 printable characters');
    }
    if (page < 1 || page > 10000) {
      throw const KuaishouFailure('search pages are 1..10000');
    }
    final json = await _json(
      'search/author',
      query: <String, String>{'keyword': term, 'page': '$page', 'lssid': ''},
      headers: <String, String>{
        ...kuaishouApiHeaders,
        'referer': '$kuaishouOrigin/search?keyword=${Uri.encodeQueryComponent(term)}',
      },
    );
    return kuaishouAuthorRows(json);
  }

  /// The room page, with its pull addresses unless [withMedia] is false.
  ///
  /// Asked anonymously first. A page that answers without its state block is retried once, with whatever cookie
  /// the first response handed out - that is the shape of the site's own ladder, and it stops there: a room that
  /// still has no block after one cookie-bearing request is either gone or changed, and paging on top of it would
  /// be a retry storm against the endpoint that refused us.
  Future<KuaishouRoom> room(String input, {bool withMedia = true}) async {
    final id = kuaishouAuthorId(input);
    final first = await _page(id, cookie: _cookie);
    try {
      return _roomFromPage(first, askedId: id, withMedia: withMedia);
    } on KuaishouFailure {
      final harvested = first.cookie;
      if (harvested.isEmpty || _configuredCookie.isNotEmpty) {
        rethrow;
      }
      final second = await _page(id, cookie: _mergeCookies(_cookie, harvested));
      return _roomFromPage(second, askedId: id, withMedia: withMedia);
    }
  }

  KuaishouRoom _roomFromPage(_KuaishouPage page, {required String askedId, required bool withMedia}) {
    final entry = kuaishouPageRoom(page.state);
    final liveStream = jsonMap(entry['liveStream']) ?? const <String, Object?>{};
    final author = jsonMap(entry['author']) ?? const <String, Object?>{};
    final gameInfo = jsonMap(entry['gameInfo']) ?? const <String, Object?>{};
    final pageId = _optionalAuthorId(author['id']) ?? askedId;
    if (pageId != askedId) {
      throw KuaishouFailure('the room page answers about $pageId while asking about $askedId');
    }
    final state = kuaishouPageState(entry['isLiving']);
    // The viewer number is only meaningful while the page says the room is on air; an offline page's count is the
    // last one it broadcast, and showing it as current would be our arithmetic, not the site's.
    final viewers = state == LiveRoomState.live ? jsonInt(gameInfo['watchingCount']) : null;
    final description = _text(author['description']);
    final variants = withMedia ? kuaishouQualities(liveStream['playUrls']) : const <KuaishouVariant>[];
    return KuaishouRoom(
      authorId: askedId,
      state: state,
      liveStreamId: _emptyToNull(_text(liveStream['id'])),
      title: _emptyToNull(_oneLine(description)),
      nick: _emptyToNull(_text(author['name'])),
      avatar: kuaishouPicture(author['avatar']),
      cover: kuaishouPoster(liveStream['poster']),
      area: _emptyToNull(_text(gameInfo['name'])),
      viewers: viewers,
      introduction: _emptyToNull(description),
      notice: _emptyToNull(description),
      variants: variants,
      restriction: switch ((state, withMedia)) {
        // A read that deliberately skipped the manifest has no evidence about playability to report.
        (_, false) => null,
        // An offline page's addresses belong to the last broadcast: not a restriction, just nothing to open.
        (LiveRoomState.ended, true) => null,
        (LiveRoomState.live, true) => kuaishouGridRestriction(variants),
        // Unknown with an address means the page shipped something to try; without one it said nothing either way.
        (_, true) => variants.isEmpty ? null : LiveRestriction.none,
      },
      emotes: kuaishouEmotes(page.state),
      cookie: _cookie.isNotEmpty ? _cookie : page.cookie,
    );
  }

  Future<_KuaishouPage> _page(String id, {required String cookie}) async {
    final response = await _client.getText(
      kuaishouRoomUrl(id),
      headers: <String, String>{...kuaishouPageHeaders, if (cookie.isNotEmpty) 'cookie': cookie},
    );
    if (response.statusCode != 200) {
      throw KuaishouFailure('the room page answered ${response.statusCode}', code: response.statusCode);
    }
    final harvested = kuaishouCookieHeader(response.bag.all('set-cookie'));
    if (harvested.isNotEmpty) {
      _sessionCookie = harvested;
      _sessionUpdatedAt = _clock();
      unawaitedTelemetry(harvested);
    }
    return _KuaishouPage(kuaishouInitialState(response.body), harvested);
  }

  /// The best-effort device registration the site's own client sends once it has a `did`. Its answer is never
  /// read, and a failure must not cost a room - which is why this is fire-and-forget rather than awaited.
  void unawaitedTelemetry(String cookieHeader) {
    final did = _cookieValue(cookieHeader, 'did');
    if (did == null) {
      return;
    }
    final body = kuaishouTelemetry(did: did, now: _clock(), sessionId: _newUuid());
    _client
        .postJson('$kuaishouTelemetryUrl?v=3.9.49&kpn=KS_GAME_LIVE_PC', body, headers: kuaishouApiHeaders)
        .then(
          (Object? _) {},
          // Swallowing this is deliberate; the room path does not wait for telemetry and must not fail because of it.
          onError: (Object _) {},
        );
  }

  String? _cookieValue(String header, String name) {
    for (final part in header.split(';')) {
      final split = part.indexOf('=');
      if (split > 0 && part.substring(0, split).trim() == name) {
        return part.substring(split + 1).trim();
      }
    }
    return null;
  }

  String _newUuid() {
    const hex = '0123456789abcdef';
    final bytes = List<String>.generate(16, (_) => hex[_random.nextInt(16)]);
    return '${bytes.take(4).join()}${bytes.skip(4).take(2).join()}${bytes.skip(6).take(2).join()}'
        '${bytes.skip(8).take(2).join()}${bytes.skip(10).join()}';
  }

  /// The `data` block of a `live_api` answer.
  ///
  /// Every list endpoint wraps its rows in `data`, and an envelope without one is not an empty answer: reading a
  /// missing `data` as "no rooms" is how a changed envelope turns a live grid into a blank page.
  Future<Map<String, Object?>> _data(String path, {Map<String, String>? query}) async {
    final data = jsonMap((await _json(path, query: query))['data']);
    if (data == null) {
      throw KuaishouFailure('$path answered without a data block');
    }
    return data;
  }

  Future<Map<String, Object?>> _json(String path, {Map<String, String>? query, Map<String, String>? headers}) async {
    final response = await _client.getText(
      '$kuaishouApiPrefix$path',
      headers: headers ?? kuaishouApiHeaders,
      queryParameters: query,
    );
    if (response.statusCode != 200) {
      throw KuaishouFailure('$path answered ${response.statusCode}', code: response.statusCode);
    }
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      // An edge that answers a block page instead of json is a failure to name, not a crash in the caller.
      throw KuaishouFailure('$path answered something that is not json', cause: error);
    }
    final data = jsonMap(decoded);
    if (data == null) {
      throw const KuaishouFailure('the answer is not a json object');
    }
    return data;
  }
}

String _mergeCookies(String existing, String added) {
  final byName = <String, String>{};
  for (final header in <String>[existing, added]) {
    for (final part in header.split(';')) {
      final split = part.indexOf('=');
      if (split > 0) {
        final name = part.substring(0, split).trim();
        final value = part.substring(split + 1).trim();
        if (name.isNotEmpty && value.isNotEmpty) {
          byName[name] = value;
        }
      }
    }
  }
  return <String>[for (final entry in byName.entries) '${entry.key}=${entry.value}'].join('; ');
}
