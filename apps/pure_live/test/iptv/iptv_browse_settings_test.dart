import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_iptv/live_iptv.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_browse_settings.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart' show iptvImporterProvider, iptvLibraryProvider;
import 'package:pure_live/modules/iptv/controllers/iptv_sources_controller.dart' show iptvSourcesProvider;

/// The browse switches and the groups mirror: the reference's defaults, the
/// four switches and the order writing through to their own keys, the reset
/// that clears the order entirely, and the group rows that count and hide
/// through the library's own seam.
void main() {
  late StorageStores stores;
  late ProviderContainer container;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    container = ProviderContainer(
      overrides: [
        iptvImporterProvider.overrideWith((ref) {
          final library = ref.watch(iptvLibraryProvider).value;
          if (library == null) return null;
          return IptvImporter(
            library: library,
            fetch: (url, {headers = const {}}) async => throw StateError('no answer for $url'),
          );
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() => stores.close());

  group('the browse switches', () {
    test('the defaults are the reference standard', () {
      expect(container.read(iptvBrowseSettingsProvider), IptvBrowseSettings.standard);
    });

    test('every switch writes through to its own key', () async {
      final controller = container.read(iptvBrowseSettingsProvider.notifier);
      await controller.setShowChannelNumber(value: false);
      await controller.setReverseChannels(value: true);
      await controller.setShowClock(value: false);
      await controller.setShowProgrammeLine(value: false);

      final state = container.read(iptvBrowseSettingsProvider);
      expect(state.showChannelNumber, isFalse);
      expect(state.reverseChannels, isTrue);
      expect(state.showClock, isFalse);
      expect(state.showProgrammeLine, isFalse);
      expect(state.order, IptvChannelOrder.defaultOrder); // untouched

      await pumpEventQueue();
      expect(StoragePrefs.getBool(kIptvShowNumberPrefsKey), isFalse);
      expect(StoragePrefs.getBool(kIptvReverseChannelsPrefsKey), isTrue);
      expect(StoragePrefs.getBool(kIptvShowClockPrefsKey), isFalse);
      expect(StoragePrefs.getBool(kIptvShowProgrammePrefsKey), isFalse);

      // A fresh read of the same store lands on the same switches.
      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(next.read(iptvBrowseSettingsProvider), state);
    });

    test('the order writes its name and the reset clears it entirely', () async {
      final controller = container.read(iptvBrowseSettingsProvider.notifier);
      await controller.setReverseChannels(value: true);
      await controller.setOrder(value: IptvChannelOrder.name);
      expect(container.read(iptvBrowseSettingsProvider).order, IptvChannelOrder.name);
      await pumpEventQueue();
      expect(StoragePrefs.getString(kIptvOrderPrefsKey), 'name');

      // The same order again writes nothing new and keeps the state.
      await controller.setOrder(value: IptvChannelOrder.name);
      expect(container.read(iptvBrowseSettingsProvider).order, IptvChannelOrder.name);

      // Back to the reference's defaults: every switch, and the order key
      // gone from the store rather than parked at its default spelling.
      await controller.reset();
      final state = container.read(iptvBrowseSettingsProvider);
      expect(state, IptvBrowseSettings.standard);
      await pumpEventQueue();
      expect(StoragePrefs.getBool(kIptvReverseChannelsPrefsKey), isFalse);
      expect(StoragePrefs.getString(kIptvOrderPrefsKey), isNull);

      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(next.read(iptvBrowseSettingsProvider), IptvBrowseSettings.standard);
    });

    test('a copy replaces only what it names, and equality follows every field', () {
      const base = IptvBrowseSettings(
        showChannelNumber: true,
        reverseChannels: false,
        showClock: true,
        showProgrammeLine: true,
        order: IptvChannelOrder.name,
      );
      final copy = base.copyWith(reverseChannels: true);
      expect(copy.reverseChannels, isTrue);
      expect(copy.showChannelNumber, isTrue);
      expect(copy.order, IptvChannelOrder.name);

      expect(base, base.copyWith());
      expect(base.hashCode, base.copyWith().hashCode);
      // One flipped switch is a different setting, whatever else matches.
      for (final other in [
        base.copyWith(showChannelNumber: false),
        base.copyWith(reverseChannels: true),
        base.copyWith(showClock: false),
        base.copyWith(showProgrammeLine: false),
        base.copyWith(order: IptvChannelOrder.defaultOrder),
      ]) {
        expect(base == other, isFalse);
      }
    });
  });

  group('the groups mirror', () {
    const list =
        '#EXTM3U\n#EXTINF:-1 group-title="央视",CCTV-1\nhttp://s/1\n'
        '#EXTINF:-1 group-title="央视",CCTV-2\nhttp://s/2\n'
        '#EXTINF:-1 group-title="卫视",HTV-1\nhttp://s/3\n';

    test('the rows carry each group count in the library order', () async {
      await container.read(iptvLibraryProvider.future);
      final sources = container.read(iptvSourcesProvider.notifier);
      final preview = await sources.previewText(list);
      await sources.commitPreview(preview, name: 'Main');
      await pumpEventQueue();

      final rows = container.read(iptvGroupsProvider);
      expect(rows, [(name: '央视', channels: 2, hidden: false), (name: '卫视', channels: 1, hidden: false)]);

      // The hidden fact lives in the library, and the mirror agrees.
      await container.read(iptvGroupsProvider.notifier).setHidden('央视', hidden: true);
      final hidden = container.read(iptvGroupsProvider).singleWhere((row) => row.name == '央视');
      expect(hidden.hidden, isTrue);
      expect(container.read(iptvLibraryProvider).value!.isGroupHidden('央视'), isTrue);
      expect(container.read(iptvGroupsProvider).singleWhere((row) => row.name == '卫视').hidden, isFalse);

      // Un-hiding gives back exactly the line-up that was there.
      await container.read(iptvGroupsProvider.notifier).setHidden('央视', hidden: false);
      expect(container.read(iptvGroupsProvider), [
        (name: '央视', channels: 2, hidden: false),
        (name: '卫视', channels: 1, hidden: false),
      ]);
    });

    test('a store that has not opened yet mirrors nothing', () {
      expect(container.read(iptvGroupsProvider), isEmpty);
    });
  });
}
