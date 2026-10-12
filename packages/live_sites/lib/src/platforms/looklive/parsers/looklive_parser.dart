import 'dart:convert';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:live_sites/live_sites.dart';

/// Static parsers and the request envelope for the Look (网易 LOOK) APIs.
abstract final class LookLiveParser {
  /// Web origin.
  static const String origin = 'https://look.163.com';

  /// API origin.
  static const String apiOrigin = 'https://api.look.163.com';

  /// The room endpoint.
  static const String roomPath = '/weapi/livestream/room/get/v3';

  /// Request headers of every API call.
  static const Map<String, String> requestHeaders = {
    'accept': 'application/json, text/plain, */*',
    'origin': origin,
    'referer': '$origin/',
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'content-type': 'application/x-www-form-urlencoded',
  };

  /// Media headers of [roomId].
  static Map<String, String> mediaHeaders(String roomId) => {
    'origin': origin,
    'referer': '$origin/live?id=$roomId',
    'user-agent': requestHeaders['user-agent']!,
  };

  static const String _nonce = '0CoJUm6Qyw8W8jud';
  static const String _secretKey = '0123456789abcdef';
  static const String _iv = '0102030405060708';

  /// The web client's RSA modulus (public).
  static final BigInt _modulus = BigInt.parse(
    '00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec'
    '4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813'
    'cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7',
    radix: 16,
  );

  /// The `encSecKey`: the reversed secret key as hexadecimal raised to
  /// 65537 mod the modulus.
  static final String encSecKey = BigInt.parse(
    utf8.encode(_secretKey).reversed.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  ).modPow(BigInt.from(0x10001), _modulus).toRadixString(16).padLeft(256, '0');

  static final crypto.AesCbc _aesCbc = crypto.AesCbc.with128bits(macAlgorithm: crypto.MacAlgorithm.empty);

  /// AES-128-CBC (PKCS#7, fixed IV) of [text] under [key], Base64.
  static Future<String> aesEncrypt(String text, String key) async {
    final box = await _aesCbc.encrypt(
      utf8.encode(text),
      secretKey: crypto.SecretKey(utf8.encode(key)),
      nonce: utf8.encode(_iv),
    );
    return base64Encode(box.cipherText);
  }

  /// The `weapi` envelope of [payload]: `params` double-encrypted
  /// (nonce then secret key), `encSecKey` the RSA blob.
  static Future<Map<String, String>> envelope(Object? payload) async {
    final once = await aesEncrypt(jsonEncode(payload), _nonce);
    final twice = await aesEncrypt(once, _secretKey);
    return {'params': twice, 'encSecKey': encSecKey};
  }

  /// The form body of [payload].
  static Future<String> formBody(Object? payload) async => Uri(queryParameters: await envelope(payload)).query;

  /// The video list path (the homepage's own recommendation feed).
  static const String videoListPath = '/weapi/livestream/homepage/recommend';

  /// The voice list path.
  static const String audioListPath = '/weapi/livestream/listen/homepage/recommend/list';

  /// Rooms one list page asks for.
  static const int pageSize = 20;

  /// The last page a caller may ask for.
  static const int maxPage = 10000;

  /// The most entries one list answer may hold.
  static const int maxEntries = 100;

  /// The id of the video feed's area.
  static const String videoAreaId = 'video';

  /// The id of the voice feed's area.
  static const String audioAreaId = 'audio';

  /// The video area's name.
  static const String videoAreaName = '视频直播';

  /// The voice area's name.
  static const String audioAreaName = '语音直播';

  /// The catalogue: the site's two feeds, and it is constant — the areas are
  /// the feeds themselves — so no request is spent finding it out.
  static List<LiveArea> areas() => const [
    LiveArea(id: videoAreaId, name: videoAreaName),
    LiveArea(id: audioAreaId, name: audioAreaName, sort: 1),
  ];

  /// The feed an area id names, or null for anything else.
  static LookLiveKind? kindOf(String areaId) => switch (areaId.trim()) {
    videoAreaId => LookLiveKind.video,
    audioAreaId => LookLiveKind.audio,
    _ => null,
  };

  /// The path of [kind]'s list.
  static String listPath(LookLiveKind kind) => kind == LookLiveKind.audio ? audioListPath : videoListPath;

  /// The payload of list page [page].
  static Map<String, int> listPayload(int page) => {'offset': (page - 1) * pageSize, 'limit': pageSize};

