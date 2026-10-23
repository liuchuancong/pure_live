import 'package:live_sites/src/common/normalization/site_counts.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/platforms/acfun/acfun_manifest.dart';
import 'package:live_sites/src/platforms/acfun/api/acfun_endpoints.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_html.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_json.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_play_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The broadcast behind a live room, apart from its identity (the author id):
/// the `liveId` (new with every broadcast), the qualities `startPlay` offered
/// and when the answer arrived (the origin of the URLs' leases). It rides in
/// the room's transient stream handle.
final class AcfunRoomData {
  /// Wraps the stream handle.
  const AcfunRoomData({required this.liveId, required this.qualities, required this.issuedAt, this.startedAt});

  /// The broadcast id.
  final String liveId;

  /// The qualities, best first.
  final List<AcfunQuality> qualities;

  /// When the answer arrived.
  final DateTime issuedAt;

  /// When the broadcast started (`liveStartTime`), or null.
  final DateTime? startedAt;
}

/// One gift of AcFun's gift table (`gift/list`): what the danmaku's gift
/// signals, which carry only the id, are named and priced by.
final class AcfunGiftInfo {
  /// Creates the entry.
  const AcfunGiftInfo({required this.id, required this.name, required this.price, this.banana = false, this.iconUrl});

  /// `giftId`, the id the gift signal sends (`1` is the banana).
  final String id;

  /// `giftName` (`香蕉`, `快乐水`).
  final String name;

  /// `giftPrice`: the price of one, in AC coins (ten to a yuan) or, for a
  /// [banana] gift, in bananas; 0 or more.
  final int price;

  /// Paid in bananas: the platform's free currency, so the gift is free.
  final bool banana;

  /// The first `webpPicList` URL, else the first of `pngPicList`.
  final String? iconUrl;

  @override
  String toString() => 'AcfunGiftInfo($id $name, $price ${banana ? 'bananas' : 'AC coins'})';
}

/// The gifts of an AcFun room's danmaku, by gift id.
final class AcfunGiftCatalog {
  /// Creates the catalogue.
  const AcfunGiftCatalog(this._gifts);

  /// No gifts.
  static const AcfunGiftCatalog empty = AcfunGiftCatalog({});

  final Map<String, AcfunGiftInfo> _gifts;

  /// The gift of [id], or null.
  AcfunGiftInfo? operator [](String id) => _gifts[id];

  /// How many gifts.
  int get length => _gifts.length;

  /// Whether it has no gifts.
  bool get isEmpty => _gifts.isEmpty;

  @override
  String toString() => 'AcfunGiftCatalog($length)';
}

/// What one `startPlay` answer carried: the broadcast (null for a paid show
/// this viewer has no ticket for), the restriction it says, the danmaku
/// tickets and the `enterRoomAttach` the room entry echoes.
typedef AcfunPlayResult = ({
  AcfunRoomData? data,
  LiveRestriction restriction,
  List<String> tickets,
  String enterRoomAttach,
});

