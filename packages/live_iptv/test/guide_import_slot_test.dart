import 'package:live_iptv/src/import/iptv_importer.dart';
import 'package:live_iptv/src/library/library.dart';
import 'package:test/test.dart';

/// The chain a guide import has to survive for the viewer to see anything:
/// the XMLTV text is parsed (off the caller's isolate since the hang fixes),
/// the +0800 wall times land as UTC instants, the channel's `tvg-id` finds
/// the guide channel without anyone mapping by hand, and the on-air
/// programme answers. A timezone read wrong shows up here as an empty
/// "what is on now" — the symptom that reads as "the guide never shows".
void main() {
  test('an imported +0800 XMLTV guide answers the on-air programme', () async {
    final library = IptvLibrary(InMemoryIptvStore());
    await library.load();
    await library.importFromText('''
#EXTM3U
#EXTINF:-1 tvg-id="cctv1" tvg-name="CCTV-1",CCTV-1 高清
http://a/1.m3u8
''', name: 'lists');

    final importer = IptvImporter(
      library: library,
      fetch: (url, {headers = const {}}) => throw StateError('no network in this test: $url'),
    );
    // Wall-clock times in the guide's own zone, anchored around now so the
    // importer's retention prune cannot eat the fixture.
    String stamp(DateTime utc) {
      final wall = utc.add(const Duration(hours: 8));
      return '${wall.year.toString().padLeft(4, '0')}'
          '${wall.month.toString().padLeft(2, '0')}'
          '${wall.day.toString().padLeft(2, '0')}'
          '${wall.hour.toString().padLeft(2, '0')}'
          '${wall.minute.toString().padLeft(2, '0')}'
          '${wall.second.toString().padLeft(2, '0')} +0800';
    }

    final now = DateTime.now().toUtc();
    final xml =
        '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="cctv1">
    <display-name>CCTV-1</display-name>
  </channel>
  <programme channel="cctv1" start="${stamp(now.subtract(const Duration(minutes: 30)))}" stop="${stamp(now.add(const Duration(minutes: 30)))}">
    <title>新闻联播</title>
  </programme>
  <programme channel="cctv1" start="${stamp(now.add(const Duration(minutes: 30)))}" stop="${stamp(now.add(const Duration(minutes: 90)))}">
    <title>焦点访谈</title>
  </programme>
</tv>
''';
    final result = await importer.importGuideText(xml, name: '中央', source: 'http://guide.example/epg.xml');
    expect(result.isImported, isTrue, reason: 'import verdict: ${result.status.name} ${result.error}');

    final channel = library.channels.firstWhere((entry) => entry.entry.tvgId == 'cctv1');
    final slot = library.programmeSlot(channel);
    expect(slot.current, isNotNull, reason: 'the programme on air now must answer');
    expect(slot.current!.title, '新闻联播');
    expect(slot.next?.title, '焦点访谈');
  });
}
