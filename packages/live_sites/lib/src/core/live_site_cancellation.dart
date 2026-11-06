/// The cancellation contract over a site's fetch surfaces.
///
/// Dart futures cannot be interrupted, so cancellation is cooperative and two
/// things at once, matching what the transport underneath can do:
///
/// - A token that reaches the transport interrupts for real. The sites'
///   transports speak live_net's `CancelToken` (`LiveRequest.cancelToken`,
///   bridged to the pooled dio clients), so a capability that takes the token
///   hands it to its requests and an abort surfaces as `CancelledFailure`.
///   Whether a site's capability does this is declared by the refinable
///   capability interfaces (`LiveCancellableDiscovery`, `LiveCancellableSearch`,
///   `LiveCancellableArea`); a site adopts them when its request chain threads
///   the token through.
///
/// - Where no token reached the transport, the entry points below still honour
///   the token at the boundary: a call is refused when the token is already
///   set, and its answer is dropped when the token is set by the time the
///   answer arrives (a dropped answer is reported as `LiveSiteCancelled`,
///   never passed on). The work in the background finishes on its own — that
///   is stated, not pretended away.
///
/// A cancelled call is a caller decision, so it is never a transient failure
/// and never an error to surface; the app decides what an abandoned screen
/// means. App-side call sites adopt this when their screens grow lifetimes;
/// the package's own guarantee ends at the boundary described here.
library;

import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/capabilities/live_search_provider.dart';
import 'package:live_sites/src/core/live_site.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/search/live_search_request/live_search_request.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';

/// A site's fetch surfaces with a caller's [CancelToken] honoured.
///
/// A null answer means the site has no such capability — the same contract as
/// `capability<T>()` (never a `LiveSiteUnsupported` left), so a caller keeps
/// its existing "absent capability" handling and only gains the token. The
/// token is forwarded where the site's capability declares it (real transport
/// interruption) and checked before and after the call everywhere else.
///
/// The members are named `fetch…` because several sites carry their own
/// `search`-shaped members, and an instance member would shadow an extension
/// of the same name.
extension LiveCancellableFetches on LiveSite {
  /// The site's discovery feed, or null when it has none.
  Future<Either<LiveSiteError, LivePage<LiveRoom>>>? fetchRecommended({LivePageRequest? request, CancelToken? cancel}) {
    final discovery = capability<LiveDiscoveryProvider>();
    if (discovery == null) return null;
    return _guarded(
      manifest.id,
      cancel,
      () => switch (discovery) {
        final LiveCancellableDiscovery cancellable => cancellable.getRecommendedRooms(request: request, cancel: cancel),
        _ => discovery.getRecommendedRooms(request: request),
      },
    );
  }

  /// The site's API search, or null when it has none.
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>>? fetchSearch(LiveSearchRequest request, {CancelToken? cancel}) {
    final provider = capability<LiveSearchProvider>();
    if (provider == null) return null;
    return _guarded(
      manifest.id,
      cancel,
      () => switch (provider) {
        final LiveCancellableSearch cancellable => cancellable.search(request, cancel: cancel),
        _ => provider.search(request),
      },
    );
  }

  /// A page of the site's rooms under [area], or null when it has no area
  /// listing.
  Future<Either<LiveSiteError, LivePage<LiveRoom>>>? fetchAreaRooms({
    required LiveArea area,
    LivePageRequest? request,
    CancelToken? cancel,
  }) {
    final provider = capability<LiveAreaProvider>();
    if (provider == null) return null;
    return _guarded(
      manifest.id,
      cancel,
      () => switch (provider) {
        final LiveCancellableArea cancellable => cancellable.getAreaRooms(area: area, request: request, cancel: cancel),
        _ => provider.getAreaRooms(area: area, request: request),
      },
    );
  }
}

/// One caller surface's fetch lifetime: every call made through it shares one
/// token, and [dispose] ends them all.
///
/// A screen (a search pane, the discovery feed, an area listing) creates a
/// scope, hands every fetch it starts to it, and disposes it when the screen
/// goes away: in-flight calls are interrupted where the site's capability
/// threads the token, dropped at the boundary everywhere else, and calls made
/// after [dispose] are refused without work. [dispose] resolves only once
/// every call the scope started has settled, so a screen that must not leave
/// work behind awaits it.
///
/// The scope holds no per-call tokens: one surface, one decision. A call a
/// screen wants to abandon on its own (search as the viewer types) takes its
/// own token through the [LiveCancellableFetches] entry points and composes
/// with the scope by the caller — a scope is not re-usable after [dispose].
final class LiveFetchScope {
  final CancelToken _token = CancelToken();
  final Set<Future<void>> _pending = {};
  Future<void>? _closing;

  /// Whether [dispose] has been called.
  bool get isCancelled => _token.isCancelled;

  /// [LiveCancellableFetches.fetchRecommended] within this scope.
  Future<Either<LiveSiteError, LivePage<LiveRoom>>>? recommended(LiveSite site, {LivePageRequest? request}) {
    final call = site.fetchRecommended(request: request, cancel: _token);
    if (call == null) return null;
    return _track(call);
  }

  /// [LiveCancellableFetches.fetchSearch] within this scope.
  Future<Either<LiveSiteError, LivePage<LiveSearchResult>>>? search(LiveSite site, LiveSearchRequest request) {
    final call = site.fetchSearch(request, cancel: _token);
    if (call == null) return null;
    return _track(call);
  }

  /// [LiveCancellableFetches.fetchAreaRooms] within this scope.
  Future<Either<LiveSiteError, LivePage<LiveRoom>>>? areaRooms(
    LiveSite site, {
    required LiveArea area,
    LivePageRequest? request,
  }) {
    final call = site.fetchAreaRooms(area: area, request: request, cancel: _token);
    if (call == null) return null;
    return _track(call);
  }

  /// Runs [call] within this scope, for a capability without a token
  /// parameter: refused once the scope is disposed, its answer dropped when
  /// it comes back after that, and a transport cancellation reported as
  /// [LiveSiteCancelled].
  Future<Either<LiveSiteError, T>> run<T>(LiveSite site, Future<Either<LiveSiteError, T>> Function() call) =>
      _track(_guarded(site.manifest.id, _token, call));

  /// Cancels every call the scope has started and waits until they have
  /// settled. Calls made afterwards are refused; the scope is not reusable.
  Future<void> dispose() {
    _token.cancel();
    return _closing ??= Future.wait(_pending.toList()).then((_) {});
  }

  /// Keeps [call] in the pending set until it settles, so [dispose] waits
  /// for it.
  Future<T> _track<T>(Future<T> call) {
    final settled = Completer<void>();
    _pending.add(settled.future);
    return call.whenComplete(() {
      _pending.remove(settled.future);
      settled.complete();
    });
  }
}

/// Calls [work], honouring [cancel] at the boundary: refused before it
/// starts, its answer dropped when [cancel] is set by the time the answer
/// arrives, and a transport cancellation mapped onto [LiveSiteCancelled].
Future<Either<LiveSiteError, T>> _guarded<T>(
  String siteId,
  CancelToken? cancel,
  Future<Either<LiveSiteError, T>> Function() work,
) async {
  if (cancel?.isCancelled ?? false) return left(LiveSiteError.cancelled(siteId: siteId));
  final Either<LiveSiteError, T> result;
  try {
    result = await work();
  } on CancelledFailure catch (failure) {
    return left(LiveSiteError.cancelled(siteId: siteId, cause: failure));
  }
  if (cancel?.isCancelled ?? false) return left(LiveSiteError.cancelled(siteId: siteId));
  return result;
}