/// Pure parsing of AcFun's JSON answers and of its search page: the catalog,
/// the directory, the room detail, the visitor session, the gift table and the
/// playback answer (the stream table itself is in [AcfunPlayParser]).
///
/// A card whose author does not check out is left out rather than guessed at:
/// AcFun echoes the `authorId` it answered for, and a page that mixes in
/// another author would otherwise land a follow on the wrong room.
abstract final class AcfunRoomParser {
  /// `api/channel/list` with `count=1`: the areas of `channelFilters` in
  /// answer order, one per (type, id). `全部` ([AcfunEndpoints.allFilterId])
  /// lists the same rooms as the recommendations and is left out. [typeName]
  /// is the parent category's name. An answer with no area filter is
  /// api-changed (the catalog would silently empty).
  static List<LiveArea> areas(String body, {required String typeName, int status = 200}) {
    final root = AcfunJson.root(body, status: status, what: 'channel/list');
    _listData(root);
    final groups = AcfunJson.list(AcfunJson.object(root['channelFilters'])?['liveChannelDisplayFilters']);
    if (groups.isEmpty) {
      throw AcfunFailure(AcfunFailureKind.apiChanged, 'channel/list: no channelFilters (${AcfunJson.snippet(body)})');
    }
    final seen = <String>{};
    final areas = <LiveArea>[];
    for (final group in groups) {
      for (final raw in AcfunJson.list(AcfunJson.object(group)?['displayFilters'])) {
        final filter = AcfunJson.object(raw);
        if (filter == null) continue;
        final type = AcfunJson.count(filter['filterType']);
        final id = AcfunJson.count(filter['filterId']);
        final name = AcfunJson.text(filter['name']);
        if (type == null || id == null || id == AcfunEndpoints.allFilterId || name.isEmpty || !seen.add('$type:$id')) {
          continue;
        }
        areas.add(
          LiveArea.normalized(
            platform: acfunSiteId,
            // The filter a page of this area asks for is the (type, id) pair,
            // and the contract hands a page request only the area id, so the
            // id carries both.
            areaId: '$type:$id',
            areaName: name,
            parentAreaName: typeName,
            iconUrl: imageUrl(filter['cover']),
          ),
        );
      }
    }
    if (areas.isEmpty) {
      throw AcfunFailure(AcfunFailureKind.apiChanged, 'channel/list: no area filters (${AcfunJson.snippet(body)})');
    }
    return areas;
  }

  /// `api/channel/list`: the rooms of one page and the opaque cursor of the
  /// next; `no_more` or an empty cursor ends the list.
  static ({List<LiveRoom> rooms, String? next}) directory(String body, {int status = 200}) {
    final data = _listData(AcfunJson.root(body, status: status, what: 'channel/list'));
    final rooms = [
      for (final raw in data.list)
        if (AcfunJson.object(raw) case final item?)
          if (AcfunJson.text(item['authorId']) case final id when AcfunEndpoints.isAuthorId(id))
            if (_identity(item, id)) room(item, id),
    ];
    return (rooms: rooms, next: data.cursor.isEmpty || data.cursor == 'no_more' ? null : data.cursor);
  }

  /// `api/live/info?authorId=`: the room of [authorId] (the requested id stays
  /// the identity). Live when it has a `liveId`, offline otherwise. An unknown
  /// author (no user, `user.id` "0", no name) is not-found; a `result` other
  /// than 0, or an answer for another author, is api-changed. The channel's
  /// signature is the introduction, with the character references the site
  /// writes decoded.
  static LiveRoom roomDetail(String body, {required String authorId, int status = 200}) {
    final root = AcfunJson.root(body, status: status, what: 'live/info');
    if (AcfunJson.intOf(root['result']) != 0) {
      throw AcfunFailure(
        AcfunFailureKind.apiChanged,
        'live/info: result ${root['result']} (${AcfunJson.snippet(body)})',
      );
    }
    final user = AcfunJson.object(root['user']);
    final userId = AcfunJson.text(user?['id']);
    if (user == null || user.isEmpty || userId.isEmpty || userId == '0' || AcfunJson.text(user['name']).isEmpty) {
      throw AcfunFailure(AcfunFailureKind.notFound, 'live/info: no author $authorId');
    }
    if (!_identity(root, authorId)) {
      throw AcfunFailure(
        AcfunFailureKind.apiChanged,
        'live/info: answered author ${root['authorId']}/$userId for $authorId',
      );
    }
    final parsed = room(root, authorId);
    final signature = acfunHtmlEntities(AcfunJson.text(user['signature']));
    return parsed.rebuild(
      (b) => b..content.replace(parsed.content.rebuild((b) => b..introduction = signature.isEmpty ? null : signature)),
    );
  }

