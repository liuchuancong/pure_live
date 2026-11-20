import 'dart:async' show Completer, TimeoutException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/browse/sites_providers.dart' show sitesProvider;
import 'package:pure_live/modules/live/toolbox/toolbox_controllers.dart';

/// The link tool over fake resolver sites: the empty and linkless refusals,
/// the first owner that wins, the failure kinds the walk sorts into, and the
/// newer resolve that silences the older one.
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

  void installSites(List<LiveSite> sites) {
    currentSites = sites;
    container.invalidate(sitesProvider);
  }

  LinkToolState state() => container.read(linkToolProvider);
  LinkToolController tool() => container.read(linkToolProvider.notifier);

  test('an empty paste and a linkless paste refuse without a request', () async {
    final asks = <Uri>[];
    installSites([_FakeResolverSite('douyin', asks: asks)]);

    await tool().resolve('   ');
    expect(state().resolving, isFalse);
    expect(state().failure, LinkToolFailure.empty);
    expect(state().resolved, isNull);
    expect(asks, isEmpty);

    await tool().resolve('这里没有链接，只有一句话');
    expect(state().failure, LinkToolFailure.unsupported);
    expect(asks, isEmpty);
  });

  test('the owned link resolves to its room, trailing slash and all', () async {
    final asks = <Uri>[];
    installSites([
      _FakeResolverSite('douyin', asks: asks, answers: {'https://live.douyin.com/123': 'https://live.douyin.com/123'}),
    ]);

    await tool().resolve('来看 https://live.douyin.com/123');
    final room = state().resolved;
    expect(room, isNotNull);
    expect(room!.platform, 'douyin');
    expect(room.roomId, '123');
    expect(state().failure, isNull);
    expect(state().resolving, isFalse);
    expect(asks, hasLength(1));

    // A canonical answer ending in a slash names the same room.
    installSites([
      _FakeResolverSite('douyin', asks: asks, answers: {'https://live.douyin.com/9': 'https://live.douyin.com/9/'}),
    ]);
    await tool().resolve('https://live.douyin.com/9');
    expect(state().resolved!.roomId, '9');
  });

  test('a platform without the resolver is passed over without a call', () async {
    final asks = <Uri>[];
    installSites([
      _FakePlainSite('plain'),
      _FakeResolverSite('douyin', asks: asks, answers: {'https://live.douyin.com/5': 'https://live.douyin.com/5'}),
    ]);

    await tool().resolve('https://live.douyin.com/5');
    expect(state().resolved!.platform, 'douyin');
    expect(asks, hasLength(1));
  });

  test('the first owner wins, a refusal moves on, and nothing owns the link', () async {
    final aAsks = <Uri>[];
    final bAsks = <Uri>[];
    installSites([
      _FakeResolverSite('aaa', asks: aAsks, answers: {'https://live.douyin.com/1': 'https://live.douyin.com/1'}),
      _FakeResolverSite('bbb', asks: bAsks, answers: {'https://live.douyin.com/1': 'https://live.douyin.com/1'}),
    ]);
    await tool().resolve('https://live.douyin.com/1');
    expect(state().resolved!.platform, 'aaa');
    expect(bAsks, isEmpty); // the first room ends the walk

    // An owner that refuses the link lets the next one try.
    installSites([
      _FakeResolverSite('aaa', asks: aAsks, refuse: true),
      _FakeResolverSite('bbb', asks: bAsks, answers: {'https://live.douyin.com/1': 'https://live.douyin.com/1'}),
    ]);
    await tool().resolve('https://live.douyin.com/1');
    expect(state().resolved!.platform, 'bbb');

    // Nobody owns it: unsupported, and the failure is not transient.
    installSites([_FakeResolverSite('aaa', asks: aAsks, refuse: true)]);
    await tool().resolve('https://live.douyin.com/1');
    expect(state().failure, LinkToolFailure.unsupported);
    expect(state().failure!.isTransient, isFalse);
  });

  test('the trouble kinds sort into timeout, failed, and unsupported', () async {
    // A resolver that never answers inside the walk's patience reads as
    // timeout; here it throws the same exception the timer would.
    installSites([_FakeResolverSite('slow', asks: [], throwIn: TimeoutException('t', const Duration(seconds: 12)))]);
    await tool().resolve('https://live.douyin.com/1');
    expect(state().failure, LinkToolFailure.timeout);
    expect(state().failure!.isTransient, isTrue);

    // A crash inside a resolver is real trouble, not "nobody owns this".
    installSites([_FakeResolverSite('boom', asks: [], throwIn: StateError('broken'))]);
    await tool().resolve('https://live.douyin.com/1');
    expect(state().failure, LinkToolFailure.failed);
    expect(state().failure!.isTransient, isTrue);

    // A left that is not a refusal names the network.
    installSites([
      _FakeResolverSite(
        'down',
        asks: [],
        errorIn: const LiveSiteNetworkError(siteId: 'down', message: 'socket closed'),
      ),
    ]);
    await tool().resolve('https://live.douyin.com/1');
    expect(state().failure, LinkToolFailure.failed);
  });

  test('a newer resolve replaces an older one, even after the old one lands', () async {
    final gate = Completer<Uri>();
    final slow = _FakeResolverSite('slow', asks: [], gate: gate, answer: 'https://live.douyin.com/1');
    installSites([slow]);

    final first = tool().resolve('https://live.douyin.com/1');
    expect(state().resolving, isTrue);

    // The paste changed: the field's edit resets, then a fresh resolve runs
    // against a fast owner.
    tool().reset();
    expect(state().resolving, isFalse);
    expect(state().failure, isNull);

    installSites([
      _FakeResolverSite('fast', asks: [], answers: {'https://live.douyin.com/2': 'https://live.douyin.com/2'}),
    ]);
    await tool().resolve('再 https://live.douyin.com/2');
    expect(state().resolved!.roomId, '2');

    // The stalled answer lands now; it must not overwrite the newer room.
    gate.complete(Uri.parse('https://live.douyin.com/1'));
    await first;
    await pumpEventQueue();
    expect(state().resolved!.roomId, '2');
    expect(state().resolving, isFalse);
  });

  test('a resolver answering a roomless URL keeps the walk going', () async {
    final asks = <Uri>[];
    installSites([
      // The canonical answer names no room (an empty path) — not a room.
      _FakeResolverSite('odd', asks: asks, answers: {'https://live.douyin.com/1': 'https://live.douyin.com/'}),
      _FakeResolverSite('bbb', asks: asks, answers: {'https://live.douyin.com/1': 'https://live.douyin.com/7'}),
    ]);
    await tool().resolve('https://live.douyin.com/1');
    expect(state().resolved!.platform, 'bbb');
    expect(asks, hasLength(2));
  });
}

