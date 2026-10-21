// The room share code: the bytes both apps write, and what the reader accepts
// back. The format is a contract with the older client, so it is pinned here
// rather than left to whatever this encoder happens to produce.
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart' show LiveAnchor, LiveRoom, RoomContent, RoomLinks;
import 'package:pure_live/shared/rooms/room_share_code.dart';

LiveRoom _room({String platform = 'douyu', String roomId = '12345'}) => LiveRoom.normalized(
  platform: platform,
  roomId: roomId,
  content: RoomContent(title: '房间标题', coverUrl: 'https://c/cover.jpg'),
  anchor: LiveAnchor.normalized(platform: platform, name: '主播名', avatarUrl: 'https://a/avatar.jpg'),
  links: RoomLinks(webUrl: 'https://www.douyu.com/12345'),
);

void main() {
  group('encodeRoomShareCode', () {
    test('names the room, the anchor and the link in one readable code', () {
      final code = encodeRoomShareCode(_room());
      expect(code, isNotEmpty);
      final back = decodeRoomShareCode(code)!;
      expect(back.ref.platform, 'douyu');
      expect(back.ref.roomId, '12345');
      expect(back.content.title, '房间标题');
      expect(back.anchor?.name, '主播名');
      expect(back.links.webUrl, 'https://www.douyu.com/12345');
      expect(back.content.coverUrl, 'https://c/cover.jpg');
    });

    test('a room without a platform or an id has nothing to point at', () {
      expect(encodeRoomShareCode(LiveRoom.normalized(roomId: '1')), '');
      expect(encodeRoomShareCode(LiveRoom.normalized(platform: 'douyu')), '');
    });

    test('a long field survives the switch to sized string headers', () {
      final title = '长' * 40;
      final back = decodeRoomShareCode(encodeRoomShareCode(_room().copyWith(content: RoomContent(title: title))))!;
      expect(back.content.title, title);
    });
  });

  group('decodeRoomShareCode', () {
    test('finds a code wrapped in other words', () {
      final code = encodeRoomShareCode(_room());
      final back = decodeRoomShareCode('看一下这个 $code 谢谢')!;
      expect(back.ref.roomId, '12345');
    });

    test('refuses what is not a code, and a code for nobody', () {
      expect(decodeRoomShareCode(''), isNull);
      expect(decodeRoomShareCode('https://www.douyu.com/12345'), isNull);
      expect(decodeRoomShareCode('not a code at all'), isNull);
      // A well-formed map that is not this app's marker is not a room either.
      expect(decodeRoomShareCode('YWJjZGVmZ2hpamtsbW5vcHFyc3R1'), isNull);
    });

    test('an unusable room id is no room', () {
      for (final id in ['0', 'null', 'undefined', 'nan', 'none']) {
        expect(decodeRoomShareCode(encodeRoomShareCode(_room(roomId: id))), isNull, reason: id);
      }
    });
  });

  group('OwnClipboardTexts', () {
    test('remembers what the app wrote and forgets the oldest', () {
      OwnClipboardTexts.clear();
      OwnClipboardTexts.remember('  code-one ');
      expect(OwnClipboardTexts.contains('code-one'), isTrue);
      expect(OwnClipboardTexts.contains('other'), isFalse);
      for (var i = 0; i < OwnClipboardTexts.limit + 5; i++) {
        OwnClipboardTexts.remember('text-$i');
      }
      expect(OwnClipboardTexts.contains('code-one'), isFalse);
      expect(OwnClipboardTexts.contains('text-${OwnClipboardTexts.limit + 4}'), isTrue);
    });
  });
}