  /// A room card or detail: the online count as concurrent viewers, the
  /// followers as the site writes them. A live room also has its start
  /// (`createTime`) and restriction; an offline one neither.
  static LiveRoom room(Map<String, dynamic> item, String authorId) {
    final user = AcfunJson.object(item['user']) ?? const <String, dynamic>{};
    final covers = AcfunJson.listOf(item['coverUrls']);
    final type = AcfunJson.object(item['type']);
    final live = AcfunJson.text(item['liveId']).isNotEmpty;
    final viewers = AcfunJson.count(item['onlineCount']);
    final followers = parseAudienceNumberOrNull(AcfunJson.text(user['fanCountValue']));
    return LiveRoom.normalized(
      platform: acfunSiteId,
      roomId: authorId,
      content: RoomContent.of(
        title: AcfunJson.text(item['title']),
        coverUrl: covers == null || covers.isEmpty ? '' : imageUrl(covers.first),
      ),
      anchor: LiveAnchor.normalized(
        platform: acfunSiteId,
        anchorId: authorId,
        name: AcfunJson.text(user['name']),
        avatarUrl: imageUrl(user['headUrl']),
        followerCount: followers,
      ),
      area: type == null || AcfunJson.text(type['name']).isEmpty ? null : _area(type),
      audience: RoomAudience.of(onlineViewers: viewers, primaryMetric: LiveAudienceMetricType.onlineViewers),
      broadcast: RoomBroadcast.of(
        liveStatus: live ? LiveStatus.live : LiveStatus.offline,
        startedAt: live ? startedAt(item['createTime']) : null,
        restriction: live ? restriction(item) : null,
      ),
      links: RoomLinks.of(webUrl: AcfunEndpoints.roomPageUrl(authorId)),
    );
  }

  /// A live room's restriction, read from the fields the web player reads: a
  /// paid show (`paidShowUuid`) is [LiveRestriction.paid] unless this viewer
  /// bought it (`paidShowUserBuyStatus`, never true for the anonymous
  /// visitor). An answer with the paid-show fields and no show has no
  /// restriction; one without them says nothing (null).
  static LiveRestriction? restriction(Map<String, dynamic> item) {
    if (AcfunJson.text(item['paidShowUuid']).isNotEmpty) {
      return item['paidShowUserBuyStatus'] == true ? LiveRestriction.none : LiveRestriction.paid;
    }
    return item.containsKey('paidShowUserBuyStatus') ? LiveRestriction.none : null;
  }

  /// When a broadcast started, from `createTime` or `liveStartTime` (epoch
  /// milliseconds); null for 0, negatives, values that are not milliseconds
  /// (before 2001 or after 2286, such as a time in seconds) and anything that
  /// is not an integer.
  static DateTime? startedAt(Object? value) => switch (AcfunJson.intOf(value)) {
    final int milliseconds when milliseconds >= 1000000000000 && milliseconds < 10000000000000 =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
    _ => null,
  };

  /// `visitor/login`: the anonymous session, logged in with device id
  /// [deviceId]. A `result` other than 0 is risk control; no user id or no
  /// token is api-changed. `acSecurity` is optional (only the danmaku link uses
  /// it).
  static AcfunVisitor visitor(String body, {required String deviceId, int status = 200}) {
    final root = AcfunJson.root(body, status: status, what: 'visitor/login');
    final result = AcfunJson.intOf(root['result']);
    if (result == null) {
      throw AcfunFailure(AcfunFailureKind.apiChanged, 'visitor/login: no result (${AcfunJson.snippet(body)})');
    }
    if (result != 0) throw AcfunFailure(AcfunFailureKind.riskControl, 'visitor/login: result $result');
    final userId = AcfunJson.text(root['userId']);
    final token = AcfunJson.text(root['acfun.api.visitor_st']);
    if (!AcfunEndpoints.isAuthorId(userId) || token.isEmpty) {
      throw const AcfunFailure(AcfunFailureKind.apiChanged, 'visitor/login: incomplete session');
    }
    final security = AcfunJson.text(root['acSecurity']);
    return AcfunVisitor(userId: userId, deviceId: deviceId, token: token, security: security.isEmpty ? null : security);
  }

