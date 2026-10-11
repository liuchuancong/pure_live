import 'dart:convert';
import 'dart:math';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/douyu/douyu_models.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_parser.dart';

/// The Douyu adapter: the descriptor-signed H5 play flow over
/// [LiveHttp].
///
/// Danmaku is not wired yet — Douyu uses a TCP text protocol
/// (`danmakuMsg.douyucdn.cn:8501`) instead of WebSockets, which needs its
/// own transport; the capability is simply absent until then.
final class DouyuSite with SiteRoomGuard implements LiveSite, LiveDirectoryCapability {
  /// A site over [http]; [now] is injectable for descriptor-expiry tests.
  new({required this.http, DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// The HTTP transport.
  final LiveHttp http;

  final DateTime Function() _now;

  static const String _www = 'www.douyu.com';

  /// The device id identifies this client to the signing endpoint; one
  /// random hex id per adapter instance.
  late final String _did = _randomDid();

  DouyuDescriptor? _descriptor;
  Future<DouyuDescriptor>? _descriptorFetch;

  @override
  String get siteId => SiteIds.douyu;

  @override
  String get id => SiteIds.douyu;

  @override
  SiteMetadata get metadata =>
      const SiteMetadata(id: SiteIds.douyu, displayName: '斗鱼直播', homeUrl: 'https://www.douyu.com');

  @override
  Future<LivePage<LiveRoom>> getRecommendRooms({int page = 1}) async {
    final root = await _getJson('https://www.douyu.com/gapi/rkc/directory/mixList/0_0/$page');
    return DouyuParser.roomList(root);
  }

  @override
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page = 1}) async {
    final root = await _getJson(
      'https://www.douyu.com/gapi/rkc/directory/mixList/${area.parentId ?? '0'}_${area.id}/$page',
    );
    return DouyuParser.roomList(root);
  }

  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('douyu search lands with the search-migration phase');
  }

  @override
  Future<LiveRoom> getRoomDetail(LiveRoom room) async {
    guardRoom(room);
    final data = await _getJson('https://www.douyu.com/betard/${room.roomId}');
    return room.mergeFrom(DouyuParser.roomDetail(jsonEncode(data), requestedId: room.roomId));
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room) async {
    guardRoom(room);
    // The quality list arrives inside the signed play answer
    // (`multirates`); asking with rate -1 returns the metadata only.
    final data = await _play(room.roomId, rate: -1);
    final rates = data['multirates'];
    final qualities = <LivePlayQuality>[];
    if (rates is List) {
      for (final item in rates) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        qualities.add(
          LivePlayQuality(
            quality: (item['rate'] as num?)?.toInt(),
            label: item['name']?.toString() ?? '',
            sort: qualities.length,
          ),
        );
      }
    }
    return qualities;
  }

  @override
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality) async {
    guardRoom(room);
    final data = await _play(room.roomId, rate: quality.quality ?? 0);
    return DouyuParser.playLines(data);
  }

  @override
  Future<LiveRoom> refreshLiveStatus(LiveRoom room) async {
    guardRoom(room);
    final data = await _getJson('https://www.douyu.com/betard/${room.roomId}');
    return room.mergeFrom(DouyuParser.roomDetail(jsonEncode(data), requestedId: room.roomId));
  }

  Future<Map<String, Object?>> _getJson(String url) async {
    final response = await http.send(LiveRequest.get(Uri.parse(url), headers: DouyuParser.mediaHeaders(''), site: id));
    if (response.statusCode != 200) {
      throw SiteApiChangedError('douyu: HTTP ${response.statusCode} for $url');
    }
    return jsonDecode(response.text) as Map<String, Object?>;
  }

  /// One signed `getH5PlayV1` for (rate, cdn): descriptor fetched or
  /// reused while fresh, then the signed form posted.
  Future<Map<String, Object?>> _play(String roomId, {required int rate}) async {
    final tt = _now().millisecondsSinceEpoch ~/ 1000;
    final descriptor = await _descriptorFor();
    final response = await http.send(
      LiveRequest.form(
        Uri.https(_www, '/lapi/live/getH5PlayV1/$roomId'),
        fields: {
          'enc_data': descriptor.encData,
          'tt': '$tt',
          'did': _did,
          'auth': descriptor.auth(roomId, tt),
          'cdn': '',
          'rate': '$rate',
          'hevc': '0',
          'fa': '0',
          'ive': '0',
          'ver': 'Douyu_new',
          'iar': '0',
        },
        headers: DouyuParser.mediaHeaders(roomId),
        site: id,
      ),
    );
    return DouyuParser.playData(response.text);
  }

  /// The signing descriptor for this device: reused while younger than
  /// five minutes, fetched once for concurrent callers.
  Future<DouyuDescriptor> _descriptorFor() {
    final cached = _descriptor;
    if (cached != null && cached.usableAt(_now())) {
      return Future.value(cached);
    }
    return _descriptorFetch ??= () async {
      try {
        final response = await http.send(
          LiveRequest.get(
            Uri.https(_www, '/wgapi/livenc/liveweb/websec/getEncryption', {'did': _did}),
            headers: DouyuParser.mediaHeaders(''),
            site: id,
          ),
        );
        final root = jsonDecode(response.text) as Map<String, Object?>;
        return DouyuParser.descriptor(root, now: _now());
      } finally {
        _descriptorFetch = null;
      }
    }();
  }

  static String _randomDid() {
    final random = Random.secure();
    return [for (var i = 0; i < 32; i++) random.nextInt(16).toRadixString(16)].join();
  }
}
