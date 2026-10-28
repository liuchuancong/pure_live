import 'package:live_sites/src/platforms/huya/parsers/huya_play_parser.dart';
import 'package:test/test.dart';

/// A whole second (the signatures count in seconds).
DateTime _at(int seconds) => DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

/// The seconds of [time] in the base-16 `wsTime` form.
String _wsTime(DateTime time) => (time.millisecondsSinceEpoch ~/ 1000).toRadixString(16);

/// The uid the tests sign with (the reference's `_presenter`).
const int _uid = 1400123456789;

/// The issue time the tests sign at (late 2026).
const int _issuedSeconds = 1790733600;

/// A signed media URL of [host] with [query].
Uri _media(String host, String path, Map<String, String> query) => Uri.https(host, path, query);

/// A web-signed URL issued at [issued]: `seqid` is the issue time plus the
/// plain uid, `u` the rotated one (the reader subtracts one from the other).
Map<String, String> _webQuery({required DateTime issued, required DateTime wsTime, String ctype = 'huya_webh5'}) => {
  'wsTime': _wsTime(wsTime),
  'ctype': ctype,
  't': '100',
  'u': '${HuyaPlayParser.rotateUid(_uid)}',
  'seqid': '${issued.millisecondsSinceEpoch + _uid}',
};

void main() {
  group('uid rotation (the reference vectors)', () {
    test('rotate and unrotate are inverses', () {
      expect(HuyaPlayParser.rotateUid(1400123456789), 1399563556349);
      expect(HuyaPlayParser.rotateUid(1471259343403), 1472703638413);
      expect(HuyaPlayParser.unrotateUid(1472703638413), 1471259343403);
      expect(HuyaPlayParser.rotateUid(1346609715), 1134703440);
    });
  });

  group('lease', () {
    final issued = _at(_issuedSeconds);

    test('a web-signed URL ends 125 s after it was issued, renewed at 100 s', () {
      final wsTime = issued.add(const Duration(minutes: 5));
      final lease = HuyaPlayParser.lease(
        _media('al-game.flv.huya.com', '/src/stream.flv', _webQuery(issued: issued, wsTime: wsTime)),
        builtAt: issued,
      );
      expect(lease, isNotNull);
      expect(lease!.expiresAt, issued.add(const Duration(seconds: 125)));
      expect(lease.refreshAt, issued.add(const Duration(seconds: 100)));
      expect(lease.requiresReconnect, isTrue);
    });

    test('a native FLV lease ends with wsTime and needs no reconnect', () {
      final wsTime = _at(_issuedSeconds + 300);
      final lease = HuyaPlayParser.lease(
        _media('al-game.flv.huya.com', '/src/stream.flv', {
          'wsTime': _wsTime(wsTime),
          'ctype': 'huya_pc_exe',
          't': '100',
        }),
        builtAt: issued,
      );
      expect(lease, isNotNull);
      expect(lease!.expiresAt, wsTime.add(const Duration(minutes: 5)));
      expect(lease.refreshAt, wsTime.add(const Duration(seconds: 270)));
      expect(lease.requiresReconnect, isFalse);
    });

    test('a static token counts from when the URL was built', () {
      final wsTime = _at(_issuedSeconds + 600);
      final lease = HuyaPlayParser.lease(
        _media('al-game.flv.huya.com', '/src/stream.flv', {
          'wsTime': _wsTime(wsTime),
          'ctype': 'huya_webh5',
          't': '100',
        }),
        builtAt: issued,
      );
      expect(lease, isNotNull);
      expect(lease!.expiresAt, issued.add(const Duration(seconds: 125)));
      expect(lease.refreshAt, issued.add(const Duration(seconds: 100)));
      expect(lease.requiresReconnect, isTrue);
    });

    test('a token window earlier than the signature bounds the lease', () {
      final wsTime = _at(_issuedSeconds + 300);
      final lease = HuyaPlayParser.lease(
        _media('al-game.flv.huya.com', '/src/stream.flv', {
          'wsTime': _wsTime(wsTime),
          'ctype': 'huya_pc_exe',
          't': '100',
        }),
        builtAt: issued,
        token: (refreshAt: issued.add(const Duration(seconds: 20)), invalidAt: issued.add(const Duration(seconds: 40))),
      );
      expect(lease, isNotNull);
      expect(lease!.expiresAt, issued.add(const Duration(seconds: 40)));
      expect(lease.refreshAt, issued.add(const Duration(seconds: 20)));
    });

    test('an expired wsTime still answers its (past) lease', () {
      final wsTime = _at(_issuedSeconds - 600);
      final lease = HuyaPlayParser.lease(
        _media('al-game.flv.huya.com', '/src/stream.flv', {
          'wsTime': _wsTime(wsTime),
          'ctype': 'huya_pc_exe',
          't': '100',
        }),
        builtAt: issued,
      );
      expect(lease, isNotNull);
      expect(lease!.expiresAt, wsTime.add(const Duration(minutes: 5)));
      expect(lease.refreshAt, wsTime.add(const Duration(seconds: 270)));
    });

    test('nothing bounds an unsigned URL', () {
      expect(HuyaPlayParser.lease(Uri.https('al-game.flv.huya.com', '/src/stream.m3u8')), isNull);
      expect(HuyaPlayParser.lease(Uri.https('example.com', '/video.m3u8')), isNull);
    });
  });
}