  /// `startPlay`: the broadcast, its qualities and the danmaku tickets.
  /// `result` 1 is live with no restriction; [AcfunEndpoints.paidShowResult]
  /// (a paid show without a ticket) is live but restricted, with no broadcast
  /// data; [AcfunEndpoints.closedResult] (the broadcast ended) is
  /// stream-unavailable; any other `result` is risk control (the session was
  /// refused, and the caller retries once with a new one).
  static AcfunPlayResult startPlay(String body, {required DateTime issuedAt, int status = 200}) {
    final root = AcfunJson.root(body, status: status, what: 'startPlay');
    final result = AcfunJson.intOf(root['result']);
    if (result == null) {
      throw AcfunFailure(AcfunFailureKind.apiChanged, 'startPlay: no result (${AcfunJson.snippet(body)})');
    }
    if (result == AcfunEndpoints.closedResult) {
      throw AcfunFailure(
        AcfunFailureKind.streamUnavailable,
        'startPlay: ${AcfunJson.text(root['error_msg'])} ($result)',
      );
    }
    if (result == AcfunEndpoints.paidShowResult) {
      return (data: null, restriction: LiveRestriction.paid, tickets: const [], enterRoomAttach: '');
    }
    if (result != 1) {
      throw AcfunFailure(
        AcfunFailureKind.riskControl,
        'startPlay: result $result ${AcfunJson.text(root['error_msg'])}',
      );
    }
    final data = AcfunJson.object(root['data']);
    final liveId = AcfunJson.text(data?['liveId']);
    if (data == null || liveId.isEmpty) {
      throw AcfunFailure(AcfunFailureKind.apiChanged, 'startPlay: no liveId (${AcfunJson.snippet(body)})');
    }
    return (
      data: AcfunRoomData(
        liveId: liveId,
        qualities: AcfunPlayParser.qualities(data['videoPlayRes']),
        issuedAt: issuedAt,
        startedAt: startedAt(data['liveStartTime']),
      ),
      restriction: LiveRestriction.none,
      tickets: [for (final ticket in AcfunJson.list(data['availableTickets'])) ?AcfunJson.string(ticket)],
      enterRoomAttach: AcfunJson.text(data['enterRoomAttach']),
    );
  }

  /// `gift/list`: `data.giftList`, each with `giftId`, `giftName`, `giftPrice`
  /// and `payWalletType` (1 AC coins, 2 bananas) and the pictures. An entry
  /// without an id or a name is left out; a price that is not a count is 0. A
  /// `result` other than 1 is risk control (this endpoint answers 1, where the
  /// others answer 0), and no list is api-changed.
  static AcfunGiftCatalog giftList(String body, {int status = 200}) {
    final root = AcfunJson.root(body, status: status, what: 'gift/list');
    if (AcfunJson.intOf(root['result']) != 1) {
      throw AcfunFailure(AcfunFailureKind.riskControl, 'gift/list: result ${root['result']}');
    }
    final list = AcfunJson.listOf(AcfunJson.object(root['data'])?['giftList']);
    if (list == null) throw const AcfunFailure(AcfunFailureKind.apiChanged, 'gift/list: no giftList');
    final gifts = <String, AcfunGiftInfo>{};
    for (final value in list) {
      final item = AcfunJson.object(value);
      final id = AcfunJson.count(item?['giftId']);
      final name = AcfunJson.string(item?['giftName']);
      if (item == null || id == null || name == null) continue;
      gifts['$id'] = AcfunGiftInfo(
        id: '$id',
        name: name,
        price: AcfunJson.count(item['giftPrice']) ?? 0,
        banana: AcfunJson.intOf(item['payWalletType']) == 2,
        iconUrl: _picture(item['webpPicList']) ?? _picture(item['pngPicList']),
      );
    }
    return AcfunGiftCatalog(gifts);
  }

