import 'dart:async' show Completer, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/browse/sites_providers.dart' show sitesProvider;
import 'package:pure_live/modules/live/search/search_controller.dart';

/// The search controller over fake sites: paging and its dedup, the newer
/// search winning over a slow older one, the all-scope aggregation with a
/// failed platform named, anchor rooms learned, suggestions, and the query
/// history's own rules.
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

  LivePage<LiveSearchResult> pageOf(List<LiveRoom> rooms, {bool hasMore = false}) =>
      LivePage<LiveSearchResult>.of(items: [for (final room in rooms) RoomSearchResult(room)], hasMore: hasMore);

  SearchState stateNow() => container.read(searchProvider);

  /// Installs the fake registry: a search site per id answering [answerFor],
  /// each carrying completions from [suggestionsFor] when given.
  void installSites({
    required Map<String, Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> Function(LiveSearchRequest request)>
    answerFor,
    Set<LiveSearchTarget> targets = const {LiveSearchTarget.rooms, LiveSearchTarget.anchors},
    Map<String, List<String>> suggestionsFor = const {},
  }) {
    currentSites = [
      for (final entry in answerFor.entries)
        _FakeSearchSite(
          entry.key,
          targets: targets,
          answer: entry.value,
          suggestions: suggestionsFor[entry.key] ?? const [],
        ),
    ];
    container.invalidate(sitesProvider);
  }

  test('a search pages, dedups the overlap, and ends where the site ends', () async {
    final asked = <int>[];
    installSites(
      answerFor: {
        'douyu': (request) async {
          asked.add(request.page);
          return switch (request.page) {
            1 => Right(pageOf([roomOf('douyu', '1'), roomOf('douyu', '2')], hasMore: true)),
            _ => Right(pageOf([roomOf('douyu', '2'), roomOf('douyu', '3')])),
          };
        },
      },
    );
    container.read(searchSiteIdProvider.notifier).selected = 'douyu';
    await container.read(searchProvider.notifier).search('word');

    expect(stateNow().query, 'word');
    expect([for (final room in stateNow().rooms) room.identityKey], ['douyu:1', 'douyu:2']);
    expect(stateNow().nextPage, 2);
    expect(stateNow().hasMore, isTrue);
    expect(stateNow().error, isNull);

    await container.read(searchProvider.notifier).loadMore();
    // The repeated hit dropped, the new one appended.
    expect([for (final room in stateNow().rooms) room.identityKey], ['douyu:1', 'douyu:2', 'douyu:3']);
    expect(stateNow().hasMore, isFalse);
    // Another loadMore on an ended walk asks nothing.
    await container.read(searchProvider.notifier).loadMore();
    expect(asked, [1, 2]);
  });

  test('a newer search wins over a slower older one', () async {
    final alphaGate = Completer<Either<LiveSiteError, LivePage<LiveSearchResult>>>();
    installSites(
      answerFor: {
        'douyu': (request) {
          if (request.query == 'alpha') return alphaGate.future;
          return Future.value(Right(pageOf([roomOf('douyu', '9')])));
        },
      },
    );
    container.read(searchSiteIdProvider.notifier).selected = 'douyu';
    final notifier = container.read(searchProvider.notifier);

    unawaited(notifier.search('alpha'));
    await container.read(searchProvider.notifier).search('beta');
    expect(stateNow().query, 'beta');
    expect([for (final room in stateNow().rooms) room.identityKey], ['douyu:9']);

    // The slow answer drains without writing: it belongs to a search the
    // viewer replaced.
    alphaGate.complete(Right(pageOf([roomOf('douyu', '1'), roomOf('douyu', '2')])));
    await pumpEventQueue();
    expect(stateNow().query, 'beta');
    expect([for (final room in stateNow().rooms) room.identityKey], ['douyu:9']);
  });

  test('a blank search clears the results', () async {
    installSites(
      answerFor: {
        'douyu': (request) async => Right(pageOf([roomOf('douyu', '1')])),
      },
    );
    container.read(searchSiteIdProvider.notifier).selected = 'douyu';
    final notifier = container.read(searchProvider.notifier);
    await notifier.search('word');
    expect(stateNow().rooms, isNotEmpty);

    await notifier.search('   ');
    expect(stateNow().query, '');
    expect(stateNow().rooms, isEmpty);
    expect(stateNow().loading, isFalse);
  });

  test('an anchor hit learns the room it names', () async {
    installSites(
      answerFor: {
        'douyu': (request) async => Right(
          LivePage<LiveSearchResult>.of(
            items: [
              AnchorSearchResult(
                LiveAnchor.of(platform: 'douyu', anchorId: '7', name: 'Streamer'),
                roomId: '9',
              ),
            ],
            hasMore: false,
          ),
        ),
      },
    );
    container.read(searchSiteIdProvider.notifier).selected = 'douyu';
    final notifier = container.read(searchProvider.notifier);
    await notifier.switchTarget(LiveSearchTarget.anchors);
    expect(stateNow().target, LiveSearchTarget.anchors);

    await notifier.search('stream');
    await pumpEventQueue();
    expect(stateNow().anchors.single.name, 'Streamer');
    expect(container.read(anchorRoomsProvider)['douyu:7'], '9');
  });

  test('the all-scope merges every platform and names the one that failed', () async {
    installSites(
      answerFor: {
        'douyu': (request) async => Right(pageOf([roomOf('douyu', '1'), roomOf('huya', '2')])),
        'huya': (request) async => const Left(LiveSiteError.network(siteId: 'huya', message: 'no proxy')),
      },
    );
    container.read(searchSiteIdProvider.notifier).selected = kSearchAllPlatforms;
    await container.read(searchProvider.notifier).search('word');

    // Both hits merged in registry order, the duplicate dropped, the failed
    // platform named instead of hidden.
    expect([for (final room in stateNow().rooms) room.identityKey], ['douyu:1', 'huya:2']);
    expect(container.read(searchFailuresProvider), {'huya'});
    expect(stateNow().error, isNull);
    expect(stateNow().hasMore, isFalse);
  });

  test('the all-scope walk ends when every platform repeats itself', () async {
    installSites(
      answerFor: {
        'douyu': (request) async => Right(pageOf([roomOf('douyu', '1')], hasMore: true)),
        'huya': (request) async => Right(pageOf([roomOf('huya', '2')], hasMore: true)),
      },
    );
    container.read(searchSiteIdProvider.notifier).selected = kSearchAllPlatforms;
    final notifier = container.read(searchProvider.notifier);
    await notifier.search('word');
    expect(stateNow().hasMore, isTrue);

    await notifier.loadMore();
    expect(stateNow().hasMore, isTrue);
    await notifier.loadMore();
    // Two stagnant pages end the walk: the same answers keep coming and the
    // list stopped growing.
    expect(stateNow().hasMore, isFalse);
    expect([for (final room in stateNow().rooms) room.identityKey], ['douyu:1', 'huya:2']);
  });

  test('suggestions answer on a platform scope and stay empty on all', () async {
    installSites(
      answerFor: {'douyu': (request) async => Right(pageOf(const []))},
      suggestionsFor: {
        'douyu': ['word one', 'word two'],
      },
    );
    container.read(searchSiteIdProvider.notifier).selected = 'douyu';
    final notifier = container.read(searchProvider.notifier);

    await notifier.suggest('wor');
    expect(stateNow().suggestions, ['word one', 'word two']);

    container.read(searchSiteIdProvider.notifier).selected = kSearchAllPlatforms;
    await notifier.suggest('wor');
    expect(stateNow().suggestions, isEmpty);
  });

  test('the query history dedups case-blind, caps at twenty, drops on ask', () async {
    final notifier = container.read(searchHistoryProvider.notifier);
    await notifier.commit('game');
    await notifier.commit('GAME');
    // The equal word (case ignored) moved to the head, not duplicated.
    expect(container.read(searchHistoryProvider), ['GAME']);

    for (var i = 0; i < 25; i++) {
      await notifier.commit('word $i');
    }
    final kept = container.read(searchHistoryProvider);
    expect(kept.length, SearchHistoryController.limit);
    expect(kept.first, 'word 24');

    await notifier.remove('word 24');
    expect(container.read(searchHistoryProvider).first, 'word 23');
    await notifier.clear();
    expect(container.read(searchHistoryProvider), isEmpty);
  });
}

/// One fake search site: identity, the targets it declares, and the answers
/// its table hands back. Doubles as the suggest capability when completions
/// are given.
final class _FakeSearchSite implements LiveSite, LiveSearchProvider, LiveSuggestCapability {
  _FakeSearchSite(this.id, {required this.targets, required this.answer, required this._suggestions});

  final String id;
  final Set<LiveSearchTarget> targets;
  final Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> Function(LiveSearchRequest request) answer;
  final List<String> _suggestions;

  @override
  Set<LiveSearchTarget> get supportedTargets => targets;

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) => answer(request);

  @override
  Future<List<String>> suggestions(String query) async => _suggestions;

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
