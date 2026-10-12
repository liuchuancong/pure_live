import 'package:live_iptv/src/probe/iptv_probe_outcome/iptv_probe_outcome.dart';
import 'package:meta/meta.dart';

/// The probe of one address of one channel.
@immutable
class IptvLineResult {
  /// A result.
  const new(this.url, this.outcome);

  /// The address that was probed.
  final String url;

  /// What it answered.
  final IptvProbeOutcome outcome;
}

/// Every address of one channel, in the order it was probed.
@immutable
class IptvProbeReport {
  /// A report.
  new({required this.channelId, required List<IptvLineResult> results, this.aborted = false})
    : results = List.unmodifiable(results);

  /// The channel whose addresses were probed.
  final String channelId;

  /// The results, in the playlist's own address order.
  final List<IptvLineResult> results;

  /// Whether the probe stopped before every address had an answer, either
  /// because the caller cancelled or because a good line was found and the
  /// rest were left alone.
  final bool aborted;

  /// The fastest address that answered, null when none did.
  String? get bestUrl {
    final working = results.where((result) => result.outcome.ok).toList();
    if (working.isEmpty) {
      return null;
    }
    working.sort((a, b) => compareIptvProbeLatency(a.outcome.latency, b.outcome.latency));
    return working.first.url;
  }

  /// Whether nothing answered: the channel is unwatchable right now.
  ///
  /// A channel whose every address the probe could not ask about is *not*
  /// down — it is unknown, which is the honest answer for an `rtmp://`-only
  /// line and the difference between "switch to the next list" and "this
  /// list is dead". A channel with no address at all is down, because there
  /// is nothing left to be unsure about.
  bool get isDown => bestUrl == null && !isUnprobed;

  /// Whether the probe learned nothing: every address abstained.
  bool get isUnprobed => results.isNotEmpty && results.every((result) => result.outcome.inconclusive);
}
