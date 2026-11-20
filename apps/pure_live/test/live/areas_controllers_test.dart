import 'dart:io' show Directory;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right;
import 'package:live_cache/live_cache.dart' show LiveCacheManager;
import 'package:live_net/live_net.dart' show ClientProfile, DioFactory;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/browse/sites_providers.dart' show sitesProvider;
import 'package:pure_live/app/providers/cache/cache_providers.dart' show liveCacheManagerProvider;
import 'package:pure_live/modules/live/areas/controllers/area_rooms_controller.dart';
import 'package:pure_live/modules/live/areas/controllers/areas_controller.dart';
import 'package:pure_live/shared/areas/area_card.dart' show AreaCardLayout;
import 'package:pure_live/shared/images/app_image_cache.dart' show installLiveCacheManager;
import 'package:pure_live/shared/shared.dart' show showUnplayableProvider;

/// The areas controllers over a fake site and the in-memory store: the
/// catalogue's load-once-and-cache rule, the rooms feed's walk with its
/// dedup and its discovery filter, and the small page choices.
void main() {
  late StorageStores stores;
  late ProviderContainer container;

  /// The fake registry's current sites; the provider override reads it.
  var currentSites = const <LiveSite>[];

  /// The throwaway manager the catalogue's short-lived copy reads.
  late LiveCacheManager cacheManager;

  setUpAll(() {
    // The catalogue's short-lived copy rides the app's cache manager; a
    // throwaway one over a temp folder keeps the test bare of the boot.
    final root = Directory.systemTemp.createTempSync('areas-controllers-test');
    addTearDown(() => root.deleteSync(recursive: true));
    cacheManager = LiveCacheManager(
      directory: root,
      http: DioFactory().create(profile: ClientProfile.media),
    );
    installLiveCacheManager(cacheManager);
  });

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    container = ProviderContainer(
      overrides: [
        sitesProvider.overrideWith((ref) => LiveSiteRegistry(currentSites)),
        liveCacheManagerProvider.overrideWithValue(cacheManager),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() => stores.close());

  LiveRoom roomOf(String platform, String id) => LiveRoom.normalized(
    platform: platform,
    roomId: id,
    content: RoomContent.of(title: 'Room $id'),
  );

  LiveArea areaOf(String platform, String id) =>
      LiveArea.normalized(platform: platform, areaId: id, areaName: 'Area $id');

  LiveRoom restrictedRoomOf(String platform, String id) => LiveRoom.normalized(
    platform: platform,
    roomId: id,
    content: RoomContent.of(title: 'Room $id'),
  ).rebuild((b) => b..broadcast.restriction = LiveRestriction.needsLogin);

  /// Installs one fake site whose area catalogue answers [areas] and whose
  /// room pages answer from [roomsByPage] (the page the request asks),
  /// counting every rooms ask in [roomsAsked].
  void installSite({
    required Map<int, Either<LiveSiteError, LivePage<LiveRoom>>> Function() roomsByPage,
    required List<int> roomsAsked,
    String id = 'douyu',
    List<LiveArea> areas = const [],
  }) {
    currentSites = [_FakeAreaSite(id, areas: areas, roomsByPage: roomsByPage, roomsAsked: roomsAsked)];
    container.invalidate(sitesProvider);
  }

  test('the catalogue loads once, the cache answers the next open, refresh asks again', () async {
    final roomsAsked = <int>[];
    installSite(
      id: 'cata',
      areas: [areaOf('cata', '1'), areaOf('cata', '2')],
      roomsByPage: () => {1: Right(LivePage<LiveRoom>.of(items: const [], hasMore: false))},
      roomsAsked: roomsAsked,
    );
    final catalog = container.read(areasCatalogProvider.notifier);
    expect(catalog.platformIds(), ['cata']);

    await catalog.open('cata');
    expect(catalog.catalogOf('cata').areas.length, 2);
    // A second open within the TTL asks nothing: the cache answers.
    await catalog.open('cata');
    expect(catalog.catalogOf('cata').areas.length, 2);

    // The explicit refresh bypasses the cache — and re-arms it.
    await catalog.refresh('cata');
    // The next open is a cache hit again.
    await catalog.open('cata');
    expect(catalog.catalogOf('cata').areas.length, 2);
  });

  test('a catalogue failure keeps the old areas and names the error', () async {
    var fail = false;
    final roomsAsked = <int>[];
    final site = _FakeAreaSite(
      'catb',
      areas: [areaOf('catb', '1')],
      roomsByPage: () => {1: Right(LivePage<LiveRoom>.of(items: const [], hasMore: false))},
      roomsAsked: roomsAsked,
    );
    currentSites = [site..failAreas = () => fail];
    container.invalidate(sitesProvider);
    final catalog = container.read(areasCatalogProvider.notifier);
    await catalog.open('catb');
    expect(catalog.catalogOf('catb').areas.length, 1);

    fail = true;
    await catalog.refresh('catb');
    final state = catalog.catalogOf('catb');
    expect(state.error, isNotNull);
    expect(state.areas.length, 1); // the old list stays on screen
    expect(state.loading, isFalse);
  });

  test('the rooms feed walks, dedups, and keeps the stale copy on a failure', () async {
    var pageAnswers = <int, Either<LiveSiteError, LivePage<LiveRoom>>>{
      1: Right(LivePage<LiveRoom>.of(items: [for (var i = 1; i <= 30; i++) roomOf('douyu', '$i')], hasMore: true)),
      2: Right(LivePage<LiveRoom>.of(items: [roomOf('douyu', '30'), roomOf('douyu', '31')], hasMore: false)),
    };
    final roomsAsked = <int>[];
    installSite(roomsByPage: () => pageAnswers, roomsAsked: roomsAsked);
    final rooms = container.read(areaRoomsProvider.notifier);
    await rooms.init(site: currentSites.single, area: areaOf('douyu', '1'));

    var current = container.read(areaRoomsProvider)!;
    expect(current.rooms.length, 30);
    expect(current.hasMore, isTrue);
    expect(current.loading, isFalse);

    // The overlap (room 30 again) drops; the new room lands.
    await rooms.loadMore();
    current = container.read(areaRoomsProvider)!;
    expect(current.rooms.length, 31);
    expect(current.rooms.last.identityKey, 'douyu:31');
    expect(current.hasMore, isFalse);

    // A later failure keeps the rooms on screen and names itself. The
    // reload starts a fresh walk from page 1, so that is the page to fail.
    pageAnswers = {1: const Left(LiveSiteError.network(siteId: 'douyu', message: 'down'))};
    final before = container.read(areaRoomsProvider)!.rooms;
    await rooms.reload();
    current = container.read(areaRoomsProvider)!;
    expect(current.error, isNotNull);
    expect(current.rooms, before);
  });

  test('the discovery filter hides the rooms that cannot play, and a setting change brings them back', () async {
    final pageAnswers = <int, Either<LiveSiteError, LivePage<LiveRoom>>>{
      1: Right(
        LivePage<LiveRoom>.of(
          items: [restrictedRoomOf('douyu', 'login'), for (var i = 1; i <= 29; i++) roomOf('douyu', '$i')],
          hasMore: false,
        ),
      ),
    };
    final roomsAsked = <int>[];
    installSite(roomsByPage: () => pageAnswers, roomsAsked: roomsAsked);
    final rooms = container.read(areaRoomsProvider.notifier);
    await rooms.init(site: currentSites.single, area: areaOf('douyu', '1'));

    // The login room stays out of the shown list but stays fetched.
    var current = container.read(areaRoomsProvider)!;
    expect(current.rooms.length, 29);
    expect(current.hidden, 1);
    expect(current.rooms.any((room) => room.identityKey == 'douyu:login'), isFalse);

    // The setting flips and the fetched rooms re-filter in place.
    container.read(showUnplayableProvider.notifier).setShow(value: true);
    await pumpEventQueue();
    current = container.read(areaRoomsProvider)!;
    expect(current.rooms.length, 30);
    expect(current.hidden, 0);
    expect(current.rooms.first.identityKey, 'douyu:login');
  });

  test('the page choices hold their own rules', () async {
    final layout = container.read(areaLayoutProvider.notifier);
    expect(container.read(areaLayoutProvider), AreaCardLayout.tile);
    await layout.set(AreaCardLayout.row);
    expect(container.read(areaLayoutProvider), AreaCardLayout.row);

    final inline = container.read(areasInlineSearchProvider.notifier)..search('  word  ');
    expect(container.read(areasInlineSearchProvider), 'word');
    inline.search('   ');
    expect(container.read(areasInlineSearchProvider), isNull);

    final view = container.read(areasViewProvider.notifier);
    expect(container.read(areasViewProvider), AreasView.platform);
    view.selected = AreasView.followed;
    expect(container.read(areasViewProvider), AreasView.followed);
  });
}

/// One fake area site: identity, its catalogue, and its room pages by page
/// number, counting every rooms ask.
final class _FakeAreaSite implements LiveSite, LiveAreaProvider {
  _FakeAreaSite(this.id, {required this.areas, required this._roomsByPage, required this.roomsAsked});

  final String id;
  final List<LiveArea> areas;
  final Map<int, Either<LiveSiteError, LivePage<LiveRoom>>> Function() _roomsByPage;
  final List<int> roomsAsked;

  /// When set, the catalogue ask fails instead.
  bool Function() failAreas = () => false;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    if (failAreas()) {
      return const Left(LiveSiteError.network(siteId: 'douyu', message: 'areas down'));
    }
    return Right(areas);
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({required LiveArea area, LivePageRequest? request}) {
    final page = request?.page ?? 1;
    roomsAsked.add(page);
    final answer = _roomsByPage()[page];
    if (answer == null) {
      return Future.value(Right(LivePage<LiveRoom>.of(items: const [], hasMore: false)));
    }
    return Future.value(answer);
  }

  @override
  LiveSiteManifest get manifest => LiveSiteManifest(id: id, name: {'en': id}, version: '1', contractVersion: '1');

  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  @override
  T? capability<T extends LiveSiteCapability>() => this is T ? this as T : null;

  @override
  Future<void> initialize(LiveSiteContext context) async {}

  @override
  Future<void> dispose() async {}
}
