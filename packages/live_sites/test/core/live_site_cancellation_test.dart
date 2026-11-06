// The cancellation contract at the boundary: the entry points refuse a
// cancelled call, drop an answer the caller stopped waiting for, and hand the
// token to the capabilities that declared it; the scope ends every call it
// started and waits for them to settle.
//
// The fakes stand in for the two sides of the contract: a capability that
// never sees the token (the base member) and one that does (the refinable
// twin), gated so a test can cancel while the call is in flight.
//
// Platform-internal code: constructor-name rules that govern the public
// surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

import 'dart:async';


import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site.dart';
import 'package:live_sites/src/core/live_site_cancellation.dart';
import 'package:live_sites/src/core/live_site_context.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/core/live_site_manifest.dart';
import 'package:live_sites/src/core/live_site_runtime_info.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_search_target.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:test/test.dart';

/// An empty page of rooms: what every stub answers.
LivePage<LiveRoom> _page() => LivePage.of(items: const <LiveRoom>[]);

/// A site whose capabilities are the stubs the test installed.
final class _FakeSite implements LiveSite {
  const _FakeSite(this._capabilities);

  static const _manifest = LiveSiteManifest(id: 'fake', name: {'en': 'Fake'}, version: '0', contractVersion: '0');

  final Map<Type, LiveSiteCapability> _capabilities;

  @override
  LiveSiteManifest get manifest => _manifest;

  @override
  LiveSiteRuntimeInfo get runtimeInfo => const LiveSiteRuntimeInfo(status: LiveSiteStatus.ready);

  @override
  T? capability<T extends LiveSiteCapability>() => _capabilities[T] as T?;

  @override
  Future<void> initialize(LiveSiteContext context) async {}

  @override
  Future<void> dispose() async {}
}

/// The base discovery member: fetchable, but no token ever reaches it.
final class _StubDiscovery implements LiveDiscoveryProvider {
  int calls = 0;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request}) async {
    calls++;
    return right(_page());
  }
}

/// A base discovery member whose one call waits for [release].
final class _GatedBaseDiscovery implements LiveDiscoveryProvider {
  _GatedBaseDiscovery(this.events, this.name);

  int calls = 0;
  final _release = Completer<void>();
  final List<String> events;
  final String name;

  void release() => _release.complete();

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request}) async {
    calls++;
    events.add('$name-started');
    await _release.future;
    events.add('$name-settled');
    return right(_page());
  }
}

/// The refinable twin: the token arrives, the answer is instant.
final class _StubCancellableDiscovery implements LiveCancellableDiscovery {
  int calls = 0;
  CancelToken? seen;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest? request,
    CancelToken? cancel,
  }) async {
    calls++;
    seen = cancel;
    return right(_page());
  }
}

/// The refinable twin whose call waits for [release], bridging its own wait
/// to the token like a transport does: cancelled means released.
final class _GatedCancellableDiscovery implements LiveCancellableDiscovery {
  int calls = 0;
  CancelToken? seen;
  final _release = Completer<void>();

  void release() => _release.complete();

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest? request,
    CancelToken? cancel,
  }) async {
    calls++;
    seen = cancel;
    unawaited(cancel?.whenCancel.then((_) => release()));
    await _release.future;
    return right(_page());
  }
}

/// The refinable twin whose transport gives up cancelled.
final class _AbortingDiscovery implements LiveCancellableDiscovery {
  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest? request,
    CancelToken? cancel,
  }) => throw const CancelledFailure();
}

/// The refinable search twin, for the scope's search surface.
final class _StubCancellableSearch implements LiveCancellableSearch {
  CancelToken? seen;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request, {CancelToken? cancel}) async {
    seen = cancel;
    return right(LivePage.of(items: const <LiveSearchResult>[]));
  }
}

/// A search provider without the twin: searchable, never interrupted.
final class _StubSearch implements LiveSearchProvider {
  int calls = 0;

  @override
  Set<LiveSearchTarget> get supportedTargets => const {LiveSearchTarget.rooms};

  @override
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>> search(LiveSearchRequest request) async {
    calls++;
    return right(LivePage.of(items: const <LiveSearchResult>[]));
  }
}

