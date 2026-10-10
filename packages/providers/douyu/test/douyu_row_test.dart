// Module: test/douyu_row_test.dart
// Purpose: Pin the field coercion and the three live-status rules the row shapes disagree about.
// Author: liuchuancong
// Created: 2026-10-10
import 'package:pure_live_douyu/pure_live_douyu.dart';
import 'package:test/test.dart';

void main() {
  group('douyuInt', () {
    test('test_int_acceptsTheNumberAndStringShapes', () {
      expect(douyuInt(42), 42);
      expect(douyuInt('42'), 42);
      expect(douyuInt(' 42 '), 42);
      expect(douyuInt(4.9), 4);
      expect(douyuInt(null), 0);
      expect(douyuInt(''), 0);
    });
  });

  group('urls', () {
    test('test_absoluteUrl_makesAProtocolRelativeCoverAbsolute', () {
      expect(douyuAbsoluteUrl('//js.douyucdn.cn/a.jpg'), 'https://js.douyucdn.cn/a.jpg');
      expect(douyuAbsoluteUrl('https://a/b.jpg'), 'https://a/b.jpg');
    });

    test('test_absoluteUrl_relativePath_isNotGuessedAt', () {
      // A bare path has no host to prepend; inventing one hands the UI a broken image url that looks fine.
      expect(douyuAbsoluteUrl('/upload/a.jpg'), isNull);
      expect(douyuAbsoluteUrl('  '), isNull);
    });
  });

  group('live status', () {
    test('test_listRowIsLive_onlyTypeOneIsARoom', () {
      expect(douyuListRowIsLive(<Object?, Object?>{'type': 1}), isTrue);
      expect(douyuListRowIsLive(<Object?, Object?>{'type': '1'}), isTrue);
      expect(douyuListRowIsLive(<Object?, Object?>{'type': 3}), isFalse);
    });

    test('test_roomPayloadIsLive_replayLoopAndReplayTitleAreNotLive', () {
      final living = <Object?, Object?>{'show_status': 1, 'videoLoop': 0, 'room_name': '房间'};
      expect(douyuRoomPayloadIsLive(living), isTrue);
      expect(douyuRoomPayloadIsLive(<Object?, Object?>{...living, 'show_status': 2}), isFalse);
      expect(douyuRoomPayloadIsLive(<Object?, Object?>{...living, 'videoLoop': 1}), isFalse);
      expect(douyuRoomPayloadIsLive(<Object?, Object?>{...living, 'room_name': '【回放】房间'}), isFalse);
    });

    test('test_searchRowIsLive_roomTypeOneIsAReplayRoom', () {
      expect(douyuSearchRowIsLive(<Object?, Object?>{'isLive': 1, 'roomType': 0}), isTrue);
      expect(douyuSearchRowIsLive(<Object?, Object?>{'isLive': 1, 'roomType': 1}), isFalse);
      expect(douyuSearchRowIsLive(<Object?, Object?>{'isLive': 0, 'roomType': 0}), isFalse);
    });
  });

  group('douyuStartedAt', () {
    test('test_startedAt_unixSecondsBecomeUtc', () {
      expect(douyuStartedAt(1700000000), DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true));
    });

    test('test_startedAt_outOfRangeValuesAreReadAsNotStated', () {
      expect(douyuStartedAt(0), isNull);
      expect(douyuStartedAt(-1), isNull);
      expect(douyuStartedAt('0'), isNull);
      // A field that means something else (a millisecond count, an id) must not become a 1970 broadcast.
      expect(douyuStartedAt(1), isNull);
    });
  });

  group('rows', () {
    test('test_roomFromListRow_blankTitleFallsBackToTheRoomId', () {
      final summary = douyuRoomFromListRow(<Object?, Object?>{'type': 1, 'rid': 123, 'rn': '  '});

      expect(summary.ref.sourceId, douyuSourceId);
      expect(summary.ref.contentId, '123');
      expect(summary.title, '123');
      expect(summary.subtitle, isEmpty);
    });

    test('test_roomFromProfile_carriesTheStartTimeItStates', () {
      final summary = douyuRoomFromProfile(<Object?, Object?>{
        'room_id': 123,
        'room_name': '房间',
        'show_time': 1700000000,
        'room_biz_all': {'hot': '10'},
      }, roomId: 'ignored');

      expect(summary.ref.contentId, '123');
      expect(summary.metadata.popularity, 10);
      expect(summary.metadata.extra['startedAt'], isNotNull);
    });

    test('test_roomFromProfile_withoutBusinessBlock_isNotAThrow', () {
      // The profile has shipped without room_biz_all for a room that was not live; popularity is then simply 0.
      final summary = douyuRoomFromProfile(<Object?, Object?>{'room_id': 1, 'room_name': 'r'}, roomId: '1');

      expect(summary.metadata.popularity, 0);
      expect(summary.metadata.extra['startedAt'], isNull);
    });
  });
}
