import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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

  test('only the settings file the launcher wrote is imported', () {
    final temp = p.join(Directory.systemTemp.path, 'fixture-temp');
    const id = 'window_42_1790000000';
    List<String> args(String path, {String instance = id}) => [
      '${WindowsMultiInstanceLauncher.instancePrefix}$instance',
      '${WindowsMultiInstanceLauncher.configPrefix}$path',
    ];
    final handOver = p.join(temp, 'pure_live_instance_ab12', '$id.json');

    expect(
      WindowsMultiInstanceLauncher.configFileFromArgs(args(handOver), tempRoot: temp),
      p.normalize(p.absolute(handOver)),
    );
    for (final path in [
      p.join(Directory.systemTemp.path, 'elsewhere', 'settings.json'),
      p.join(temp, 'other_ab12', '$id.json'),
      p.join(temp, 'pure_live_instance_ab12', 'window_other.json'),
      p.join(temp, 'pure_live_instance_ab12', '..', '..', 'etc', '$id.json'),
      p.join(temp, '$id.json'),
      '',
    ]) {
      expect(WindowsMultiInstanceLauncher.configFileFromArgs(args(path), tempRoot: temp), isNull, reason: path);
    }
    expect(
      WindowsMultiInstanceLauncher.configFileFromArgs([
        '${WindowsMultiInstanceLauncher.configPrefix}$handOver',
      ], tempRoot: temp),
      isNull,
      reason: 'the main window never imports a hand-over file',
    );
  });
}
