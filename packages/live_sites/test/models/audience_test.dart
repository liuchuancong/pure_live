import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/common/normalization/site_counts.dart';
import 'package:test/test.dart';

void main() {
  group('parseAudienceNumberOrNull', () {
    test('parses Chinese-scale texts', () {
      expect(parseAudienceNumberOrNull('1.2万'), 12000);
      expect(parseAudienceNumberOrNull('8000万'), 80000000);
      expect(parseAudienceNumberOrNull('2亿'), 200000000);
      expect(parseAudienceNumberOrNull('3千'), 3000);
    });

    test('parses latin-scale and plain texts', () {
      expect(parseAudienceNumberOrNull('3,400'), 3400);
      expect(parseAudienceNumberOrNull('3,400'), 3400);
      expect(parseAudienceNumberOrNull('1.5k'), 1500);
      expect(parseAudienceNumberOrNull('3m'), 3000000);
      expect(parseAudienceNumberOrNull('42'), 42);
    });

    test('null on unknown input (never a fabricated zero)', () {
      expect(parseAudienceNumberOrNull(''), isNull);
      expect(parseAudienceNumberOrNull('   '), isNull);
      expect(parseAudienceNumberOrNull('abc'), isNull);
      expect(parseAudienceNumberOrNull(null), isNull);
    });
  });

  group('AudienceNumberConverter', () {
    const converter = AudienceNumberConverter();

    test('reads texts and numbers', () {
      expect(converter.fromJson('1.2万'), 12000);
      expect(converter.fromJson(0), 0);
      expect(converter.fromJson('nonsense'), isNull);
    });

    test('writes plain ints', () {
      expect(converter.toJson(12000), 12000);
      expect(converter.toJson(null), isNull);
    });
  });

  group('EpochMillisConverter', () {
    const converter = EpochMillisConverter();

    test('reads epoch millis and legacy ISO strings', () {
      final fromMillis = converter.fromJson(1700000000000);
      expect(fromMillis, isNotNull);
      expect(fromMillis!.isUtc, isTrue);

      final fromIso = converter.fromJson('2023-11-14T22:13:20.000Z');
      expect(fromIso, fromMillis);
    });

    test('writes epoch millis', () {
      expect(converter.toJson(null), isNull);
      expect(converter.toJson(DateTime.fromMillisecondsSinceEpoch(1700000000000)), 1700000000000);
    });
  });

  group('LiveStatusByNameConverter', () {
    const converter = LiveStatusByNameConverter();

    test('reads names and legacy v1 index ints', () {
      expect(converter.fromJson('live'), LiveStatus.live);
      expect(converter.fromJson(1), LiveStatus.replay);
      expect(converter.fromJson('nope'), isNull);
      expect(converter.fromJson(null), isNull);
    });

    test('writes names', () {
      expect(converter.toJson(LiveStatus.live), 'live');
      expect(converter.toJson(null), isNull);
    });
  });

  group('UriStringConverter / StringifyConverter', () {
    const uriConverter = UriStringConverter();
    const stringify = StringifyConverter();

    test('UriStringConverter tolerates garbage', () {
      expect(uriConverter.fromJson('https://live.example.com/1'), Uri.parse('https://live.example.com/1'));
      expect(uriConverter.fromJson('::::'), isNull);
      expect(uriConverter.fromJson(''), isNull);
      expect(uriConverter.toJson(Uri.parse('https://x.example.com')), 'https://x.example.com');
    });

    test('StringifyConverter handles numeric ids', () {
      expect(stringify.fromJson(23058), '23058');
      expect(stringify.fromJson('9999.0'), '9999');
      expect(stringify.toJson('23058'), '23058');
    });
  });

  group('RoomAudience', () {
    test('reads legacy string counts into int? fields', () {
      final audience = RoomAudience.fromJson({'popularity': '1.2万', 'onlineViewers': 3400});
      expect(audience.popularity, 12000);
      expect(audience.onlineViewers, 3400);
      expect(audience.totalViewers, isNull);
    });

    test('sparse merge keeps stored values', () {
      const stored = RoomAudience(
        popularity: 12000,
        onlineViewers: 3400,
        primaryMetric: LiveAudienceMetricType.popularity,
      );
      final merged = stored.mergedWith(const RoomAudience(onlineViewers: 3500));
      expect(merged.popularity, 12000);
      expect(merged.onlineViewers, 3500);
      expect(merged.primaryMetric, LiveAudienceMetricType.popularity);

      final unknown = stored.mergedWith(const RoomAudience(primaryMetric: LiveAudienceMetricType.unknown));
      expect(unknown.primaryMetric, LiveAudienceMetricType.popularity);
    });
  });
}
