import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// A request signer: turns a base URL + query into the signed URL.
///
/// Douyin signs most web APIs with `a_bogus` (a browser-cipher port). The
/// signer is a seam: the adapter defaults to unsigned requests (the
/// webcast host accepts several of them), and the app injects the full
/// signer when it lands.
typedef DouyinSigner = Uri Function(Uri base, Map<String, String> params);

/// Static parsers for the Douyin webcast APIs.
abstract final class DouyinParser {
  /// App id used by the web client.
  static const String aid = '6383';

  /// API request headers.
  static const Map<String, String> apiHeaders = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'origin': 'https://live.douyin.com',
    'referer': 'https://live.douyin.com/',
  };

  /// Media request headers for [webRid].
  static Map<String, String> mediaHeaders(String webRid) => {
    'user-agent': apiHeaders['user-agent']!,
    'origin': apiHeaders['origin']!,
    'referer': webRid.trim().isEmpty
        ? 'https://live.douyin.com/'
        : 'https://live.douyin.com/${Uri.encodeComponent(webRid.trim())}',
  };

  /// Validates a JSON body and returns the root.
  static Map<String, Object?> checked(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('douyin $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('douyin $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('douyin $what: body is not an object');
    }
    final code = SiteCounts.integer(decoded['status_code']);
    if (code != null && code != 0) {
      final message = decoded['data']?.toString() ?? '';
      throw SiteRiskControlError('douyin $what: status_code $code $message'.trim());
    }
    return decoded;
  }

  /// `room/web/enter` → the room (`data.data[0]`).
  static LiveRoom enter(String body, {required String webRid, int status = 200}) {
    final data = checked(body, status: status, what: 'enter')['data'];
    final list = data is Map<String, Object?> ? data['data'] : null;
    if (list is! List || list.isEmpty) {
      throw SiteNotFoundError('douyin enter: no room for $webRid');
    }
    final room = list.first;
    if (room is! Map<String, Object?>) {
      throw const SiteApiChangedError('douyin enter: data.data[0] is not an object');
    }
    final user = data is Map<String, Object?> ? data['user'] : null;
    return roomFrom(
      webRid: webRid,
      room: room,
      person: user is Map<String, Object?> ? user : null,
      live: _isLive(room, roomStatus: data is Map<String, Object?> ? data['room_status'] : null),
    );
  }

  /// `room/reflow/info` → the room (`data.room`), the only answer carrying
  /// the broadcast's start time.
  static LiveRoom reflow(String body, {int status = 200}) {
    final root = checked(body, status: status, what: 'reflow');
    final data = root['data'];
    final room = data is Map<String, Object?> ? data['room'] : null;
    if (room is! Map<String, Object?>) {
      throw const SiteApiChangedError('douyin reflow: data.room missing');
    }
    final owner = room['owner'];
    final webRid = owner is Map<String, Object?> ? owner['web_rid']?.toString() : null;
    if (webRid == null || webRid.isEmpty) {
      throw const SiteApiChangedError('douyin reflow: room.owner.web_rid missing');
    }
    return roomFrom(webRid: webRid, room: room, live: _isLive(room));
  }

  /// Builds the room snapshot from an enter/reflow room object.
  static LiveRoom roomFrom({
    required String webRid,
    required Map<String, Object?> room,
    required bool live,
    Map<String, Object?>? person,
  }) {
    final owner = room['owner'];
    final ownerMap = owner is Map<String, Object?> ? owner : const <String, Object?>{};
    final personMap = person ?? const <String, Object?>{};
    return LiveRoom(
      platform: SiteIds.douyin,
      roomId: webRid,
      title: room['title']?.toString() ?? '',
      nick:
          (live ? ownerMap['nickname'] ?? personMap['nickname'] : personMap['nickname'] ?? ownerMap['nickname'])
              ?.toString() ??
          '',
      avatar: _image(ownerMap['avatar_thumb'] ?? personMap['avatar_thumb']),
      cover: live ? _image(room['cover']) : null,
      status: live ? LiveStatus.live : LiveStatus.offline,
      startedAt: live ? _epoch(room['start_time']) ?? _epoch(room['create_time']) : null,
      data: live ? room['stream_url'] : null,
      danmakuData: live ? _numericRoomId(room) : null,
    );
  }

  /// This broadcast's numeric `room_id` (`id_str`, else `id`), the chat
  /// channel's name; null when it is absent, `0` or not digits.
  static String? _numericRoomId(Map<String, Object?> room) {
    final text = (room['id_str'] ?? room['id'])?.toString().trim();
    if (text == null || text.isEmpty || text == '0') return null;
    return RegExp(r'^\d+$').hasMatch(text) ? text : null;
  }

  /// The quality levels of a `stream_url`: the sdk options first, the
  /// stream data keys as the fallback.
  static List<LivePlayQuality> qualities(Object? streamUrl) {
    final variants = _variants(streamUrl);
    return [for (final variant in variants) variant.quality];
  }

  /// The play lines for [qualityId] in `stream_url`.
  static List<LivePlayLine> playLines(Object? streamUrl, {required String? qualityId, required String webRid}) {
    final variants = _variants(streamUrl);
    final variant =
        variants.where((v) => v.quality.quality?.toString() == qualityId).firstOrNull ?? variants.firstOrNull;
    if (variant == null) {
      return const [];
    }
    return [
      for (final line in variant.lines)
        LivePlayLine(url: line.url, headers: mediaHeaders(webRid), format: line.format, lineId: line.format.name),
    ];
  }

  static List<_Variant> _variants(Object? streamUrl) {
    if (streamUrl is! Map<String, Object?>) {
      return const [];
    }
    final sdk = streamUrl['live_core_sdk_data'];
    final pull = sdk is Map<String, Object?> ? sdk['pull_data'] : null;
    final pullMap = pull is Map<String, Object?> ? pull : const <String, Object?>{};
    final options = pullMap['options'];
    final optionsMap = options is Map<String, Object?> ? options : const <String, Object?>{};
    final streamData = pullMap['stream_data'];
    final streamMap = streamData is Map<String, Object?> ? streamData['data'] : null;
    final streams = streamMap is Map<String, Object?> ? streamMap : const <String, Object?>{};
    final flvMap = streamUrl['flv_pull_url'];
    final flv = flvMap is Map<String, Object?> ? flvMap : const <String, Object?>{};
    final hlsMap = streamUrl['hls_pull_url_map'];
    final hls = hlsMap is Map<String, Object?> ? hlsMap : const <String, Object?>{};
    final namesMap = streamUrl['resolution_name'];
    final names = namesMap is Map<String, Object?> ? namesMap : const <String, Object?>{};

    final keys = <String>{...flv.keys, ...hls.keys};
    final optionsByKey = <String, Map<String, Object?>>{};
    final optionList = optionsMap['qualities'];
    if (optionList is List) {
      for (final option in optionList) {
        if (option is! Map<String, Object?>) {
          continue;
        }
        final key = option['sdk_key']?.toString().toLowerCase();
        if (key != null && key.isNotEmpty) {
          optionsByKey.putIfAbsent(key, () => option);
          keys.add(key);
        }
      }
    }

    final variants = <_Variant>[];
    for (final key in keys) {
      final raw = key.trim().toLowerCase();
      if (!_isPlayableKey(raw)) {
        continue;
      }
      final option = optionsByKey[raw];
      final entry = streams[raw];
      final main = entry is Map<String, Object?> ? entry['main'] : null;
      final mainMap = main is Map<String, Object?> ? main : const <String, Object?>{};
      final lines = <({String url, StreamFormat format})>[];
      void add(Object? value, StreamFormat format) {
        final url = value?.toString() ?? '';
        if (!(url.startsWith('http://') || url.startsWith('https://'))) {
          return;
        }
        if (lines.any((line) => line.url == url)) {
          return;
        }
        lines.add((url: url, format: format));
      }

      add(mainMap['flv'], StreamFormat.flv);
      add(mainMap['hls'], StreamFormat.hls);
      add(flv[raw], StreamFormat.flv);
      add(hls[raw], StreamFormat.hls);
      if (lines.isEmpty) {
        continue;
      }
      final name = option?['name']?.toString() ?? names[key]?.toString() ?? raw;
      variants.add(
        _Variant(
          quality: LivePlayQuality(quality: optionsByKey.keys.toList().indexOf(raw), label: name),
          lines: lines,
        ),
      );
    }
    return variants;
  }

  static bool _isPlayableKey(String key) {
    if (key.isEmpty) {
      return false;
    }
    if (key == 'origin' || key == 'uhd' || key == 'hd' || key == 'sd' || key == 'ld') {
      return true;
    }
    return RegExp(r'^[a-z0-9_]+$').hasMatch(key) && !key.contains('_only');
  }

  static bool _isLive(Map<String, Object?> room, {Object? roomStatus}) {
    final status = SiteCounts.integer(room['status']);
    if (roomStatus != null) {
      return SiteCounts.integer(roomStatus) == 2 || status == 2;
    }
    return status == 2;
  }

  static DateTime? _epoch(Object? value) {
    final seconds = SiteCounts.integer(value);
    return seconds == null || seconds <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  static String? _image(Object? value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    if (value is Map<String, Object?>) {
      final list = value['url_list'];
      if (list is List && list.isNotEmpty) {
        return list.first?.toString();
      }
    }
    return null;
  }
}

final class _Variant {
  new({required this.quality, required this.lines});

  final LivePlayQuality quality;
  final List<({String url, StreamFormat format})> lines;
}
