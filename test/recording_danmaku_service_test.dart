import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/services/recording_danmaku_service.dart';

LiveRecordTask _task(DateTime start, String dir) => LiveRecordTask(
  taskId: 'task-1',
  roomId: '100',
  platform: 'huya',
  title: 't',
  nick: 'n',
  avatar: '',
  cover: '',
  createTime: start,
)..outputDir = dir;

LiveMessage _chat(String text, {String id = '', LiveMessageType type = LiveMessageType.chat}) => LiveMessage(
  type: type,
  userName: 'viewer',
  userId: 'u1',
  message: text,
  color: const LiveMessageColor(255, 0, 0),
  messageId: id,
);

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('rec-danmaku-'));
  tearDown(() async => dir.delete(recursive: true));

  test('writes each attempt to <prefix>.xml with attempt-relative times', () async {
    var now = DateTime(2026, 9, 25, 12, 0, 0);
    void Function(LiveMessage)? deliver;
    var stops = 0;
    final service = RecordingDanmakuService(
      enabled: () => true,
      now: () => now,
      connect: (task, onMessage) async {
        deliver = onMessage;
        return RecordingDanmakuConnection(stop: () async => stops++);
      },
    );
    final task = _task(now, dir.path)..status = RecordStatus.running;
    service.sync([task]);
    await _settle();

    now = now.add(const Duration(milliseconds: 2500));
    deliver!(_chat('hi <b>&"\u0001', id: 'm1'));
    deliver!(_chat('hi <b>&"\u0001', id: 'm1')); // replay after reconnect
    deliver!(_chat('gift', type: LiveMessageType.gift));
    final first = File('${dir.path}/${task.recordingFilePrefix}.xml');

    // The CDN ends the attempt; the recorder reconnects with a new prefix.
    task.status = RecordStatus.reconnecting;
    service.sync([task]);
    await _settle();
    final xml = await first.readAsString();
    expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>\n<i>'));
    expect(xml.trimRight(), endsWith('</i>'));
    expect(RegExp('<d ').allMatches(xml), hasLength(1));
    expect(xml, contains('<d p="2.500,1,25,16711680,'));
    expect(xml, contains('>hi &lt;b&gt;&amp;&quot;</d>'));

    now = now.add(const Duration(seconds: 10));
    task
      ..beginNewAttempt(now: now)
      ..outputDir = dir.path
      ..status = RecordStatus.running;
    service.sync([task]);
    await _settle();
    now = now.add(const Duration(seconds: 1));
    deliver!(_chat('second', id: 'm2'));
    expect(service.fileFor('task-1')!.path, endsWith('${task.recordingFilePrefix}.xml'));
    expect(service.fileFor('task-1')!.path, isNot(first.path));

    task.status = RecordStatus.stopped;
    service.sync([task]);
    await _settle();
    expect(stops, 1);
    final second = await File('${dir.path}/${task.recordingFilePrefix}.xml').readAsString();
    expect(second, contains('<d p="1.000,'));
    expect(second.trimRight(), endsWith('</i>'));
    await service.dispose();
  });

  test('does nothing while disabled', () async {
    var connects = 0;
    final service = RecordingDanmakuService(
      enabled: () => false,
      connect: (task, onMessage) async {
        connects++;
        return null;
      },
    );
    service.sync([_task(DateTime.now(), dir.path)..status = RecordStatus.running]);
    await _settle();
    expect(connects, 0);
    expect(dir.listSync(), isEmpty);
  });

  test('a failed connection is retried only after the delay', () async {
    var now = DateTime(2026, 9, 25);
    var connects = 0;
    final service = RecordingDanmakuService(
      enabled: () => true,
      now: () => now,
      connect: (task, onMessage) async {
        connects++;
        throw StateError('offline');
      },
    );
    final task = _task(now, dir.path)..status = RecordStatus.running;
    service.sync([task]);
    await _settle();
    service.sync([task]);
    await _settle();
    expect(connects, 1);
    now = now.add(const Duration(seconds: 31));
    service.sync([task]);
    await _settle();
    expect(connects, 2);
    await service.dispose();
  });
}
