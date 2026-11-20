import 'dart:async' show Completer, TimeoutException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, Left, Right;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/browse/sites_providers.dart' show sitesProvider;
import 'package:pure_live/modules/live/toolbox/toolbox_controllers.dart';

/// The node test over fake page sites: which platforms it offers, what one
/// probe records, the endpoint it prefers, and the sweep that seeds every
/// tile and lands each answer.
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

  PlatformProbeState probeState() => container.read(platformProbeProvider);
  PlatformProbeController probe() => container.read(platformProbeProvider.notifier);

  LivePage<LiveRoom> pageOf(int count) => LivePage<LiveRoom>.of(
    items: [
      for (var i = 0; i < count; i++)
        LiveRoom.normalized(
          platform: 'a',
          roomId: '$i',
          content: RoomContent.of(title: 'r$i'),
        ),
    ],
  );

  test('the wall offers discovery and hot platforms in order, only those', () {
    installSites([
      _FakePageSite('disc', discoveryPage: pageOf(1), hotPage: pageOf(2)),
      _FakePageSite('bare', noCapabilities: true),
      _FakePageSite('hot', hotPage: pageOf(3)),
      _FakePageSite('disc2', discoveryPage: pageOf(1)),
    ]);
    expect(probeSites(currentSites).map((site) => site.manifest.id), ['disc', 'hot', 'disc2']);
  });

  test('one probe records the endpoint answer with its count', () async {
    final asked = <String>[];
    installSites([_FakePageSite('disc', discoveryPage: pageOf(12), askedEndpoints: asked)]);

    await probe().probe('disc');
    final node = probeState().nodes['disc']!;
    expect(node.probing, isFalse);
    final outcome = probeState().nodes['disc']!.outcome!;
    expect(outcome, isA<ProbeSuccess>());
    expect((outcome as ProbeSuccess).rooms, 12);
    expect(asked, ['discovery']);
  });

  test('the discovery feed leads when a platform offers both', () async {
    final asked = <String>[];
    installSites([_FakePageSite('both', discoveryPage: pageOf(1), hotPage: pageOf(30), askedEndpoints: asked)]);

    await probe().probe('both');
    expect(asked, ['discovery']);
    expect((probeState().nodes['both']!.outcome! as ProbeSuccess).rooms, 1);
  });

  test('a hot-only platform probes its hot list', () async {
    final asked = <String>[];
    installSites([_FakePageSite('hot', hotPage: pageOf(30), askedEndpoints: asked)]);

    await probe().probe('hot');
    expect(asked, ['hot']);
    expect((probeState().nodes['hot']!.outcome! as ProbeSuccess).rooms, 30);
  });

  test('a failure keeps the site words, a crash and a stall read as network', () async {
    installSites([
      _FakePageSite(
        'down',
        discoveryPage: pageOf(0),
        errorIn: const LiveSiteNetworkError(siteId: 'down', message: 'socket closed'),
      ),
    ]);
    await probe().probe('down');
    final failed = probeState().nodes['down']!.outcome! as ProbeFailure;
    expect(failed.error.message, 'socket closed');

    // A crash inside the adapter is a synthesized network answer, not a
    // broken wall.
    installSites([_FakePageSite('boom', discoveryPage: pageOf(0), throwIn: StateError('broken'))]);
    await probe().probe('boom');
    expect((probeState().nodes['boom']!.outcome! as ProbeFailure).error.message, contains('broken'));

    // The timeout path reads the same way.
    installSites([
      _FakePageSite('stuck', discoveryPage: pageOf(0), throwIn: TimeoutException('t', const Duration(seconds: 15))),
    ]);
    await probe().probe('stuck');
    expect((probeState().nodes['stuck']!.outcome! as ProbeFailure).error.message, 'probe timed out');

    // A platform that lost its page capabilities answers unsupported.
    installSites([_FakePageSite('bare', noCapabilities: true)]);
    await probe().probe('bare');
    expect((probeState().nodes['bare']!.outcome! as ProbeFailure).error, isA<LiveSiteUnsupported>());
  });

  test('a probe already running for a platform is left alone', () async {
    final asks = <int>[];
    final site = _FakePageSite('disc', discoveryPage: pageOf(1), discoveryAsks: asks)
      ..holdDiscovery = Completer<void>();
    installSites([site]);

    final running = probe().probe('disc');
    expect(probeState().nodes['disc']!.probing, isTrue);

    // The second press answers nothing and starts nothing new.
    await probe().probe('disc');
    expect(asks, hasLength(1));

    site.holdDiscovery!.complete();
    await running;
    expect(probeState().nodes['disc']!.probing, isFalse);
  });

  test('the sweep seeds every tile, lands each answer, and ends the run', () async {
    final asked = <String>[];
    installSites([
      _FakePageSite('a', discoveryPage: pageOf(3), askedEndpoints: asked),
      _FakePageSite('b', hotPage: pageOf(4), askedEndpoints: asked),
      _FakePageSite('bare', noCapabilities: true),
    ]);

    await probe().probeAll();
    final state = probeState();
    expect(state.running, isFalse);
    expect(state.nodes.keys, ['a', 'b']); // the capability-less one is not a tile
    expect(state.nodes['a']!.outcome, isA<ProbeSuccess>());
    expect(state.nodes['b']!.outcome, isA<ProbeSuccess>());
    expect(asked, ['discovery', 'hot']);
  });

  test('a sweep with nothing to probe answers nothing', () async {
    installSites([_FakePageSite('bare', noCapabilities: true)]);
    await probe().probeAll();
    expect(probeState().running, isFalse);
    expect(probeState().nodes, isEmpty);
  });

  test('a clear forgets every answer', () async {
    installSites([_FakePageSite('a', discoveryPage: pageOf(1))]);
    await probe().probe('a');
    expect(probeState().nodes, isNotEmpty);

    probe().clear();
    expect(probeState().nodes, isEmpty);
    expect(probeState().running, isFalse);
  });
}

