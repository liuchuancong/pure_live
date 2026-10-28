import 'package:live_sites/src/platforms/douyin/parsers/douyin_play_parser.dart';
import 'package:test/test.dart';

/// The issue time the tests read a URL at (late 2026).
final DateTime _issued = DateTime.fromMillisecondsSinceEpoch(1790733600000, isUtc: true);

/// [seconds] after [_issued], as a Unix-seconds `expire` value.
String _expire([int seconds = 3600]) => '${_issued.millisecondsSinceEpoch ~/ 1000 + seconds}';

Uri _url(Map<String, String> query) => Uri.https('pull.example.com', '/stream.flv', query);

void main() {
  group('play leases', () {
    test('a signed URL is renewed a quarter before it expires, at most ten minutes', () {
      final url = _url({'expire': _expire()});
      final lease = DouyinPlayParser.lease(url, _issued)!;
      final expiresAt = _issued.add(const Duration(hours: 1));
      expect(lease.expiresAt, expiresAt);
      expect(lease.refreshAt, expiresAt.subtract(const Duration(minutes: 10)));
      expect(lease.expiresAt, isNotNull);
    });

    test('a short lifetime renews at its quarter instead', () {
      final lease = DouyinPlayParser.lease(_url({'expire': _expire(120)}), _issued)!;
      expect(lease.expiresAt, _issued.add(const Duration(seconds: 120)));
      expect(lease.refreshAt, _issued.add(const Duration(seconds: 90)));
    });

    test('wsTime and keeptime bound the URL too, and hex times are read', () {
      final wsTime = (_issued.millisecondsSinceEpoch ~/ 1000).toRadixString(16);
      final lease = DouyinPlayParser.lease(_url({'wsTime': wsTime, 'keeptime': '708'}), _issued)!;
      expect(lease.expiresAt, _issued.add(const Duration(seconds: 1800)));
      final seconds = _issued.millisecondsSinceEpoch ~/ 1000 + 3600;
      final hex = DouyinPlayParser.lease(_url({'expire': seconds.toRadixString(16)}), _issued)!;
      expect(hex.expiresAt, _issued.add(const Duration(hours: 1)));
    });

    test('an unsigned URL has no lease', () {
      expect(DouyinPlayParser.lease(_url(const {}), _issued), isNull);
      expect(DouyinPlayParser.lease(_url({'expire': 'soon'}), _issued), isNull);
    });

    test('a held URL reads its absolute expiry without an issue time', () {
      final past = DouyinPlayParser.leaseOf(_url({'expire': _expire(-600)}))!;
      expect(past.expiresAt, _issued.subtract(const Duration(minutes: 10)));
      expect(past.refreshAt, _issued.subtract(const Duration(minutes: 20)));
      expect(DouyinPlayParser.leaseOf(_url(const {})), isNull);
    });
  });
}
