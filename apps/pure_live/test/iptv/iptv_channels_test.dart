import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_browse_settings.dart'
    show IptvChannelOrder, iptvBrowseSettingsProvider, iptvGroupsProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart'
    show
        IptvChannelScope,
        IptvChannelsState,
        iptvChannelsProvider,
        iptvImporterProvider,
        iptvLibraryProvider,
        iptvSearchHandoffProvider,
        kIptvRevealStep;
import 'package:pure_live/modules/iptv/controllers/iptv_sources_controller.dart' show iptvSourcesProvider;

/// The channels browser over the real library on the in-memory store, with
/// only the network fetch faked: the group and playlist filters and their
/// fallbacks, the favourites scope, the query's four fields and its
/// complete-answer rule, the reveal's pages and its stale-turn drop, the
/// name order, and the group switches the settings page flips.
void main() {
  late StorageStores stores;
  late ProviderContainer container;

  /// The real importer over the real library; only the download seam is
  /// the test's table.
  IptvImporter? importerOf(Ref ref) {
    final library = ref.watch(iptvLibraryProvider).value;
    if (library == null) return null;
    return IptvImporter(
      library: library,
      fetch: (url, {headers = const {}}) async {
        throw StateError('no answer for $url');
      },
    );
  }

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    container = ProviderContainer(overrides: [iptvImporterProvider.overrideWith(importerOf)]);
    addTearDown(container.dispose);
  });

  tearDown(() => stores.close());

  String block(int from, int to, String group) =>
      [for (var i = from; i <= to; i++) '#EXTINF:-1 tvg-id="t$i.tv" group-title="$group",Chan $i\nhttp://s/$i\n']
          .join();

  /// 70 + 5 + 3 channels over three groups, unpadded names so the name
  /// order and the library's own order disagree.
  final mainList = '#EXTM3U\n#PLAYLIST:Main\n${block(1, 70, 'G1')}${block(71, 75, 'G2')}${block(76, 78, 'G3')}';

  /// A second playlist sharing Chan 1's address and carrying one channel of
  /// its own.
  const sideList =
      '#EXTM3U\n#PLAYLIST:Side\n'
      '#EXTINF:-1 tvg-id="t1.tv" group-title="G1",Chan 1\nhttp://s/1\n'
      '#EXTINF:-1 tvg-id="s90.tv" group-title="S1",Side Only\nhttp://s/90\n';

  /// Imports the main list and leaves the mirror settled on it.
  Future<void> importMain() async {
    await container.read(iptvLibraryProvider.future);
    final sources = container.read(iptvSourcesProvider.notifier);
    final preview = await sources.previewText(mainList);
    await sources.commitPreview(preview, name: 'Main');
    container.read(iptvChannelsProvider);
    await pumpEventQueue();
  }

  IptvChannelsState state() => container.read(iptvChannelsProvider);

  test('the mirror opens on the first page and counts its groups', () async {
    await importMain();
    final library = container.read(iptvLibraryProvider).value!;
    expect(state().ready, isTrue);
    expect(state().groups, library.groupNames); // largest first, the library's rank
    expect(state().groupCounts, {'G1': 70, 'G2': 5, 'G3': 3});
    expect(state().totalCount, 78);
    expect(state().libraryCount, 78);
    expect(state().channels.length, 78);
    expect(state().shown, kIptvRevealStep); // the first page, not the whole list
    expect(state().loadingMore, isFalse);
    expect(state().selectedGroup, isNull);
  });

  test('a group filters and restarts the reveal, and an unknown one is refused', () async {
    await importMain();
    container.read(iptvChannelsProvider.notifier).selectGroup('G3');
    expect(state().selectedGroup, 'G3');
    expect(state().channels.length, 3);
    expect(state().shown, 3);
    expect(state().totalCount, 78); // the library's size, whatever the filter

    container.read(iptvChannelsProvider.notifier).selectGroup('Nope');
    expect(state().selectedGroup, 'G3');

    // null is the "every group" choice, not "leave it".
    container.read(iptvChannelsProvider.notifier).selectGroup(null);
    expect(state().selectedGroup, isNull);
    expect(state().channels.length, 78);
    expect(state().shown, kIptvRevealStep);
  });

  test('the playlist filter keeps shared channels on both sides and drops emptied groups', () async {
    await importMain();
    final sources = container.read(iptvSourcesProvider.notifier);
    final preview = await sources.previewText(sideList);
    await sources.commitPreview(preview, name: 'Side');
    await pumpEventQueue();
    final sideId = container.read(iptvLibraryProvider).value!.playlistNamed('Side')!.id;

    // The shared address merged: one channel carries both lists.
    expect(state().totalCount, 79);
    final shared = state().channels.singleWhere((channel) => channel.entry.url == 'http://s/1');
    expect(shared.sources.length, 2);

    container.read(iptvChannelsProvider.notifier).selectPlaylist(sideId);
    expect(state().channels.length, 2);
    expect(state().channels.every((channel) => channel.sources.contains(sideId)), isTrue);
    // The groups the side list has no channel in leave with the filter.
    expect(state().groups, ['G1', 'S1']);
    expect(state().groupCounts, {'G1': 1, 'S1': 1});

    container.read(iptvChannelsProvider.notifier).selectPlaylist(null);
    expect(state().totalCount, 79);
  });

  test('the favourites scope is its own empty, and follows the heart from anywhere', () async {
    await importMain();
    container.read(iptvChannelsProvider.notifier).selectScope(IptvChannelScope.favourites);
    expect(state().scope, IptvChannelScope.favourites);
    expect(state().channels, isEmpty);
    // The library still counts its 78: an empty favourites list in front of
    // a stocked library is a different fact from an empty library, and the
    // page words the two differently.
    expect(state().libraryCount, 78);
    expect(state().ready, isTrue);

    final one = container.read(iptvLibraryProvider).value!.channels.first;
    await container.read(iptvLibraryProvider).value!.toggleFavorite(one.id);
    await pumpEventQueue();
    expect(state().channels.single.id, one.id);
    expect(state().libraryCount, 78); // the library's size, whatever the scope

    container.read(iptvChannelsProvider.notifier).selectScope(IptvChannelScope.all);
    expect(state().channels.length, 78);
  });

  test('the query filters by name, tvg-id and group, and answers complete', () async {
    await importMain();
    container.read(iptvChannelsProvider.notifier).setQuery('  Chan 42  ');
    expect(state().query, 'chan 42');
    expect(state().channels.single.entry.name, 'Chan 42');
    expect(state().shown, 1); // a search is complete at once

    container.read(iptvChannelsProvider.notifier).setQuery('t7.tv');
    expect(state().channels.single.entry.tvgId, 't7.tv');

    container.read(iptvChannelsProvider.notifier).setQuery('g2');
    expect(state().channels.length, 5);
    expect(state().channels.every((channel) => channel.entry.url.startsWith('http://s/7')), isTrue);

    // More matches than a page: the search still shows them all.
    container.read(iptvChannelsProvider.notifier).setQuery('chan');
    expect(state().channels.length, 78);
    expect(state().shown, 78);

    // Empty clears: the browse reveal starts over at its first page.
    container.read(iptvChannelsProvider.notifier).setQuery('');
    expect(state().shown, kIptvRevealStep);
  });

  test('loadMore reveals the next page, stops at the end, and drops a stale turn', () async {
    await importMain();
    final notifier = container.read(iptvChannelsProvider.notifier);

    await notifier.loadMore();
    expect(state().shown, 78);

    // The list is all revealed: another turn is a no-op.
    await notifier.loadMore();
    expect(state().shown, 78);

    // A filter switch while the page turn waits: the turn belongs to the
    // list that asked, so the new filter's answer stands.
    final turning = notifier.loadMore();
    notifier.setQuery('chan 42');
    await turning;
    expect(state().query, 'chan 42');
    expect(state().channels.single.entry.name, 'Chan 42');
    expect(state().loadingMore, isFalse);
  });

  test('the name order sorts the list, and the library order takes it back', () async {
    await importMain();
    // The library's own order is the import order: Chan 1, Chan 2, …
    expect(state().channels[0].entry.name, 'Chan 1');
    expect(state().channels[1].entry.name, 'Chan 2');

    await container.read(iptvBrowseSettingsProvider.notifier).setOrder(value: IptvChannelOrder.name);
    await pumpEventQueue();
    expect(state().channels[0].entry.name, 'Chan 1');
    expect(state().channels[1].entry.name, 'Chan 10'); // the alphabet over the names

    await container.read(iptvBrowseSettingsProvider.notifier).setOrder(value: IptvChannelOrder.defaultOrder);
    await pumpEventQueue();
    expect(state().channels[1].entry.name, 'Chan 2');
  });

  test('the slots name every channel the grid shows', () async {
    await importMain();
    final notifier = container.read(iptvChannelsProvider.notifier);
    final shown = state().channels.take(state().shown).map((channel) => channel.id).toSet();
    expect(state().slots.keys.toSet(), shown);

    notifier.selectGroup('G3');
    expect(state().slots.keys.toSet(), state().channels.take(state().shown).map((channel) => channel.id).toSet());

    notifier.refreshSlots();
    expect(state().slots.keys.toSet(), state().channels.take(state().shown).map((channel) => channel.id).toSet());
  });

  test('a group hidden in the settings leaves the browser and comes back whole', () async {
    await importMain();
    final groups = container.read(iptvGroupsProvider.notifier);
    expect(container.read(iptvGroupsProvider).length, 3);
    expect(container.read(iptvGroupsProvider).every((row) => !row.hidden), isTrue);

    await groups.setHidden('G2', hidden: true);
    await pumpEventQueue();
    expect(container.read(iptvGroupsProvider).singleWhere((row) => row.name == 'G2').hidden, isTrue);
    expect(state().groups, ['G1', 'G3']);
    expect(state().totalCount, 73);

    await groups.setHidden('G2', hidden: false);
    await pumpEventQueue();
    expect(state().groups, ['G1', 'G2', 'G3']);
    expect(state().totalCount, 78);
  });

  test('the search handoff is taken once', () {
    final handoff = container.read(iptvSearchHandoffProvider.notifier);
    expect(handoff.take(), isNull);

    handoff.hand('cnn');
    expect(handoff.take(), 'cnn');
    expect(handoff.take(), isNull);
  });
}