/// One fake page site: identity, its two cheap pages, and which endpoint it
/// answered — counting both the asks and which kind they were.
final class _FakePageSite implements LiveSite, LiveDiscoveryProvider, LiveHotProvider {
  _FakePageSite(
    this.id, {
    this.discoveryPage,
    this.hotPage,
    this.askedEndpoints,
    this.discoveryAsks,
    this.errorIn,
    this.throwIn,
    this.noCapabilities = false,
  });

  final String id;
  final LivePage<LiveRoom>? discoveryPage;
  final LivePage<LiveRoom>? hotPage;

  /// 'discovery' / 'hot' per ask, when the test wants the kinds.
  final List<String>? askedEndpoints;

  /// The discovery page's asks, when the test wants the count.
  final List<int>? discoveryAsks;
  final LiveSiteError? errorIn;
  final Object? throwIn;
  final bool noCapabilities;

  /// When set, the discovery call stalls until the test completes it; a
  /// later probe must not start a second one.
  Completer<void>? holdDiscovery;
  Completer<void> releaseDiscovery = Completer<void>()..complete();

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request}) async {
    discoveryAsks?.add(request?.page ?? 1);
    askedEndpoints?.add('discovery');
    if (throwIn != null) {
      // The staged trouble may be any object the walk must not strand on.
      // ignore: only_throw_errors
      throw throwIn!;
    }
    await (holdDiscovery ?? releaseDiscovery).future;
    if (errorIn != null) return Left(errorIn!);
    return Right(discoveryPage ?? LivePage<LiveRoom>.of(items: const []));
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getHotRooms({LivePageRequest? request}) async {
    askedEndpoints?.add('hot');
    if (throwIn != null) {
      // The staged trouble may be any object the walk must not strand on.
      // ignore: only_throw_errors
      throw throwIn!;
    }
    if (errorIn != null) return Left(errorIn!);
    return Right(hotPage ?? LivePage<LiveRoom>.of(items: const []));
  }

  @override
  LiveSiteManifest get manifest => LiveSiteManifest(id: id, name: {'en': id}, version: '1', contractVersion: '1');

  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  @override
  T? capability<T extends LiveSiteCapability>() {
    if (noCapabilities) return null;
    // A class implementing both interfaces would read every site as
    // discovery-capable; the page each site carries decides its endpoint.
    if (T == LiveDiscoveryProvider && discoveryPage == null) return null;
    if (T == LiveHotProvider && hotPage == null) return null;
    return this is T ? this as T : null;
  }

  @override
  Future<void> initialize(LiveSiteContext context) async {}

  @override
  Future<void> dispose() async {}
}
