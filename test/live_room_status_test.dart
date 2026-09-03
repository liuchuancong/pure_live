import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/interface/live_site.dart';

void main() {
  group('LiveRoom canonical status', () {
    test('legacy boolean is normalized when enum is omitted', () {
      final live = LiveRoom(roomId: 'live', platform: 'douyu', status: true);
      final offline = LiveRoom(roomId: 'offline', platform: 'douyu', status: false);

      expect(live.liveStatus, LiveStatus.live);
      expect(live.effectiveLiveStatus, LiveStatus.live);
      expect(live.isPlayableNow, isTrue);
      expect(offline.liveStatus, LiveStatus.offline);
      expect(offline.isExplicitlyOfflineNow, isTrue);
    });

    test('old persisted room without enum migrates from the legacy boolean', () {
      final live = LiveRoom.fromJson(<String, dynamic>{
        'roomId': 'persisted-live',
        'platform': 'huya',
        'status': true,
      });
      final offline = LiveRoom.fromJson(<String, dynamic>{
        'roomId': 'persisted-offline',
        'platform': 'huya',
        'status': false,
      });

      expect(live.effectiveLiveStatus, LiveStatus.live);
      expect(offline.effectiveLiveStatus, LiveStatus.offline);
    });

    test('explicit offline enum wins over a stale legacy live boolean', () {
      final room = LiveRoom(
        roomId: 'legacy-conflict',
        platform: 'huya',
        status: true,
        liveStatus: LiveStatus.offline,
      );

      expect(room.effectiveLiveStatus, LiveStatus.offline);
      expect(room.isLiveNow, isFalse);
      expect(room.isExplicitlyOfflineNow, isTrue);
      expect(room.toJson()['liveStatus'], LiveStatus.offline.index);
      expect(room.toJson()['status'], isFalse);
    });

    test('unknown and banned remain authoritative over the legacy boolean', () {
      final pending = LiveRoom(
        roomId: 'pending',
        platform: 'huya',
        status: true,
        liveStatus: LiveStatus.unknown,
      );
      final banned = LiveRoom(
        roomId: 'banned',
        platform: 'huya',
        status: true,
        liveStatus: LiveStatus.banned,
      );

      expect(pending.effectiveLiveStatus, LiveStatus.unknown);
      expect(pending.isLiveStatusPending, isTrue);
      expect(banned.effectiveLiveStatus, LiveStatus.banned);
      expect(banned.isPlayableNow, isFalse);
    });

    test('recording room is playable but not ranked as a live broadcast', () {
      final room = LiveRoom(
        roomId: 'replay',
        platform: 'kuaishou',
        status: true,
        liveStatus: LiveStatus.live,
        isRecord: true,
      );

      expect(room.effectiveLiveStatus, LiveStatus.replay);
      expect(room.isPlayableNow, isTrue);
      expect(room.isLiveNow, isFalse);
    });

    test('base site fallback stays unknown without platform evidence', () async {
      final room = await LiveSite().getRoomDetail(
        roomId: 'missing-adapter-room',
        platform: 'fixture',
      );

      expect(room.effectiveLiveStatus, LiveStatus.unknown);
      expect(room.isLiveStatusPending, isTrue);
      expect(room.isExplicitlyOfflineNow, isFalse);
    });
  });
}
