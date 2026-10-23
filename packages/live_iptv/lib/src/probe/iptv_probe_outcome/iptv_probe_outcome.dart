/// The probe seam: what one address was asked, and what came back.
///
/// Kept apart from the walk that uses it (`IptvLineProber`) and the ranking
/// that consumes its answers (`rankIptvLines`): this is the vocabulary, and
/// those are two different policies over it. A transport adapter only ever
/// needs this file.
library;

// ignore_for_file: unnecessary_type_name_in_constructor -- this SDK has no
// `new.named` shorthand: a named constructor must repeat its type name.

import 'package:meta/meta.dart';

/// Asks one address whether it is there, and how fast it answers.
///
/// The implementation must resolve [IptvProbeOutcome.answered] only when it
/// saw actual media bytes: an HTTP 200 with an empty body is a dead stream,
/// and calling it reachable would put it first in the ranking and make the
/// player stall on it. An address this transport cannot speak to at all —
/// an `rtmp://` or `udp://` line, which real IPTV lists are full of —
/// answers [IptvProbeOutcome.inconclusive] rather than
/// [IptvProbeOutcome.down]: not being able to ask is not evidence of death.
typedef IptvLineProbe = Future<IptvProbeOutcome> Function(String url, Map<String, String> headers);

/// What a probe of one address found.
@immutable
class IptvProbeOutcome {
  /// A verdict.
  const IptvProbeOutcome({required this.ok, this.inconclusive = false, this.latency, this.bytes, this.message});

  /// A verdict about an address that answered with media in [latency].
  const IptvProbeOutcome.answered(this.latency, {this.bytes, this.message}) : ok = true, inconclusive = false;

  /// A verdict about an address that did not answer.
  ///
  /// The reason is required: a failure the screen cannot explain and a log
  /// cannot grep is the one thing a probe must not produce.
  const IptvProbeOutcome.down(this.message) : ok = false, inconclusive = false, latency = null, bytes = null;

  /// A verdict from a probe that could not ask the question.
  ///
  /// It writes no health record, so the address keeps being ranked with the
  /// lines nobody has probed instead of being buried with the failures —
  /// which is what an `rtmp://` mirror of a working HLS line deserves.
  const IptvProbeOutcome.inconclusive(this.message) : ok = false, inconclusive = true, latency = null, bytes = null;

  /// Whether the address delivered media.
  final bool ok;

  /// Whether the probe abstained because the address is not something it can
  /// open. Never both with [ok].
  final bool inconclusive;

  /// How long the first bytes took, when they came.
  final Duration? latency;

  /// How many bytes were read to decide, when the probe counted them.
  final int? bytes;

  /// Why it failed, or anything else worth showing the user.
  final String? message;

  /// This outcome, with [latency] filled in with [elapsed] when the probe
  /// measured none.
  IptvProbeOutcome withLatency(Duration elapsed) =>
      ok && latency == null ? IptvProbeOutcome(ok: true, latency: elapsed, bytes: bytes, message: message) : this;

  @override
  bool operator ==(Object other) =>
      other is IptvProbeOutcome &&
      other.ok == ok &&
      other.inconclusive == inconclusive &&
      other.latency == latency &&
      other.bytes == bytes &&
      other.message == message;

  @override
  int get hashCode => Object.hash(ok, inconclusive, latency, bytes, message);

  @override
  String toString() =>
      'IptvProbeOutcome(${inconclusive
          ? 'skipped'
          : ok
          ? 'ok'
          : 'down'}${latency == null ? '' : ', ${latency!.inMilliseconds}ms'})';
}

/// Orders two measured latencies, the unmeasured one last.
///
/// Shared by the report (which names the fastest working line) and the
/// ranking (which orders the stored verdicts), because both have to give the
/// same answer about a line whose probe never saw a byte: "we don't know how
/// fast it is" is not "it is instant", and either reading silently promotes a
/// dead address to the top of the list.
int compareIptvProbeLatency(Duration? a, Duration? b) {
  if (a == null) {
    return b == null ? 0 : 1;
  }
  if (b == null) {
    return -1;
  }
  return a.compareTo(b);
}