  /// A list answer of [kind]: its live rooms, each once, and whether the site
  /// has another page after them.
  ///
  /// An answer that carries neither rows nor a "more" flag is an ended list
  /// rather than a broken one, which is how the video feed answers once it
  /// runs out. An entry of another feed is left out; an entry that looked
  /// like a card of this feed but cannot be read costs itself, while a page
  /// none of whose entries can be read is a changed endpoint.
  static LivePage<LiveRoom> directory(String body, {required LookLiveKind kind, required int page, int status = 200}) {
    final what = kind == LookLiveKind.audio ? 'voice list' : 'video list';
    final data = LookLiveParser.data(body, status: status, what: what);
    final rows = data['itemList'];
    final hasMore = data['hasMore'];
    if (rows == null && hasMore == false) {
      return const LivePage<LiveRoom>(items: []);
    }
    if (rows is! List || rows.length > maxEntries || hasMore is! bool) {
      throw SiteApiChangedError(
        'looklive $what: itemList ${rows is List ? 'of ${rows.length}' : rows.runtimeType}, hasMore $hasMore',
      );
    }
    final seen = <String>{};
    final rooms = <LiveRoom>[];
    var unreadable = 0;
    for (final row in rows) {
      final entry = card(row, kind: kind);
      if (entry.malformed) {
        unreadable++;
        continue;
      }
      if (entry.room case final room? when seen.add(room.roomId)) {
        rooms.add(room);
      }
    }
    if (rooms.isEmpty && unreadable > 0) {
      throw SiteApiChangedError('looklive $what page $page: $unreadable unreadable entries, none listed');
    }
    return LivePage<LiveRoom>(items: rooms, hasMore: hasMore, nextPage: hasMore ? page + 1 : null);
  }

  /// One list entry: its room, or none because the entry is another feed's
  /// or carries no live data.
  ///
  /// A card is `type` 1 with a `liveData` object whose `liveType` says which
  /// feed it belongs to — 1 video, 2 voice, and a card whose `liveType` is
  /// neither is a changed payload rather than another feed's entry. The
  /// number, name, title, pictures, popularity and viewer count come from the
  /// card; a card's room is always live, because the feeds carry nothing
  /// else.
  static ({LiveRoom? room, bool malformed}) card(Object? raw, {required LookLiveKind kind}) {
    final entry = SiteJson.object(raw);
    if (SiteText.trimmed(entry['type']) != '1' || entry['liveData'] == null) {
      return (room: null, malformed: false);
    }
    final live = SiteJson.object(entry['liveData']);
    final liveType = SiteCounts.integer(live['liveType']);
    if (liveType != 1 && liveType != 2) {
      return (room: null, malformed: true);
    }
    if (liveType != (kind == LookLiveKind.audio ? 2 : 1)) {
      return (room: null, malformed: false);
    }
    final user = SiteJson.object(live['userInfo']);
    final roomId = SiteText.trimmed(user['liveRoomNo']);
    if (!_roomNumber.hasMatch(roomId)) {
      return (room: null, malformed: true);
    }
    final online = SiteCounts.integer(live['onlineNumber']);
    return (
      room: LiveRoom(
        platform: SiteIds.looklive,
        roomId: roomId,
        title: SiteText.trimmed(live['liveTitle']),
        nick: SiteText.trimmed(user['nickname']),
        avatar: _picture(user['avatarUrl']),
        cover: _picture(live['liveCoverUrl']),
        status: LiveStatus.live,
        watching: online ?? SiteCounts.integer(live['popularity']),
        onlineViewers: online,
      ),
      malformed: false,
    );
  }

  /// A room number: two to eighteen digits, as the site writes them.
  static final RegExp _roomNumber = RegExp(r'^[1-9][0-9]{1,17}$');

  /// [input] as a room number when it is one, else null.
  static String? roomNumber(String input) {
    final text = input.trim();
    return _roomNumber.hasMatch(text) ? text : null;
  }

  /// Validates the envelope (`code` 0) and returns `data`; code 404 is
  /// "not found".
  static Map<String, Object?> data(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('looklive $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('looklive $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('looklive $what: body is not an object');
    }
    final code = SiteCounts.integer(decoded['code']);
    if (code == 404) {
      throw SiteNotFoundError('looklive $what: room not found');
    }
    if (code != null && code != 0 && code != 200) {
      throw SiteApiChangedError('looklive $what: code $code');
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw SiteApiChangedError('looklive $what: no data object');
    }
    return data;
  }

