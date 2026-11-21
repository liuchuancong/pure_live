import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/browse/sites_providers.dart' show sitesProvider;
import 'package:pure_live/features/settings/browse/sites_display_provider.dart';

/// A platform the registry can carry without any of its own machinery:
/// identity only, no capabilities, no lifecycle.
final class _StubSite implements LiveSite {
  const _StubSite(this.id);

  final String id;

  @override
  LiveSiteManifest get manifest => LiveSiteManifest(id: id, name: {'zh': id}, version: '1.0.0', contractVersion: '1');

  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.uninitialized);

  @override
  T? capability<T extends LiveSiteCapability>() => null;

  @override
  Future<void> initialize(LiveSiteContext context) async {}

  @override
  Future<void> dispose() async {}
}

/// The browsing pages' platform order and visibility: the default answer
/// (Bilibili when the build carries it), the stored order cleaned of what
/// the registry no longer knows, a save only taking a true rearrangement,
/// the hidden set's legacy translation and its one-platform floor, the
/// bulk switches keeping a live lead, and the follow list as one document.
void main() {
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  // The composition root's stand-in: three sites in registration order,
  // one of them the reference's own bilibili.
  LiveSiteRegistry registry() =>
      LiveSiteRegistry([const _StubSite('alpha'), const _StubSite('bilibili'), const _StubSite('gamma')]);

  ProviderContainer containerWith(LiveSiteRegistry sites) {
    final container = ProviderContainer(overrides: [sitesProvider.overrideWithValue(sites)]);
    addTearDown(container.dispose);
    return container;
  }

  group('the default answer', () {
    test('bilibili wins when the build carries it, else the first, else nobody', () {
      expect(defaultPreferredSiteId(['gamma', 'bilibili', 'alpha']), 'bilibili'); // anywhere in the list
      expect(defaultPreferredSiteId(['gamma', 'alpha']), 'gamma');
      expect(defaultPreferredSiteId(const <String>[]), '');
    });
  });

  group('the order', () {
    test('a fresh start reads the registry, and bilibili leads it', () {
      final order = containerWith(registry()).read(sitesOrderProvider);

      expect(order.order, ['alpha', 'bilibili', 'gamma']);
      expect(order.preferred, 'bilibili');
    });

    test('a stored order loses its strangers and its doubles, a new platform joins at its registry place', () async {
      await StoragePrefs.setStringList(SitesOrderController.orderKey, ['gamma', 'ghost', 'alpha', 'gamma']);
      final order = containerWith(registry()).read(sitesOrderProvider);

      expect(order.order, ['gamma', 'alpha', 'bilibili']); // ghost gone, one gamma left, bilibili appended
    });

    test('the stored lead reads only when the registry knows it', () async {
      await StoragePrefs.setString(SitesOrderController.preferredKey, 'gamma');
      expect(containerWith(registry()).read(sitesOrderProvider).preferred, 'gamma');

      await StoragePrefs.setString(SitesOrderController.preferredKey, 'ghost');
      expect(containerWith(registry()).read(sitesOrderProvider).preferred, 'bilibili'); // the default stands in
    });

    test('a save only takes a true rearrangement, and the one it takes survives the store', () async {
      final container = containerWith(registry());
      final controller = container.read(sitesOrderProvider.notifier);

      await controller.setOrder(['gamma', 'bilibili', 'alpha']); // the whole order, moved
      expect(container.read(sitesOrderProvider).order, ['gamma', 'bilibili', 'alpha']);
      expect(container.read(sitesOrderProvider).preferred, 'bilibili'); // the lead is not the order
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(containerWith(registry()).read(sitesOrderProvider).order, ['gamma', 'bilibili', 'alpha']);

      await controller.setOrder(['gamma', 'bilibili']); // a platform dropped
      await controller.setOrder(['gamma', 'bilibili', 'alpha', 'ghost']); // a stranger joined
      expect(container.read(sitesOrderProvider).order, ['gamma', 'bilibili', 'alpha']); // both refused
    });

    test('reset goes back to the registry and its default lead, through the store', () async {
      final container = containerWith(registry());
      final controller = container.read(sitesOrderProvider.notifier);
      await controller.setOrder(['gamma', 'bilibili', 'alpha']);
      await controller.setPreferred('gamma');

      await controller.reset();
      expect(container.read(sitesOrderProvider).order, ['alpha', 'bilibili', 'gamma']);
      expect(container.read(sitesOrderProvider).preferred, 'bilibili');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final restored = containerWith(registry()).read(sitesOrderProvider);
      expect(restored.order, ['alpha', 'bilibili', 'gamma']);
      expect(restored.preferred, 'bilibili');
    });

    test('the preferred site resolves against the registry', () {
      expect(containerWith(registry()).read(preferredSiteProvider).manifest.id, 'bilibili');
    });
  });

  group('the hidden set', () {
    test('nothing hidden shows everything, in the order', () {
      final container = containerWith(registry());
      final display = container.read(sitesDisplayProvider.notifier);

      expect(container.read(sitesDisplayProvider), isEmpty);
      expect(display.shown('gamma'), isTrue);
      expect(display.visibleIds(), ['alpha', 'bilibili', 'gamma']);
    });

    test('the legacy key held the shown ids, read once as their complement', () async {
      await StoragePrefs.setStringList(SitesDisplayController.legacyKey, ['alpha']);
      expect(containerWith(registry()).read(sitesDisplayProvider), {'bilibili', 'gamma'});

      // the hidden set's own key outranks the legacy one
      await StoragePrefs.setStringList(SitesDisplayController.hiddenKey, ['gamma']);
      expect(containerWith(registry()).read(sitesDisplayProvider), {'gamma'});
    });

    test('a switch hides, unhides, and refuses to turn the last one off', () async {
      final container = containerWith(registry());
      final display = container.read(sitesDisplayProvider.notifier);

      expect(await display.toggle('gamma'), isTrue);
      expect(container.read(sitesDisplayProvider), {'gamma'});
      expect(display.visibleIds(), ['alpha', 'bilibili']);

      expect(await display.toggle('gamma'), isTrue); // back on: gone from the set
      expect(container.read(sitesDisplayProvider), isEmpty);

      await display.toggle('alpha');
      await display.toggle('gamma');
      expect(await display.toggle('bilibili'), isFalse); // the last one shown stays
      expect(container.read(sitesDisplayProvider), {'alpha', 'gamma'});
    });

    test('hiding the lead hands it to the first one still shown', () async {
      final container = containerWith(registry());
      final display = container.read(sitesDisplayProvider.notifier);

      expect(await display.toggle('bilibili'), isTrue);
      expect(container.read(sitesOrderProvider).preferred, 'alpha'); // the first still shown
    });

    test('show-all clears the set only when something was hidden', () async {
      final container = containerWith(registry());
      final display = container.read(sitesDisplayProvider.notifier);

      expect(await display.setAllShown(value: true), isFalse); // already all shown
      expect(await display.toggle('gamma'), isTrue);
      expect(await display.setAllShown(value: true), isTrue);
      expect(container.read(sitesDisplayProvider), isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(containerWith(registry()).read(sitesDisplayProvider), isEmpty); // the clearing survives
    });

    test('all-off keeps a platform, and the lead follows it when it rode a hidden one', () async {
      // the preference riding a platform this build hides: prefs from
      // another build may disagree with this registry's visibility
      await StoragePrefs.setStringList(SitesDisplayController.hiddenKey, ['bilibili']);
      final container = containerWith(registry());
      final display = container.read(sitesDisplayProvider.notifier);
      expect(container.read(sitesOrderProvider).preferred, 'bilibili'); // stored, still the lead

      expect(await display.setAllShown(value: false), isTrue);
      expect(container.read(sitesDisplayProvider), {'bilibili', 'gamma'}); // alpha, the first shown, kept
      expect(container.read(sitesOrderProvider).preferred, 'alpha'); // the lead followed the kept one
    });

    test('all-off with one platform left keeps it and answers no', () async {
      await StoragePrefs.setStringList(SitesDisplayController.hiddenKey, ['alpha', 'gamma']);
      final container = containerWith(registry());
      final display = container.read(sitesDisplayProvider.notifier);
      expect(display.visibleIds(), ['bilibili']);

      expect(await display.setAllShown(value: false), isFalse);
      expect(container.read(sitesDisplayProvider), {'alpha', 'gamma'}); // untouched
    });

    test('a saved draft keeps one platform and moves the lead off a hidden one', () async {
      final container = containerWith(registry());
      final display = container.read(sitesDisplayProvider.notifier);

      expect(await display.setHidden({'alpha', 'bilibili', 'gamma'}), isFalse); // nothing left to show
      expect(container.read(sitesDisplayProvider), isEmpty); // the refusal changed nothing

      expect(await display.setHidden({'bilibili'}), isTrue);
      expect(container.read(sitesDisplayProvider), {'bilibili'});
      expect(container.read(sitesOrderProvider).preferred, 'alpha'); // the lead left the hidden one
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(containerWith(registry()).read(sitesDisplayProvider), {'bilibili'}); // the draft survives
    });

    test('the visible list rides the order the viewer saved', () async {
      final container = containerWith(registry());
      await container.read(sitesOrderProvider.notifier).setOrder(['gamma', 'bilibili', 'alpha']);
      await container.read(sitesDisplayProvider.notifier).toggle('gamma');

      expect(container.read(sitesDisplayProvider.notifier).visibleIds(), ['bilibili', 'alpha']);
    });
  });

  group('the follow document', () {
    LiveRoom room(String platform, String roomId) => LiveRoom.normalized(platform: platform, roomId: roomId);

    test('the document round trips its rooms', () {
      final restored = decodeFollows(encodeFollows([room('douyin', '9'), room('Alpha', ' 42 ')]));

      expect(restored, hasLength(2));
      expect(restored?[0].ref.platform, 'douyin');
      expect(restored?[0].ref.roomId, '9');
      expect(restored?[1].ref.platform, 'alpha'); // the room's own normalization rides along
      expect(restored?[1].ref.roomId, '42');
    });

    test('words that are not a document answer nothing', () {
      expect(decodeFollows('not json'), isNull);
      expect(decodeFollows('{"a": 1}'), isNull); // an object, not a list
    });

    test('entries that are not rooms pass silently', () {
      expect(decodeFollows('[42, null, "junk"]'), isEmpty); // an empty document, not a failed one
    });

    test('a room the parser cannot read fails the whole document', () {
      expect(decodeFollows('[{"ref": 7}]'), isNull);
    });
  });
}
