// Opt-in production probe: Huya danmaku WebSocket endpoints. Connects, joins
// the room group, heartbeats and counts delivered frames on both candidate
// endpoints in one shared window. Requires live network and a live room; not
// part of offline CI.
//
// Why this exists: our adapter uses wss://wsapi.huya.com while dart_simple_live
// uses wss://cdnws.api.huya.com:443. A parallel run (same room, same window)
// showed identical delivery (59 vs 59 frames / 30s), so there is no basis to
// switch — this probe can be re-run when either endpoint degrades.
//
//   flutter test tool/probes/huya_danmaku_ws_probe_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/tars/codec/tars_output_stream.dart';

const String _ua = 'HYSDK(Windows,30000002)_APP(pc_exe&7100004&official)_SDK(trans&2.40.0.6448)';
const String _roomDataRegex = r'var\s+TT_ROOM_DATA\s*=\s*(\{[\s\S]*?\})';
const String _streamRegex = r"stream:\s*(\{[\s\S]*?\n\s*\})";

Future<String> _fetchText(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', _ua);
    final response = await request.close();
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close(force: true);
  }
}

Future<String?> _findLiveRoom() async {
  final body = await _fetchText('https://www.huya.com/cache.php?m=LiveList&do=getLiveListByPage&tagAll=0&page=1');
  final json = jsonDecode(body) as Map<String, dynamic>;
  for (final item in json['data']['datas'] as List) {
    final room = item['profileRoom']?.toString();
    if (room != null && room.isNotEmpty && room != '0') return room;
  }
  return null;
}

Future<int> _countFrames(String endpoint, int topSid, Duration window) async {
  var frames = 0;
  WebSocket? socket;
  try {
    socket = await WebSocket.connect(endpoint, protocols: const ['chat']).timeout(const Duration(seconds: 8));
    socket.listen((_) => frames++, onError: (_) {}, cancelOnError: false);

    final group = TarsOutputStream();
    group.write(<String>['live:$topSid', 'chat:$topSid'], 0);
    group.write('', 1);
    final join = TarsOutputStream();
    join.write(16, 0); // EWSCmdC2S_RegisterGroupReq
    join.write(group.toUint8List(), 1);
    socket.add(join.toUint8List());

    final beat = TarsOutputStream();
    beat.write(20, 0); // EWSCmdC2S_HeartBeatReq
    beat.write(Uint8List(0), 1);
    socket.add(beat.toUint8List());

    final done = Completer<void>();
    Timer(window, () => done.complete());
    final ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      try {
        socket?.add(beat.toUint8List());
      } catch (_) {}
    });
    await done.future;
    ticker.cancel();
  } finally {
    await socket?.close();
  }
  return frames;
}

void main() {
  test(
    'both huya danmaku endpoints deliver frames for a live room',
    () async {
      final roomId = await _findLiveRoom();
      expect(roomId, isNotNull, reason: '需要至少一个直播中的房间');

      final page = await _fetchText('https://www.huya.com/$roomId');
      final streamRaw = RegExp(_streamRegex).firstMatch(page)?.group(0)?.replaceAll('stream: ', '').split('\n').first;
      expect(streamRaw, isNotNull, reason: '房间页应包含 stream 段');
      final streamInfo = ((jsonDecode(streamRaw!) as Map)['data'] as List).first['gameStreamInfoList'][0] as Map;
      final topSid = int.tryParse(streamInfo['lChannelId'].toString()) ?? 0;
      expect(topSid, greaterThan(0), reason: '需解析出频道号');

      const window = Duration(seconds: 30);
      final counts = await Future.wait([
        _countFrames('wss://wsapi.huya.com', topSid, window),
        _countFrames('wss://cdnws.api.huya.com:443', topSid, window),
      ]);
      // ignore: avoid_print
      print('wsapi=${counts[0]} cdnws=${counts[1]} (${window.inSeconds}s)');
      expect(counts[0], greaterThan(0), reason: 'wsapi 端点应投递弹幕帧');
      expect(counts[1], greaterThan(0), reason: 'cdnws 端点应投递弹幕帧');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
