import 'package:live_sites/live_sites.dart';
import 'package:test/test.dart';

void main() {
  group('LiveRoom identity', () {
    test('normalized() lower-cases the platform and trims ids', () {
      final room = LiveRoom.normalized(platform: ' DOUYU ', roomId: ' 9999 ');
      expect(room.ref, const LiveRoomRef(platform: 'douyu', roomId: '9999'));
      expect(room.identityKey, 'douyu:9999');
    });

    test('normalization is idempotent', () {
      final once = LiveRoom.normalized(platform: 'Douyu', roomId: '9999');
      final twice = LiveRoom.normalized(platform: once.platform, roomId: once.roomId);
      expect(once, twice);
    });

    test('identity lives on ref, equality is value-based', () {
      final a = LiveRoom.normalized(platform: 'douyu', roomId: '9999');
      final b = LiveRoom.normalized(platform: 'douyu', roomId: '9999');
      final retitled = a.copyWith(content: const RoomContent(title: 'new'));

      expect(a == b, isTrue);
      expect(a == retitled, isFalse, reason: 'value equality: a new title is a new value');
      expect(a.ref == retitled.ref, isTrue, reason: 'identity: same room regardless of fields');
      expect(a.identityKey, retitled.identityKey);
    });
  });

  group('LiveRoom mergedWith', () {
    test('sparse incoming never erases stored values', () {
      final stored = LiveRoom.normalized(
        platform: 'douyu',
        roomId: '9999',
        content: const RoomContent(title: 'stored title', coverUrl: 'https://cover'),
        audience: const RoomAudience(popularity: 12000),
      );
      final incoming = LiveRoom.normalized(
        platform: 'douyu',
        roomId: '9999',
        content: const RoomContent(title: 'fresh title'),
      );

      final merged = stored.mergedWith(incoming);
      expect(merged.content.title, 'fresh title');
      expect(merged.content.coverUrl, 'https://cover');
      expect(merged.audience.popularity, 12000);
      expect(merged.local, const RoomLocal(), reason: 'local state is never merged');
    });

    test('ignores rooms of another identity', () {
      final stored = LiveRoom.normalized(platform: 'douyu', roomId: '1');
      final other = LiveRoom.normalized(platform: 'douyu', roomId: '2');
      expect(stored.mergedWith(other), same(stored));
    });

    test('a changed status invalidates the previous start time', () {
      final started = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      final stored = LiveRoom.normalized(
        platform: 'douyu',
        roomId: '9999',
        broadcast: RoomBroadcast(liveStatus: LiveStatus.live, startedAt: started),
      );
      final ended = stored.mergedWith(
        LiveRoom.normalized(
          platform: 'douyu',
          roomId: '9999',
          broadcast: const RoomBroadcast(liveStatus: LiveStatus.offline),
        ),
      );
      expect(ended.broadcast.startedAt, isNull);

      final sameStatus = stored.mergedWith(
        LiveRoom.normalized(
          platform: 'douyu',
          roomId: '9999',
          broadcast: const RoomBroadcast(liveStatus: LiveStatus.live),
        ),
      );
      expect(sameStatus.broadcast.startedAt, started);
    });
  });

  group('LiveRoom JSON', () {
    test('round-trips through v2 storage', () {
      final room = LiveRoom.normalized(
        platform: 'douyu',
        roomId: '9999',
        content: const RoomContent(title: '标题', coverUrl: 'https://cover', platformTags: ['王者荣耀']),
        audience: const RoomAudience(popularity: 12000, primaryMetric: LiveAudienceMetricType.popularity),
        broadcast: const RoomBroadcast(liveStatus: LiveStatus.live),
        anchor: const LiveAnchor(platform: 'douyu', anchorId: '42', name: '主播'),
        area: const LiveArea(platform: 'douyu', areaId: '1', areaName: '英雄联盟', parentAreaName: '网游'),
        local: const RoomLocal(tagIds: ['followed']),
      );

      final restored = LiveRoom.fromJson(room.toJson());
      expect(restored, room);
      expect(restored.ref, room.ref);
      expect(restored.content.platformTags, ['王者荣耀']);
      expect(restored.anchor!.name, '主播');
      expect(restored.area!.parentAreaName, '网游');
      expect(restored.local.tagIds, ['followed']);
      expect(restored.runtime.streamHandle, isNull, reason: 'runtime handles are never stored');
    });
  });

  group('LiveMessage', () {
    test('normalized() trims text; color defaults to white', () {
      final message = LiveMessage.normalized(text: '  hello  ');
      expect(message.text, 'hello');
      expect(message.effectiveColor, LiveMessageColor.white);
      expect(message.effectiveSender.userId, '');
      expect(message.isFromOtherRoom, isFalse);
    });

    test('payload contract: gift messages expose their payload', () {
      final gift = LiveMessage.normalized(
        type: LiveMessageType.gift,
        payload: const LiveGift(giftId: '1', name: '小花'),
      );
      final payload = gift.giftOrNull;
      expect(payload, isA<LiveGift>());
      expect(payload, const LiveGift(giftId: '1', name: '小花'));

      final chat = LiveMessage.normalized(text: 'hi');
      expect(chat.giftOrNull, isNull);
    });

    test('sender badge fields round-trip through JSON', () {
      final message = LiveMessage.normalized(
        text: 'hi',
        sender: const MessageSender(
          userId: '1',
          userName: '观众',
          fanBadgeLevel: '21',
          fanBadgeName: '粉丝团',
          role: LiveAnchorRole.moderator,
          membershipTier: 1,
        ),
      );
      final restored = LiveMessage.fromJson(message.toJson());
      final sender = restored.effectiveSender;
      expect(sender.fanBadgeLevel, '21');
      expect(sender.role, LiveAnchorRole.moderator);
      expect(sender.membershipTier, 1);
    });
  });
}