/// A fake resolver site: [answers] maps the asked link to the canonical room
/// URL; [refuse] answers the not-owner left; [errorIn] and [throwIn] stage
/// the trouble kinds; [gate] holds the answer until the test releases it.
final class _FakeResolverSite implements LiveSite, LiveLinkResolver {
  _FakeResolverSite(
    this.id, {
    required this.asks,
    this.answers = const {},
    this.refuse = false,
    this.errorIn,
    this.throwIn,
    this.gate,
    this.answer,
  });

  final String id;
  final List<Uri> asks;
  final Map<String, String> answers;
  final bool refuse;
  final LiveSiteError? errorIn;
  final Object? throwIn;
  final Completer<Uri>? gate;
  final String? answer;

  @override
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri) {
    asks.add(uri);
    if (throwIn != null) {
      // The staged trouble may be any object the walk must not strand on.
      // ignore: only_throw_errors
      throw throwIn!;
    }
    if (gate != null) return gate!.future.then(Right<LiveSiteError, Uri>.new);
    if (errorIn != null) return Future.value(Left(errorIn!));
    if (refuse) {
      return Future.value(Left(LiveSiteUnsupported(siteId: id, message: 'not mine')));
    }
    final canonical = answers[uri.toString()] ?? answer;
    if (canonical == null) {
      return Future.value(Left(LiveSiteUnsupported(siteId: id, message: 'not mine')));
    }
    return Future.value(Right(Uri.parse(canonical)));
  }

  @override
  LiveSiteManifest get manifest => LiveSiteManifest(id: id, name: {'en': id}, version: '1', contractVersion: '1');

  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  @override
  T? capability<T extends LiveSiteCapability>() => (this is T ? this as T : null);

  @override
  Future<void> initialize(LiveSiteContext context) async {}

  @override
  Future<void> dispose() async {}
}

/// A site with no capabilities at all.
final class _FakePlainSite implements LiveSite {
  _FakePlainSite(this.id);

  final String id;

  @override
  LiveSiteManifest get manifest => LiveSiteManifest(id: id, name: {'en': id}, version: '1', contractVersion: '1');

  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  @override
  T? capability<T extends LiveSiteCapability>() => null;

  @override
  Future<void> initialize(LiveSiteContext context) async {}

  @override
  Future<void> dispose() async {}
}
