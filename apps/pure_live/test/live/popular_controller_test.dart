import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/browse/sites_providers.dart' show sitesProvider;
import 'package:pure_live/features/settings/browse/sites_display_provider.dart'
    show sitesDisplayProvider, sitesOrderProvider;
import 'package:pure_live/modules/live/popular/popular_controller.dart';
import 'package:pure_live/shared/shared.dart' show showUnplayableProvider;

/// The popular catalog over fake discovery sites: the platform list's
/// filters, the walk's dedup and its place across a visibility flip, the
/// pager's local moves, the resize's first-room rule, and the small
/// choices — the shown platform and the inline search word.
void main() {
  late StorageStores stores;
  late ProviderContainer container;

  /// The fake registry's current sites; the provider override reads it.
  var currentSites = const <LiveSite>[];

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    container = ProviderContainer(overrides: [sitesProvider.overrideWith((ref) => LiveSiteRegistry(currentSites))]);
    addTearDown(container.dispose);
  });

  tearDown(() => stores.close());

  LiveRoom roomOf(String platform, String id) => LiveRoom.normalized(
    platform: platform,
    roomId: id,
    content: RoomContent.of(title: 'Room $id'),
  );

  LiveRoom restrictedRoomOf(String platform, String id) =>
      roomOf(platform, id).rebuild((b) => b..broadcast.restriction = LiveRestriction.needsLogin);

  List<LiveRoom> roomsOf(String platform, int from, int to) => [
    for (var i = from; i <= to; i++) roomOf(platform, '$i'),
  ];

  LivePage<LiveRoom> pageOf(List<LiveRoom> rooms, {bool hasMore = false}) =>
      LivePage<LiveRoom>.of(items: rooms, hasMore: hasMore);

  /// Installs the fake registry and re-reads the catalog against it.
  void installSites(List<LiveSite> sites) {
    currentSites = sites;
    container.invalidate(sitesProvider);
  }

  /// A fresh container over the same stores (the shown platform's
  /// persistence checks re-read the choice through one).
  ProviderContainer freshContainer() {
    final next = ProviderContainer(overrides: [sitesProvider.overrideWith((ref) => LiveSiteRegistry(currentSites))]);
    addTearDown(next.dispose);
    return next;
  }

  PopularFeedState feedOf(String platform) => container.read(popularCatalogProvider.notifier).feedOf(platform);

  test('the platform list follows the viewer order, names discovery sites only, and follows the display', () async {
    installSites([
      _FakePopularSite('popa', pages: {}, asked: []),
      _FakePopularSite('popb', pages: {}, asked: [], noDiscovery: true),
      _FakePopularSite('popc', pages: {}, asked: []),
    ]);
    final catalog = container.read(popularCatalogProvider.notifier);
    // The capability-less platform never names a tab.
    expect(catalog.platformIds(), ['popa', 'popc']);

    // The viewer's own order leads, the registry's fills the rest.
    await container.read(sitesOrderProvider.notifier).setOrder(['popc', 'popb', 'popa']);
    expect(catalog.platformIds(), ['popc', 'popa']);

    // A platform hidden in the settings leaves the tabs too.
    expect(await container.read(sitesDisplayProvider.notifier).toggle('popa'), isTrue);
    expect(catalog.platformIds(), ['popc']);
  });

  test('a platform without recommendations names the missing capability', () async {
    installSites([_FakePopularSite('popx', pages: {}, asked: [], noDiscovery: true)]);
    final catalog = container.read(popularCatalogProvider.notifier);
    expect(catalog.platformIds(), isEmpty);

    await catalog.open('popx');
    final feed = feedOf('popx');
    expect(feed.rooms, isEmpty);
    expect(feed.loading, isFalse);
    expect(feed.hasMore, isFalse);
    expect(feed.error, isNotNull);
  });

  test('open loads the first window once, and a re-open asks nothing', () async {
    final asked = <int>[];
    installSites([
      _FakePopularSite('popa', pages: {1: Right(pageOf(roomsOf('popa', 1, 30), hasMore: true))}, asked: asked),
    ]);
    final catalog = container.read(popularCatalogProvider.notifier);

    await catalog.open('popa');
    final feed = feedOf('popa');
    expect(feed.rooms.length, 30);
    expect(feed.page, 1);
    expect(feed.pageSize, 30); // the platform's own window, not a setting
    expect(feed.hidden, 0);
    expect(feed.hasMore, isTrue);
    expect(feed.loading, isFalse);
    expect(feed.error, isNull);
    expect(asked, [1]);

    // The catalogue stays per platform: re-selecting the tab refetches nothing.
    await catalog.open('popa');
    expect(asked, [1]);
  });

  test('loadMore appends the next block, drops the overlap, and stops at the end', () async {
    final asked = <int>[];
    installSites([
      _FakePopularSite(
        'popa',
        pages: {
          1: Right(pageOf(roomsOf('popa', 1, 30), hasMore: true)),
          2: Right(pageOf([roomOf('popa', '30'), roomOf('popa', '31')])),
        },
        asked: asked,
      ),
    ]);
    final catalog = container.read(popularCatalogProvider.notifier);
    await catalog.open('popa');

    // The repeated room drops; the chunk lands whole.
    await catalog.loadMore('popa');
    final feed = feedOf('popa');
    expect(feed.rooms.length, 31);
    expect(feed.rooms.last.identityKey, 'popa:31');
    expect(feed.hasMore, isFalse);
    expect(asked, [1, 2]);

    // The ended walk is asked for nothing more.
    await catalog.loadMore('popa');
    expect(asked, [1, 2]);
  });

  test('the pager moves local pages without a request, fetches past the held rooms, and clamps at the end', () async {
    final asked = <int>[];
    installSites([
      _FakePopularSite(
        'popa',
        pages: {1: Right(pageOf(roomsOf('popa', 1, 30), hasMore: true)), 2: Right(pageOf(roomsOf('popa', 31, 60)))},
        asked: asked,
      ),
    ]);
    final catalog = container.read(popularCatalogProvider.notifier);
    await catalog.open('popa');

    // Page 2 is beyond the held rooms: the walk fetches it.
    await catalog.loadPage('popa', 2);
    var feed = feedOf('popa');
    expect(feed.rooms.length, 60);
    expect(feed.page, 2);
    expect(asked, [1, 2]);

    // Page 1 is a local slice: it moves without a request.
    await catalog.loadPage('popa', 1);
    expect(feedOf('popa').page, 1);
    expect(asked, [1, 2]);

    // A page past the ended catalogue clamps to the last real one.
    await catalog.loadPage('popa', 5);
    feed = feedOf('popa');
    expect(feed.page, 2);
    expect(feed.rooms.length, 60);
    expect(asked, [1, 2]);

    // The pager's count: the local slices, no plus-one at the end.
    expect(pageCountOf(feed), 2);
  });

  test('a refresh failure keeps the old catalogue, and the retry walks from page 1', () async {
    final asked = <int>[];
    final site = _FakePopularSite(
      'popa',
      pages: {1: Right(pageOf(roomsOf('popa', 1, 30), hasMore: true))},
      asked: asked,
    );
    installSites([site]);
    final catalog = container.read(popularCatalogProvider.notifier);
    await catalog.open('popa');

    site.pages = {1: const Left(LiveSiteError.network(siteId: 'popa', message: 'down'))};
    await catalog.refresh('popa');
    var feed = feedOf('popa');
    expect(feed.error, isNotNull);
    expect(feed.rooms.length, 30); // the old catalogue stays on screen
    expect(feed.loading, isFalse);
    // The refresh built a fresh walk: the failed page is page 1 again.
    expect(asked, [1, 1]);

    site.pages = {1: Right(pageOf(roomsOf('popa', 1, 30), hasMore: true))};
    await catalog.refresh('popa');
    feed = feedOf('popa');
    expect(feed.error, isNull);
    expect(feed.rooms.length, 30);
    expect(asked, [1, 1, 1]);
  });

  test('the discovery filter hides and counts, and a setting change re-shows without a request', () async {
    final asked = <int>[];
    installSites([
      _FakePopularSite(
        'popa',
        pages: {
          1: Right(pageOf([restrictedRoomOf('popa', 'login'), ...roomsOf('popa', 1, 29)], hasMore: true)),
        },
        asked: asked,
      ),
    ]);
    final catalog = container.read(popularCatalogProvider.notifier);
    await catalog.open('popa');
    expect(feedOf('popa').rooms.length, 29);
    expect(feedOf('popa').hidden, 1);
    expect(feedOf('popa').rooms.any((room) => room.identityKey == 'popa:login'), isFalse);

    // The setting flips: the fetched rooms re-filter in place, asking nothing.
    container.read(showUnplayableProvider.notifier).setShow(value: true);
    await pumpEventQueue();
    final feed = feedOf('popa');
    expect(feed.rooms.length, 30);
    expect(feed.rooms.first.identityKey, 'popa:login');
    expect(feed.hidden, 0);
    expect(asked, [1]);
  });

  test('a visibility flip keeps the walk in place, so the next block still arrives', () async {
    final asked = <int>[];
    installSites([
      _FakePopularSite(
        'popa',
        pages: {
          1: Right(pageOf([restrictedRoomOf('popa', 'login'), ...roomsOf('popa', 1, 29)], hasMore: true)),
          2: Right(pageOf(roomsOf('popa', 30, 59), hasMore: true)),
          3: Right(pageOf(roomsOf('popa', 60, 89))),
        },
        asked: asked,
      ),
    ]);
    final catalog = container.read(popularCatalogProvider.notifier);
    await catalog.open('popa');
    expect(feedOf('popa').rooms.length, 29);
    await catalog.loadMore('popa');
    expect(feedOf('popa').rooms.length, 59);
    expect(asked, [1, 2]);

    // The flip re-shows the hidden room — and must not throw the walk's
    // place away: a fresh walk would replay the fetched pages, starve the
    // stagnation rule, and end the feed while the platform has more.
    container.read(showUnplayableProvider.notifier).setShow(value: true);
    await pumpEventQueue();
    expect(feedOf('popa').rooms.length, 60);
    expect(feedOf('popa').hidden, 0);

    await catalog.loadMore('popa');
    final feed = feedOf('popa');
    expect(feed.rooms.length, 90);
    expect(feed.hasMore, isFalse);
    expect(asked, [1, 2, 3]);
  });

  test('resize re-measures keeping the shown page, fetching only when short', () async {
    final asked = <int>[];
    installSites([
      _FakePopularSite(
        'popa',
        pages: {
          1: Right(pageOf(roomsOf('popa', 1, 30), hasMore: true)),
          2: Right(pageOf(roomsOf('popa', 31, 60), hasMore: true)),
          3: Right(pageOf(roomsOf('popa', 61, 90))),
        },
        asked: asked,
      ),
    ]);
    final catalog = container.read(popularCatalogProvider.notifier);
    await catalog.open('popa');

    // The held rooms already cover page 1 at the smaller size: no request.
    await catalog.resize('popa', 20);
    var feed = feedOf('popa');
    expect(feed.pageSize, 20);
    expect(feed.page, 1);
    expect(feed.rooms.length, 30);
    expect(asked, [1]);

    // The same size is a no-op.
    await catalog.resize('popa', 20);
    expect(asked, [1]);

    // The larger size needs rooms the walk has not brought yet.
    await catalog.resize('popa', 60);
    feed = feedOf('popa');
    expect(feed.pageSize, 60);
    expect(feed.page, 1);
    expect(feed.rooms.length, 60);
    expect(asked, [1, 2]);

    // Back on page 2 at 60, a 30-room page keeps the first room in view:
    // room 61 sits in the requested page 3.
    await catalog.loadPage('popa', 2);
    expect(feedOf('popa').page, 2);
    await catalog.resize('popa', 30);
    feed = feedOf('popa');
    expect(feed.pageSize, 30);
    expect(feed.page, 3);
    expect(feed.rooms.length, 90);
    expect(asked, [1, 2, 3]);
  });

  test('the shown platform: stored choice wins, preferred or first otherwise, and the choice writes through', () async {
    installSites([_FakePopularSite('popa', pages: {}, asked: []), _FakePopularSite('popb', pages: {}, asked: [])]);
    // No local choice and no preference: the first platform opens.
    expect(container.read(popularSiteProvider), 'popa');

    // The choice writes through: a fresh read lands on it.
    container.read(popularSiteProvider.notifier).selected = 'popb';
    await pumpEventQueue(); // the setter persists without waiting
    expect(freshContainer().read(popularSiteProvider), 'popb');

    // A stored id the platform list lost falls to the preference.
    await StoragePrefs.setString('browse.popular.site', 'ghost');
    expect(freshContainer().read(popularSiteProvider), 'popa');

    // The settings' preferred platform answers when nothing is stored.
    await container.read(sitesOrderProvider.notifier).setPreferred('popb');
    expect(freshContainer().read(popularSiteProvider), 'popb');
  });

  test('the inline search trims its word and returns to browsing', () async {
    final search = container.read(popularInlineSearchProvider.notifier);
    expect(container.read(popularInlineSearchProvider), isNull);

    search.search('  word  ');
    expect(container.read(popularInlineSearchProvider), 'word');

    search.search('   ');
    expect(container.read(popularInlineSearchProvider), isNull);

    search
      ..search('word')
      ..clear();
    expect(container.read(popularInlineSearchProvider), isNull);
  });
}

/// One fake discovery site: identity, and the recommendation pages its
/// table answers by page number, counting every ask. [noDiscovery] strips
/// the capability for the platform-list and unsupported checks.
final class _FakePopularSite implements LiveSite, LiveDiscoveryProvider {
  _FakePopularSite(this.id, {required this.pages, required this.asked, this.noDiscovery = false});

  final String id;

  /// The answers by the page the request asks; a missing page answers an
  /// empty ended page.
  Map<int, Either<LiveSiteError, LivePage<LiveRoom>>> pages;
  final List<int> asked;

  final bool noDiscovery;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request}) {
    final page = request?.page ?? 1;
    asked.add(page);
    final answer = pages[page];
    if (answer == null) {
      return Future.value(Right(LivePage<LiveRoom>.of(items: const [])));
    }
    return Future.value(answer);
  }

  @override
  LiveSiteManifest get manifest => LiveSiteManifest(id: id, name: {'en': id}, version: '1', contractVersion: '1');

  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  @override
  T? capability<T extends LiveSiteCapability>() => noDiscovery ? null : (this is T ? this as T : null);

  @override
  Future<void> initialize(LiveSiteContext context) async {}

  @override
  Future<void> dispose() async {}
}
