import 'dart:convert';

import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/douyu/douyu_models.dart';

/// Static parsers for the Douyu web APIs and page payloads.
abstract final class DouyuParser {
  static final RegExp _htmlPage = RegExp(r'^\s*<');

  /// Validates a JSON envelope (`error`/`code` on the webconf APIs) and
  /// returns the decoded root.
  static Object? checked(String body, {int status = 200, String what = 'response'}) {
    if (status != 200) {
      throw SiteApiChangedError('douyu $what: HTTP $status');
    }
    final Object? root;
    try {
      root = jsonDecode(body);
    } on FormatException catch (error) {
      throw SiteApiChangedError('douyu $what: body is not JSON (${error.message})');
    }
    if (root is! Map<String, Object?>) {
      throw SiteApiChangedError('douyu $what: body is not an object');
    }
    final error = (root['error'] as num?)?.toInt() ?? (root['code'] as num?)?.toInt() ?? 0;
    if (error != 0) {
      final message = root['msg']?.toString() ?? root['message']?.toString() ?? '';
      throw SiteApiChangedError('douyu $what: error $error $message'.trim());
    }
    return root;
  }

  /// `getEncryption` payload → descriptor; incomplete or already-expired
  /// descriptors are API-changed errors.
  static DouyuDescriptor descriptor(Map<String, Object?> root, {required DateTime now}) {
    final descriptor = DouyuDescriptor.fromJson(root['data']);
    if (descriptor == null || !descriptor.usableAt(now)) {
      throw const SiteApiChangedError('getEncryption: descriptor incomplete or expired');
    }
    return descriptor;
  }

  /// `getH5PlayV1` payload → `data`. Non-zero `error` is a room state
  /// (e.g. `-5` not streaming) surfaced as "not found" — a retry cannot
  /// fix it.
  static Map<String, Object?> playData(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('getH5PlayV1: body is not an object');
    }
    final code = (decoded['error'] as num?)?.toInt() ?? (decoded['code'] as num?)?.toInt();
    if (code == null) {
      throw const SiteApiChangedError('getH5PlayV1: no error code');
    }
    if (code != 0) {
      throw SiteNotFoundError('getH5PlayV1: error $code ${decoded['msg']?.toString() ?? ''}'.trim());
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw const SiteApiChangedError('getH5PlayV1: no data');
    }
    return data;
  }

  /// Play lines from the `data`: `rtmp_url` + `rtmp_live` per entry of
  /// the answering CDN (`rtmp_multi_bitrate` for the other rates).
  static List<LivePlayLine> playLines(Map<String, Object?> data) {
    final url = data['rtmp_url']?.toString() ?? '';
    final path = data['rtmp_live']?.toString() ?? '';
    if (!url.startsWith('http') || path.isEmpty) {
      return const [];
    }
    return [
      LivePlayLine(
        url: '$url/$path',
        headers: mediaHeaders(data['room_id']?.toString() ?? ''),
        format: StreamFormat.flv,
        codec: 'avc',
        lineId: data['rtmp_cdn']?.toString() ?? 'cdn',
      ),
    ];
  }

  /// Standard media headers; the referer carries the room so the edge
  /// accepts the stream.
  static Map<String, String> mediaHeaders(String roomId) => {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': roomId.isEmpty ? 'https://www.douyu.com/' : 'https://www.douyu.com/$roomId',
  };

  /// The `betard/<rid>` page payload → room detail. The payload may be
  /// double-encoded JSON (`room` as a JSON string).
  static LiveRoom roomDetail(String body, {required String requestedId}) {
    if (_htmlPage.hasMatch(body.trimLeft())) {
      throw SiteNotFoundError('betard/$requestedId: HTML page');
    }
    var decoded = jsonDecode(body);
    if (decoded is String) {
      decoded = jsonDecode(decoded);
    }
    final root = decoded is Map<String, Object?> ? decoded['room'] : null;
    if (root is! Map<String, Object?>) {
      throw SiteApiChangedError('betard/$requestedId: no room');
    }
    final rid = root['room_id']?.toString() ?? '';
    if (rid.isEmpty) {
      throw SiteApiChangedError('betard/$requestedId: room.room_id missing');
    }
    final rawTitle = root['room_name']?.toString() ?? '';
    final replay = root['videoLoop']?.toString() == '1';
    final titleIsReplay = rawTitle.startsWith('【回放】');
    final live = root['show_status']?.toString() == '1' && !replay && !titleIsReplay;
    return LiveRoom(
      platform: SiteIds.douyu,
      roomId: rid,
      title: rawTitle,
      nick: root['owner_name']?.toString() ?? '',
      avatar: _image(root['owner_avatar']),
      cover: _image(root['room_pic']),
      areaName: root['second_lvl_name']?.toString(),
      watching: int.tryParse(switch (root['room_biz_all']) {
        final Map<String, Object?> biz => biz['hot']?.toString() ?? '',
        _ => '',
      }),
      status: replay ? LiveStatus.replay : (live ? LiveStatus.live : LiveStatus.offline),
    );
  }

  /// `web/api/room/list` payload → one page of live rooms.
  static LivePage<LiveRoom> roomList(Map<String, Object?> root) {
    final list = root['data'];
    final rooms = <LiveRoom>[];
    if (list is List) {
      for (final item in list) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        rooms.add(
          LiveRoom(
            platform: SiteIds.douyu,
            roomId: item['room_id']?.toString() ?? '',
            title: item['room_name']?.toString() ?? '',
            nick: item['nickname']?.toString() ?? '',
            avatar: _image(item['owner_avatar']),
            cover: _image(item['verticalSrc'] ?? item['room_src']),
            areaName: item['cate_name']?.toString(),
            watching: int.tryParse(item['hn']?.toString() ?? ''),
            status: LiveStatus.live,
          ),
        );
      }
    }
    return LivePage<LiveRoom>(items: rooms, hasMore: rooms.isNotEmpty);
  }

  /// Normalizes the avatar/cover paths: a bare upload path becomes the
  /// `_middle.jpg` CDN URL; a full URL passes through.
  static String? _image(Object? value) {
    final path = value?.toString() ?? '';
    if (path.isEmpty) {
      return null;
    }
    if (path.startsWith('https://') || path.startsWith('http://')) {
      return path;
    }
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return 'https://apic.douyucdn.cn/upload/${clean}_middle.jpg';
  }
}
