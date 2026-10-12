import 'package:live_iptv/src/library/library.dart';
import 'package:live_iptv/src/model/model.dart';
import 'package:test/test.dart';

/// One guide source, shared by every expectation below.
const epgSource = EpgSource(id: 'epg-1', name: '中央台', source: 'http://guide.example/epg.xml');

/// The storage key of guide channel [channelId] under [epgSource].
String keyOf(String channelId) => epgChannelKey('epg-1', channelId);

/// A three-line list: one channel naming its guide id, one only resembling
/// the guide by name, and one no guide mentions at all.
const String playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="cctv1",CCTV-1 高清
http://a/1.m3u8
#EXTINF:-1,湖南卫视
http://a/2.m3u8
#EXTINF:-1,购物频道
http://a/3.m3u8
''';

void main() {
  late IptvLibrary library;
  late DateTime firstStart;
  late DateTime now;

  IptvChannel channel(String name) => library.channels.firstWhere((entry) => entry.entry.name == name);

  setUp(() async {
    library = IptvLibrary(InMemoryIptvStore());
    await library.load();
    // Anchored to the clock the importer prunes against: programmes that
    // already stopped are deleted after a guide import, so a fixture with
    // fixed dates would be eaten by the very code under test.
    firstStart = DateTime.now().toUtc().subtract(const Duration(minutes: 30));
    await library.importFromText(playlist, name: 'lists');
    await library.saveGuide(
      epgSource,
      [
        const EpgChannel(sourceId: 'epg-1', channelId: 'cctv1', displayName: 'CCTV 1 综合'),
        const EpgChannel(sourceId: 'epg-1', channelId: 'hunan', displayName: '湖南卫视 综合'),
      ],
      [
        EpgProgramme(
          channelId: 'cctv1',
          sourceId: 'epg-1',
          start: firstStart,
          stop: firstStart.add(const Duration(hours: 2)),
          title: '新闻联播',
        ),
        EpgProgramme(
          channelId: 'cctv1',
          sourceId: 'epg-1',
          start: firstStart.add(const Duration(hours: 2)),
          stop: firstStart.add(const Duration(hours: 4)),
          title: '焦点访谈',
        ),
        EpgProgramme(
          channelId: 'hunan',
          sourceId: 'epg-1',
          start: firstStart,
          stop: firstStart.add(const Duration(hours: 3)),
          title: '金鹰剧场',
        ),
      ],
    );
    now = firstStart.add(const Duration(minutes: 30));
  });

  tearDown(() => library.dispose());

  group('guideKeyFor', () {
    test('follows the tvg-id the playlist declared', () {
      expect(library.guideKeyFor(channel('CCTV-1 高清')), keyOf('cctv1'));
    });

    test('falls back to the normalized name, which is why 高清 does not matter', () {
      expect(library.guideKeyFor(channel('湖南卫视')), keyOf('hunan'));
    });

    test('a channel no guide mentions has no key rather than a wrong one', () {
      expect(library.guideKeyFor(channel('购物频道')), isNull);
      expect(library.schedule(channel('购物频道'), from: now), isEmpty);
    });
  });

  group('programmeSlot', () {
    test('names what is on and what follows it', () {
      final slot = library.programmeSlot(channel('CCTV-1 高清'), now: now);

      expect(slot.current?.title, '新闻联播');
      expect(slot.next?.title, '焦点访谈');
      expect(slot.isEmpty, isFalse);
      expect(slot.title, '新闻联播');
    });

    test('progress and remaining time are read against the instant asked for', () {
      final slot = library.programmeSlot(channel('CCTV-1 高清'), now: now);

      expect(slot.progress, closeTo(0.25, 0.001));
      expect(slot.remaining, const Duration(minutes: 90));
      expect(slot.untilNext, const Duration(minutes: 90));
    });

    test('a channel with no programme list is empty, not off the air', () {
      final slot = library.programmeSlot(channel('购物频道'), now: now);

      expect(slot.isEmpty, isTrue);
      expect(slot.current, isNull);
      expect(slot.title, isNull);
      expect(slot.progress, isNull);
    });

    test('after the last programme there is nothing on and nothing next', () {
      final late = library.programmeSlot(channel('CCTV-1 高清'), now: firstStart.add(const Duration(hours: 6)));

      expect(late.isEmpty, isTrue);
    });
  });

  group('schedule', () {
    test('walks forward from the moment asked for', () {
      final list = library.schedule(channel('CCTV-1 高清'), from: now);

      expect(list.map((programme) => programme.title), ['新闻联播', '焦点访谈']);
      // The programme already under way is part of the schedule, which is the
      // whole point of a guide row: a viewer joining at 20:40 still wants to
      // know that the film started at 20:15.
      expect(list.first.start.isAfter(now), isFalse);
    });
  });

  group('mappings', () {
    test('autoMatch records what it decided and answers how many', () async {
      final written = await library.autoMatch(sourceId: 'epg-1');

      expect(written, greaterThanOrEqualTo(2));
      expect(library.mappingFor(channel('湖南卫视').id)?.epgChannelKey, keyOf('hunan'));
    });

    test('a locked mapping outranks the matcher, and the matcher leaves it alone', () async {
      final cctv = channel('CCTV-1 高清');
      await library.assignGuide(channelId: cctv.id, epgSourceId: 'epg-1', epgChannelKey: keyOf('hunan'));

      expect(library.guideKeyFor(cctv), keyOf('hunan'));
      await library.autoMatch(sourceId: 'epg-1');
      expect(library.guideKeyFor(cctv), keyOf('hunan'));
      expect(library.mappingFor(cctv.id)?.locked, isTrue);
      expect(library.mappingFor(cctv.id)?.origin, 'user');
    });

    test('releasing a mapping leaves the channel unmapped until the next run', () async {
      final cctv = channel('CCTV-1 高清');
      await library.assignGuide(channelId: cctv.id, epgSourceId: 'epg-1', epgChannelKey: keyOf('hunan'));
      await library.releaseGuide(cctv.id);

      expect(library.mappingFor(cctv.id), isNull);
      // The live fallback still resolves it by tvg-id, which is the point:
      // releasing is not muting.
      expect(library.guideKeyFor(cctv), keyOf('cctv1'));
    });

    test('a locked pin survives its guide channel disappearing', () async {
      final cctv = channel('CCTV-1 高清');
      await library.assignGuide(channelId: cctv.id, epgSourceId: 'epg-1', epgChannelKey: keyOf('gone'));

      // The viewer asked for that channel; the guide has it not. The key is
      // still theirs, and the programme list is simply empty for now.
      expect(library.guideKeyFor(cctv), keyOf('gone'));
      expect(library.programmeSlot(cctv, now: now).isEmpty, isTrue);
    });
  });

  group('searchGuideChannels', () {
    test('narrows the guide by name for the mapping editor', () {
      expect(library.searchGuideChannels('epg-1', '湖南卫视').map((channel) => channel.channelId), ['hunan']);
      expect(library.searchGuideChannels('epg-1', '').length, 2);
      expect(library.searchGuideChannels('epg-1', '不存在的台'), isEmpty);
    });
  });
}