  /// `www.acfun.cn/search?type=user&ajaxpipe=1`: the authors (live or not) of
  /// the BigPipe answer's `html` fragment, and the total (`data-total`).
  /// Nothing in the answer is run: scripts are text.
  ///
  /// The answer's own checks stay: no total, more cards than the total leaves
  /// for this page, or no cards without the `empty-page` marker is api-changed
  /// — a blocked or cut answer is not "no results". A card whose author, link
  /// or name does not check out, or that repeats an author, is left out.
  static ({List<LiveRoom> rooms, int total}) searchPage(String body, {required int page, int status = 200}) {
    AcfunJson.checkStatus(body, status: status, what: 'search');
    final end = body.indexOf('/*<!-- fetch-stream -->*/');
    final decoded = AcfunJson.tryDecode(end < 0 ? body : body.substring(0, end));
    final content = AcfunJson.object(decoded)?['html'];
    if (content is! String) {
      throw AcfunFailure(AcfunFailureKind.apiChanged, 'search: no html (${AcfunJson.snippet(body)})');
    }
    final fragment = AcfunHtmlElement.parseFragment(content);
    final totalNode = fragment.query(
      (element) => element.hasClass('total-num') && element.attributes.containsKey('data-total'),
    );
    if (totalNode == null) {
      throw AcfunFailure(AcfunFailureKind.apiChanged, 'search: no total (${AcfunJson.snippet(content)})');
    }
    final cards = fragment.queryAll((element) => element.hasClass('search-up')).toList();
    final empty = fragment.query((element) => element.hasClass('empty-page')) != null;
    final totalText = totalNode.attributes['data-total']!.trim();
    var total = AcfunJson.intOf(totalText);
    if (total == null &&
        totalText.isEmpty &&
        totalNode.text.replaceAll(RegExp(r'\s'), '') == '共0条结果' &&
        empty &&
        cards.isEmpty) {
      total = 0;
    }
    const size = AcfunEndpoints.searchPageSize;
    final left = total == null ? 0 : total - (page - 1) * size;
    if (total == null ||
        total < 0 ||
        cards.length > size ||
        cards.length > (left < 0 ? 0 : (left > size ? size : left))) {
      throw AcfunFailure(
        AcfunFailureKind.apiChanged,
        'search: ${cards.length} cards for total $totalText on page $page',
      );
    }
    if (cards.isEmpty && !empty) {
      throw const AcfunFailure(AcfunFailureKind.apiChanged, 'search: no cards and no empty-page marker');
    }
    final seen = <String>{};
    return (rooms: [for (final card in cards) ?_searchCard(card, seen)], total: total);
  }

  // Helpers -------------------------------------------------------------------

  /// One author card: the id of its `data-up-exposure-log`, the name link to
  /// `/u/<id>` on acfun.cn, live when `is_on_live` holds a broadcast id,
  /// unknown when it is neither text nor a flag.
  static LiveRoom? _searchCard(AcfunHtmlElement card, Set<String> seen) {
    final log = AcfunJson.object(AcfunJson.tryDecode(card.attributes['data-up-exposure-log'] ?? ''));
    final id = AcfunJson.text(log?['up_id']);
    if (log == null || !AcfunEndpoints.isAuthorId(id)) return null;
    final anchor = card.query(
      (element) =>
          element.tag == 'a' &&
          element.ancestors.takeWhile((node) => node != card.parent).any((node) => node.hasClass('up__main__name')),
    );
    final href = Uri.tryParse(anchor?.attributes['href'] ?? '');
    final name = anchor?.text.trim() ?? '';
    if (anchor == null ||
        href == null ||
        (href.hasScheme && !(href.isScheme('http') || href.isScheme('https'))) ||
        (href.hasAuthority && href.host != 'www.acfun.cn' && href.host != 'acfun.cn') ||
        href.userInfo.isNotEmpty ||
        href.path != '/u/$id' ||
        name.isEmpty ||
        !seen.add(id)) {
      return null;
    }
    final flag = log['is_on_live'];
    final live = switch (flag) {
      final String value => value.trim().isNotEmpty,
      final bool value => value,
      _ => null,
    };
    final followerText = card.query((element) => element.hasClass('info__danmaku-count'))?.text ?? '';
    final followers = parseAudienceNumberOrNull(_followers.firstMatch(followerText)?.group(1));
    final status = switch (live) {
      true => LiveStatus.live,
      false => LiveStatus.offline,
      null => LiveStatus.unknown,
    };
    return LiveRoom.normalized(
      platform: acfunSiteId,
      roomId: id,
      content: RoomContent.of(introduction: card.query((element) => element.hasClass('up__main__intro'))?.text.trim()),
      anchor: LiveAnchor.normalized(
        platform: acfunSiteId,
        anchorId: id,
        name: name,
        avatarUrl: imageUrl(
          card.query((element) => element.tag == 'img' && element.hasClass('up__avatar'))?.attributes['src'],
        ),
        followerCount: followers,
        liveStatus: status,
      ),
      broadcast: RoomBroadcast.of(liveStatus: status),
      links: RoomLinks.of(webUrl: AcfunEndpoints.roomPageUrl(id)),
    );
  }

