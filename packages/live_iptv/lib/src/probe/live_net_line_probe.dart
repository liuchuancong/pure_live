/// The live_net media probe, shaped as an [IptvLineProbe].
///
/// This is the one file in the package that knows a transport exists. The
/// prober itself stays a contract — [IptvLineProbe] — because deciding what a
/// verdict *means* (rank it, quarantine it, retry it tomorrow) has nothing to
/// do with how the bytes were fetched, and a package that conflates the two
/// cannot be tested without a network.
///
/// The application wires it in one line, at its composition root, where the
/// shared HTTP client, the proxy rules and the user agent already live:
///
/// ```dart
/// final prober = IptvLineProber(
///   probe: iptvLineProbeFrom(MediaProbe(http: httpClient)),
/// );
/// ```
///
/// The two timeouts have to agree: [MediaProbe] bounds the fetch and
/// [IptvLineProber] bounds the wait, and if the prober's clock is the shorter
/// one, a slow-but-live address is recorded as a failure while the fetch is
/// still running. Give the prober at least as long as the probe.
library;

import 'package:live_iptv/src/probe/iptv_line_prober.dart';
import 'package:live_net/live_net.dart' show MediaProbe, MediaProbeResult;

/// An [IptvLineProbe] that asks [probe] about each address.
///
/// The mapping is deliberately literal: a probe that abstained because the
/// address is `rtmp://` stays [IptvProbeOutcome.inconclusive] rather than
/// becoming a failure, because burying a mirror for the probe's own blind spot
/// would take the channel's only working line out of the rotation.
IptvLineProbe iptvLineProbeFrom(MediaProbe probe) =>
    (url, headers) async => iptvOutcomeOf(await probe.check(url, headers: headers));

/// [result] as the verdict the IPTV prober understands.
IptvProbeOutcome iptvOutcomeOf(MediaProbeResult result) {
  if (result.inconclusive) {
    return IptvProbeOutcome.inconclusive(result.message ?? 'the probe cannot open this address');
  }
  if (result.playable) {
    return IptvProbeOutcome.answered(result.latency, bytes: result.bytes, message: result.container.name);
  }
  return IptvProbeOutcome.down(result.message ?? 'answered no media');
}
