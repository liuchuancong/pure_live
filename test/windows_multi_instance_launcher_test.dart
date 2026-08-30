import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/utils/windows_multi_instance_launcher.dart';

void main() {
  test('room command-line payload round-trips without platform response blobs', () {
    final room = LiveRoom(
      roomId: '23030429',
      platform: 'BILIBILI',
      title: '测试直播间',
      nick: '主播',
      status: true,
      liveStatus: LiveStatus.live,
      data: Object(),
      danmakuData: Object(),
    );
    final args = WindowsMultiInstanceLauncher.buildArguments(room: room, processId: 42, timestampMicros: 123456);

    expect(args.first, '--instance=window_42_123456');
    expect(args.length, 2);
    final decoded = WindowsMultiInstanceLauncher.roomFromArgs(args);
    expect(decoded, isNotNull);
    expect(decoded!.roomId, '23030429');
    expect(decoded.platform, 'bilibili');
    expect(decoded.title, '测试直播间');
    expect(decoded.nick, '主播');
    expect(decoded.data, isNull);
    expect(decoded.danmakuData, isNull);
  });

  test('instance ids are sanitized and malformed room payloads are ignored', () {
    expect(WindowsMultiInstanceLauncher.instanceIdFromArgs(const ['--instance=room ../A-1']), 'room.A-1');
    expect(WindowsMultiInstanceLauncher.instanceIdFromArgs(const ['--instance=../../']), isEmpty);
    expect(WindowsMultiInstanceLauncher.instanceIdFromArgs(const ['--instance=NUL']), 'instance_NUL');
    expect(WindowsMultiInstanceLauncher.roomFromArgs(const ['--open-room=not_base64!']), isNull);
  });

  test('room payload carries canonical offline state instead of a stale legacy boolean', () {
    final room = LiveRoom(roomId: 'ended', platform: 'huya', status: true, liveStatus: LiveStatus.offline);

    final decoded = WindowsMultiInstanceLauncher.roomFromArgs([WindowsMultiInstanceLauncher.encodeRoomArgument(room)]);

    expect(decoded, isNotNull);
    expect(decoded!.effectiveLiveStatus, LiveStatus.offline);
    expect(decoded.status, isFalse);
  });
}