  /// "N 粉丝" on a search card (`\s` covers the `&ensp;` the site writes).
  static final RegExp _followers = RegExp(r'^\s*([0-9]+(?:\.[0-9]+)?[万亿]?)\s*粉丝\s*$');

  /// An area named by its type object; the id rides along when the answer
  /// gives one.
  static LiveArea _area(Map<String, dynamic> type) => LiveArea.normalized(
    platform: acfunSiteId,
    areaId: AcfunJson.text(type['id']),
    areaName: AcfunJson.text(type['name']),
  );

  /// The first https `url` of a picture list.
  static String? _picture(Object? list) {
    for (final entry in AcfunJson.list(list)) {
      final url = AcfunJson.text(AcfunJson.object(entry)?['url']);
      if (url.startsWith('https://')) return url;
    }
    return null;
  }

  /// Whether [item] is the room of [authorId]: the echoed `authorId` and
  /// `user.id` are it, and the user has a name.
  static bool _identity(Map<String, dynamic> item, String authorId) {
    final user = AcfunJson.object(item['user']);
    return AcfunJson.text(item['authorId']) == authorId &&
        AcfunJson.text(user?['id']) == authorId &&
        AcfunJson.text(user?['name']).isNotEmpty;
  }

  /// `channelListData` (or the answer itself) of a list answer: `result` 0, a
  /// `liveList` list and a `pcursor` string or number.
  static ({List<Object?> list, String cursor}) _listData(Map<String, dynamic> root) {
    final data = AcfunJson.object(root['channelListData']) ?? root;
    if (AcfunJson.intOf(data['result']) != 0) {
      throw AcfunFailure(AcfunFailureKind.apiChanged, 'channel/list: result ${data['result']}');
    }
    final list = AcfunJson.listOf(data['liveList']);
    final cursor = data['pcursor'];
    if (list == null || (cursor is! String && cursor is! int)) {
      throw const AcfunFailure(AcfunFailureKind.apiChanged, 'channel/list: no liveList or pcursor');
    }
    return (list: list, cursor: '$cursor'.trim());
  }

  /// An image link as AcFun returns it, made absolute: quotes around it
  /// removed, protocol-relative `//…` made https; empty for null, blanks and
  /// anything that is not a web address.
  static String imageUrl(Object? source) {
    var value = source?.toString().trim() ?? '';
    if (value.isEmpty || value.toLowerCase() == 'null') return '';
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1).trim();
    }
    if (value.isEmpty) return '';
    if (value.startsWith('//')) return 'https:$value';
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty) return value;
    if (!value.contains(' ') && RegExp(r'^[\w.-]+\.[a-zA-Z]{2,}([/:?#]|$)').hasMatch(value)) return 'https://$value';
    return '';
  }
}
