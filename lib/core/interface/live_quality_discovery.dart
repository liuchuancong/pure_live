import 'dart:async';

import 'package:dio/dio.dart';
import 'package:pure_live/core/models/live_room.dart';
import 'package:pure_live/core/models/live_play_quality.dart';

import 'live_site.dart';

/// Optional discovery ownership. Implementations forward cancellation to their
/// transport and settle only after temporary sessions/credentials are released.
/// Cancelling a caller must never close a shared client or another discovery.
abstract interface class LiveQualityDiscovery {
  Future<List<LivePlayQuality>> discoverPlayQualitiesRaw({required LiveRoom liveroom, CancelToken? cancel});
}

extension LiveSiteQualityDiscovery on LiveSite {
  Future<List<LivePlayQuality>> discoverPlayQualities({required LiveRoom liveroom, CancelToken? cancel}) async {
    if (cancel?.isCancelled == true) throw cancel!.cancelError!;
    final site = this;
    final result = site is LiveQualityDiscovery
        ? await (site as LiveQualityDiscovery).discoverPlayQualitiesRaw(liveroom: liveroom, cancel: cancel)
        : await getPlayQualites(liveroom: liveroom);
    // A legacy adapter still has its own transport lifetime, but its cancelled
    // result must not become the next stage of a new playback operation.
    if (cancel?.isCancelled == true) throw cancel!.cancelError!;
    return result;
  }
}

/// One consumer's discovery lifetime, independent from metadata/URL requests
/// and native player ownership. Closing joins only capability-owned cleanup.
class LiveQualityDiscoveryScope {
  final cancelToken = CancelToken();
  final Set<Future<void>> _pending = {};
  Future<void>? _closing;

  void checkActive() {
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
  }

  Future<List<LivePlayQuality>> discover(LiveSite site, LiveRoom liveroom) async {
    checkActive();
    final cleanup = Completer<void>();
    if (site is LiveQualityDiscovery) _pending.add(cleanup.future);
    try {
      return await site.discoverPlayQualities(liveroom: liveroom, cancel: cancelToken);
    } finally {
      _pending.remove(cleanup.future);
      cleanup.complete();
    }
  }

  void cancel() {
    if (!cancelToken.isCancelled) cancelToken.cancel();
  }

  Future<void> close() {
    cancel();
    return _closing ??= Future.wait(_pending.toList()).then((_) {});
  }
}
