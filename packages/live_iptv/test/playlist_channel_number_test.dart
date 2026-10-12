import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/playlist/playlist_parser.dart';
import 'package:test/test.dart';

/// The tests reach into `src/` rather than the package barrel on purpose:
/// the barrel also exports the library and its store, and those are held by
/// a storage migration that is still in flight. Parsing and ranking need no
/// storage, and neither should the tests that check them.
void main() {
  group('channelNumberOf', () {
    test('reads tvg-chno, dropping the provider leading zeros', () {
      final entries = parseM3u('''
#EXTM3U
#EXTINF:-1 tvg-chno="001" tvg-name="CCTV1",CCTV1
http://a/1.m3u8
''');

      expect(entries.single.channelNumber, 1);
    });

    test('reads tvg-number when a provider writes that instead', () {
      final entries = parseM3u('''
#EXTM3U
#EXTINF:-1 tvg-number="203",Hunan
http://a/2.m3u8
''');

      expect(entries.single.channelNumber, 203);
    });

    test('prefers tvg-chno when both are present', () {
      final entries = parseM3u('''
#EXTM3U
#EXTINF:-1 tvg-chno="9" tvg-number="70",One
http://a/1.m3u8
''');

      expect(entries.single.channelNumber, 9);
    });

    test('a value that is not a number is no number', () {
      final entries = parseM3u('''
#EXTM3U
#EXTINF:-1 tvg-chno="01CCTV",CCTV1
http://a/1.m3u8
''');

      expect(entries.single.channelNumber, isNull);
    });

    test('zero and a negative are no number either', () {
      final entries = parseM3u('''
#EXTM3U
#EXTINF:-1 tvg-chno="0",Zero
http://a/1.m3u8
#EXTINF:-1 tvg-chno="-4",Negative
http://a/2.m3u8
''');

      expect(entries.map((entry) => entry.channelNumber), [isNull, isNull]);
    });

    test('an entry with no number attribute stays unnumbered', () {
      final entries = parseM3u('''
#EXTM3U
#EXTINF:-1,Plain
http://a/1.m3u8
''');

      expect(entries.single.channelNumber, isNull);
    });
  });

  group('the number survives storage', () {
    test('an entry written to JSON and read back keeps its number', () {
      final entries = parseM3u('''
#EXTM3U
#EXTINF:-1 tvg-chno="12" group-title="CCTV",CCTV12
http://a/12.m3u8
''');
      final entry = entries.single;
      final restored = IptvEntry.fromJson(entry.toJson());

      expect(restored, entry);
      expect(restored.channelNumber, 12);
      expect(restored.group, 'CCTV');
    });

    test('a stored entry from before numbers existed reads back unnumbered', () {
      final restored = IptvEntry.fromJson({'name': 'Old', 'url': 'http://a/1'});

      expect(restored.channelNumber, isNull);
    });
  });
}
