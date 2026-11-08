import 'package:live_net/live_net.dart' show HttpProxyRoute, ProxyRoute;
import 'package:live_sites/live_sites.dart';
import 'package:media_core_ingest/media_core_ingest.dart';

import 'package:pure_live/app/providers/network/network_providers.dart' show appProxyRouteProvider;

/// A started ingest relay for one line, and the local line the player opens.
final class LiveIngestSession {
  LiveIngestSession(this.relay);

  final LoopbackIngestRelay relay;

  Uri get inputUri => relay.inputUri;

  Future<void> close() => relay.close();
}

/// Starts the ingest a site's runtime info asks for, or answers null when the
/// line can go to the player as it is.
///
/// [proxyRoute] re-reads the app's route per request, so a relay that outlives
/// a proxy change follows it; callers read [appProxyRouteProvider], which both
/// a provider's `Ref` and a widget's `WidgetRef` can do.
///
/// Bigo is the only platform declaring a need today: its web HLS hides the
/// head of every segment behind a seed-derived XOR, and `media_core_ingest`'s
/// loopback relay restores the bytes before the player reads them.
Future<LiveIngestSession?> startLiveIngest({
  required ProxyRoute Function() proxyRoute,
  required LiveSite site,
  required LivePlayLine line,
}) async {
  final recipe = site.runtimeInfo.ingest;
  if (recipe == null || !recipe.needs.contains(LiveSiteIngestNeed.segmentTransform)) return null;
  final seedOf = recipe.seedOf;
  final transform = recipe.transform;
  if (seedOf == null || transform == null) return null;
  if (!line.url.startsWith('http')) return null;
  int? seed;
  final relay = await LoopbackIngestRelay.start(
    source: Uri.parse(line.url),
    headers: line.headers.toMap(),
    findProxy: (url) {
      final route = proxyRoute();
      return route is HttpProxyRoute ? route.ioRoute : 'DIRECT';
    },
    onManifest: (manifest, body) {
      final found = seedOf(body);
      if (found != null) seed = found;
    },
    childTransform: (child, body) {
      final value = seed;
      return value == null ? body : transform(body, value);
    },
  );
  return LiveIngestSession(relay);
}

/// [line] with its address replaced by the relay's local playlist. The label,
/// format and lease stay the site's own.
LivePlayLine ingestedLine(LivePlayLine line, Uri inputUri) => LivePlayLine.of(
  url: inputUri.toString(),
  format: line.format,
  formatSource: line.formatSource,
  codec: line.codec,
  lineLabel: line.lineLabel,
  lease: line.lease,
  geometry: line.geometry,
  singleUse: line.singleUse,
);