void main() {
  final request = LiveSearchRequest.of(query: 'ann', target: LiveSearchTarget.rooms);

  group('the cancellable entry points', () {
    test('a surface the site has no capability for answers null', () {
      const site = _FakeSite(<Type, LiveSiteCapability>{});
      expect(site.fetchRecommended(), isNull);
      expect(site.fetchSearch(request), isNull);
      expect(site.fetchAreaRooms(area: LiveArea.of(areaId: 'a')), isNull);
    });

    test('a twin still answers for the base capability it refines', () {
      final site = _FakeSite({LiveDiscoveryProvider: _StubCancellableDiscovery()});
      expect(site.capability<LiveDiscoveryProvider>(), isA<LiveCancellableDiscovery>());
    });

    test('a token reaches the capability that declared it, and its answer passes', () async {
      final twin = _StubCancellableDiscovery();
      final site = _FakeSite({LiveDiscoveryProvider: twin});
      final token = CancelToken();

      final answer = await site.fetchRecommended(cancel: token);
      expect(answer!.isRight(), isTrue);
      expect(identical(twin.seen, token), isTrue, reason: 'the very token rides on the call');
    });

    test('a token set before the call refuses it without work', () async {
      final twin = _StubCancellableDiscovery();
      final site = _FakeSite({LiveDiscoveryProvider: twin});
      final token = CancelToken()..cancel();

      final answer = await site.fetchRecommended(cancel: token);
      expect(answer!.getLeft().toNullable(), isA<LiveSiteCancelled>());
      expect(twin.calls, 0, reason: 'a refused call never reaches the capability');
    });

    test('an answer that arrives after the token was set is dropped', () async {
      final twin = _GatedCancellableDiscovery();
      final site = _FakeSite({LiveDiscoveryProvider: twin});
      final token = CancelToken();

      final answer = site.fetchRecommended(cancel: token);
      expect(twin.calls, 1, reason: 'the call is in flight, not refused');
      token.cancel();
      expect((await answer)!.getLeft().toNullable(), isA<LiveSiteCancelled>(), reason: 'the result is never passed on');
    });

    test('a transport cancellation is reported as cancelled', () async {
      final site = _FakeSite({LiveDiscoveryProvider: _AbortingDiscovery()});

      final answer = await site.fetchRecommended(cancel: CancelToken());
      final error = answer!.getLeft().toNullable();
      expect(error, isA<LiveSiteCancelled>());
      expect(error!.cause, isA<CancelledFailure>());
    });

    test('a capability without the twin is checked before and after only', () async {
      final base = _StubDiscovery();
      final site = _FakeSite({LiveDiscoveryProvider: base});
      final token = CancelToken();

      expect((await site.fetchRecommended(cancel: token))!.isRight(), isTrue);
      token.cancel();
      expect((await site.fetchRecommended(cancel: token))!.getLeft().toNullable(), isA<LiveSiteCancelled>());
      expect(base.calls, 1, reason: 'the cancelled second call is refused at the boundary');
    });

    test('the search entry dispatches to the twin that declared the token', () async {
      final twin = _StubCancellableSearch();
      final site = _FakeSite({LiveSearchProvider: twin});
      final token = CancelToken();

      expect((await site.fetchSearch(request, cancel: token))!.isRight(), isTrue);
      expect(identical(twin.seen, token), isTrue);
    });

    test('the search entry falls back to a capability without the twin', () async {
      final base = _StubSearch();
      final site = _FakeSite({LiveSearchProvider: base});

      expect((await site.fetchSearch(request))!.isRight(), isTrue);
      expect(base.calls, 1);
    });
  });

  group('the fetch scope', () {
    test('every call rides on the scope token and dispose ends them', () async {
      final twin = _GatedCancellableDiscovery();
      final site = _FakeSite({LiveDiscoveryProvider: twin});
      final scope = LiveFetchScope();

      final answer = scope.recommended(site);
      expect(twin.seen, isNotNull, reason: 'the call went out under the scope token');
      expect(scope.isCancelled, isFalse);

      final closing = scope.dispose();
      expect(scope.isCancelled, isTrue);
      expect(twin.seen!.isCancelled, isTrue, reason: 'the scope token cancelled the call the scope started');
      await closing;
      expect((await answer)!.getLeft().toNullable(), isA<LiveSiteCancelled>(), reason: 'a cancelled result is not passed on');
    });

    test('calls after dispose are refused without work', () async {
      final twin = _StubCancellableDiscovery();
      final site = _FakeSite({LiveDiscoveryProvider: twin});
      final scope = LiveFetchScope();
      await scope.dispose();

      expect((await scope.recommended(site))!.getLeft().toNullable(), isA<LiveSiteCancelled>());
      expect(twin.calls, 0, reason: 'a disposed scope starts nothing');
    });

    test('a scope with no capability answers null and disposes idle', () async {
      const site = _FakeSite(<Type, LiveSiteCapability>{});
      final scope = LiveFetchScope();

      expect(scope.recommended(site), isNull);
      await scope.dispose();
      expect(scope.isCancelled, isTrue);
    });

    test('dispose waits for a capability it cannot interrupt', () async {
      final events = <String>[];
      final base = _GatedBaseDiscovery(events, 'call');
      final site = _FakeSite({LiveDiscoveryProvider: base});
      final scope = LiveFetchScope();

      final answer = scope.recommended(site);
      final closing = scope.dispose();
      expect(events, ['call-started'], reason: 'the scope gave up but the capability knows no token');

      base.release();
      await closing;
      expect(events, ['call-started', 'call-settled'], reason: 'dispose returns only after the call settled');
      expect((await answer)!.getLeft().toNullable(), isA<LiveSiteCancelled>(), reason: 'the late answer is dropped');
    });

    test('run applies the scope to a capability without a token', () async {
      const site = _FakeSite(<Type, LiveSiteCapability>{});
      final scope = LiveFetchScope();
      var calls = 0;

      final answer = await scope.run(site, () async {
        calls++;
        return right<LiveSiteError, String>('answer');
      });
      expect(answer.getRight().toNullable(), 'answer');
      expect(calls, 1);

      await scope.dispose();
      final late = await scope.run(site, () async {
        calls++;
        return right<LiveSiteError, String>('late');
      });
      expect(late.getLeft().toNullable(), isA<LiveSiteCancelled>());
      expect(calls, 1, reason: 'a disposed scope runs nothing');
    });

    test('the search surface goes through the scope like the discovery one', () async {
      final twin = _StubCancellableSearch();
      final site = _FakeSite({LiveSearchProvider: twin});
      final scope = LiveFetchScope();

      final answer = await scope.search(site, request);
      expect(answer!.isRight(), isTrue);
      await scope.dispose();
      expect(twin.seen!.isCancelled, isTrue);
    });
  });
}