  /// `room/get/v3` → the room snapshot with its media URLs in `data`.
  static LiveRoom room(String body, {required String roomId, int status = 200}) {
    const what = 'room/get/v3';
    final data = LookLiveParser.data(body, status: status, what: what);
    final anchor = data['anchor'];
    final anchorMap = anchor is Map<String, Object?> ? anchor : const <String, Object?>{};
    final answered = anchorMap['liveRoomNo']?.toString() ?? '';
    if (answered != roomId) {
      throw SiteApiChangedError('looklive $what: asked $roomId, got $answered');
    }
    final info = data['roomInfo'];
    final infoMap = info is Map<String, Object?> ? info : const <String, Object?>{};
    final liveStatus = SiteCounts.integer(data['liveStatus']);
    final live = liveStatus == 1;
    final banned = liveStatus == -10 || liveStatus == -4;
    final startSeconds = SiteCounts.integer(infoMap['startTime']);
    return LiveRoom(
      platform: SiteIds.looklive,
      roomId: roomId,
      title: infoMap['title']?.toString() ?? '',
      nick: anchorMap['nickName']?.toString() ?? '',
      avatar: _picture(anchorMap['avatarUrl']),
      cover: _picture(infoMap['liveCoverUrl']),
      status: live
          ? LiveStatus.live
          : banned
          ? LiveStatus.banned
          : LiveStatus.offline,
      startedAt: live && startSeconds != null && startSeconds > 0
          ? DateTime.fromMillisecondsSinceEpoch(startSeconds * 1000, isUtc: true)
          : null,
      data: live ? infoMap : null,
    );
  }

  /// The play lines of a live room: the HLS playlist then the FLV stream
  /// from `liveUrl`.
  static List<LivePlayLine> playLines(Object? liveUrl, String roomId) {
    if (liveUrl is! Map<String, Object?>) {
      return const [];
    }
    final lines = <LivePlayLine>[];
    final hls = liveUrl['hlsPullUrl']?.toString() ?? '';
    final flv = liveUrl['httpPullUrl']?.toString() ?? '';
    if (hls.startsWith('http')) {
      lines.add(LivePlayLine(url: hls, headers: mediaHeaders(roomId), format: StreamFormat.hls, lineId: 'hls'));
    }
    if (flv.startsWith('http')) {
      lines.add(LivePlayLine(url: flv, headers: mediaHeaders(roomId), format: StreamFormat.flv, lineId: 'flv'));
    }
    return lines;
  }

  static String? _picture(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }

  /// The Yunxin chat-server address endpoint.
  static const String chatAddressPath = '/weapi/livestream/chat/address';

  /// The `chat/address` payload of [roomId].
  static Map<String, Object> chatAddressPayload(String roomId) => {'liveRoomNo': roomId, 'os': 0};

  static final RegExp _chatAddress = RegExp(
    r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+:([0-9]{1,5})$',
  );

  /// The chat servers of a `chat/address` answer: `data.address`, each a
  /// `host:port` of NetEase Yunxin's chatroom service, in the answer's order,
  /// lower-cased; entries that are not a host name and a port (1 to 65535) are
  /// left out. The envelope follows [data] (code 404 is "not found"); no
  /// `address` list, or none usable, is a changed API.
  static List<String> chatAddresses(String body, {int status = 200}) {
    const what = 'chat/address';
    final data = LookLiveParser.data(body, status: status, what: what);
    final raw = data['address'];
    if (raw is! List) {
      throw const SiteApiChangedError('looklive chat/address: address is not a list');
    }
    final addresses = <String>{
      for (final entry in raw)
        if (entry?.toString().trim().toLowerCase() case final address? when address.isNotEmpty)
          if (_chatAddress.firstMatch(address) case final match?)
            if (int.tryParse(match.group(4) ?? '') case final port? when port >= 1 && port <= 65535) address,
    };
    if (addresses.isEmpty) {
      throw const SiteApiChangedError('looklive chat/address: no usable address');
    }
    return addresses.toList();
  }
}

/// The two feeds LOOK Live serves.
enum LookLiveKind {
  /// Video broadcasts (`liveType` 1).
  video,

  /// Voice broadcasts (`liveType` 2).
  audio,
}
