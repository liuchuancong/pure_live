import 'package:live_iptv/live_iptv.dart';
import 'package:test/test.dart';

/// The group records the rank reads: a hide makes a group a record, and
/// that record must not read back as an arrangement — un-hiding gives the
/// group back its unarranged place, while a real placement (a drag, a pin)
/// still leads.
void main() {
  const list = '''
#EXTM3U
#EXTINF:-1 tvg-id="a" group-title="Alpha",A1
http://s/a1
#EXTINF:-1 tvg-id="b" group-title="Beta",B1
http://s/b1
#EXTINF:-1 tvg-id="c" group-title="Gamma",C1
http://s/c1
''';

  late IptvLibrary library;

  setUp(() async {
    library = IptvLibrary(InMemoryIptvStore());
    await library.load();
    await library.importResult(parsePlaylistResult(list), name: 'List');
  });

  tearDown(() => library.dispose());

  test('a hide and its undo leave the untouched order alone', () async {
    expect(library.groupNames, ['Alpha', 'Beta', 'Gamma']);

    // The hide gives the group its first record — a flag, not a placement.
    await library.setGroupHidden('Beta', hidden: true);
    expect(library.isGroupHidden('Beta'), isTrue);

    await library.setGroupHidden('Beta', hidden: false);
    // The record the hide made must not have promoted Beta: the untouched
    // order stands.
    expect(library.groupNames, ['Alpha', 'Beta', 'Gamma']);
  });

  test('a real placement still leads, and a pin leads it', () async {
    await library.setGroupOrder('Gamma', 0);
    expect(library.groupNames, ['Gamma', 'Alpha', 'Beta']);

    await library.setGroupPinned('Beta', pinned: true);
    expect(library.groupNames, ['Beta', 'Gamma', 'Alpha']);
  });

  test('an unpinned, unplaced record the viewer never made ranks last', () async {
    // The record a hide makes: unpinned, order -1. While hidden it shows
    // nowhere; its rank is the unarranged tail all the same.
    await library.setGroupHidden('Gamma', hidden: true);
    final ranks = library.groupRanks;
    expect(ranks['Gamma'], greaterThan(ranks['Alpha']!));
    expect(ranks['Gamma'], greaterThan(ranks['Beta']!));
  });
}
