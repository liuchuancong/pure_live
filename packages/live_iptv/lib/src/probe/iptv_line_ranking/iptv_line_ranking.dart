import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/probe/iptv_probe_outcome/iptv_probe_outcome.dart';
import 'package:live_iptv/src/probe/iptv_probe_report/iptv_probe_report.dart';
import 'package:meta/meta.dart';

/// One playable address of a channel, with the request it needs.
@immutable
class IptvLineCandidate {
  /// A candidate.
  const new({required this.url, this.headers = const {}, this.health});

  /// The address.
  final String url;

  /// The request headers the playlist declared for the channel.
  final Map<String, String> headers;

  /// What the last probe said, null when this address has never been
  /// probed or the verdict is too old to act on.
  final IptvLineHealth? health;

  /// Whether the last verdict was good.
  bool get isHealthy => health?.ok ?? false;

  /// Whether the address has an answer at all.
  bool get isProbed => health != null;
}

/// The addresses of [entry]: the primary URL first, then its alternatives,
/// with duplicates gone.
///
/// The order is the playlist's, and it is kept as the tie-break everywhere
/// below: a list the provider put first is a claim that it is the best one,
/// and probing must not quietly invert that when several addresses answer
/// equally fast.
List<String> iptvLineUrls(IptvEntry entry) {
  final urls = <String>[];
  for (final url in [entry.url, ...entry.alternatives]) {
    final trimmed = url.trim();
    if (trimmed.isNotEmpty && !urls.contains(trimmed)) {
      urls.add(trimmed);
    }
  }
  return List.unmodifiable(urls);
}

/// The channel's addresses, best first, given what the probes found.
///
/// Three buckets, in that order: an address that answered, an address
/// nobody has asked, and an address that failed. A never-asked address sits
/// *ahead* of the failures rather than behind them, because "nobody knows"
/// is not evidence of death — a channel imported an hour ago has no
/// verdicts, and ranking it by that absence would send the player to a
/// known-dead address first.
///
/// A verdict older than [staleAfter] is dropped to "nobody knows": sources
/// come back, and a failure from yesterday has no business deciding tonight's
/// order.
List<IptvLineCandidate> rankIptvLines(
  IptvChannel channel,
  Map<String, IptvLineHealth> health, {
  DateTime? now,
  Duration staleAfter = const Duration(hours: 12),
}) {
  final urls = iptvLineUrls(channel.entry);
  final ranked = <_RankedLine>[];
  for (final (index, url) in urls.indexed) {
    final record = health[url];
    final stale = record != null && now != null && now.difference(record.checkedAt) > staleAfter;
    final verdict = stale ? null : record;
    ranked.add(
      _RankedLine(
        candidate: IptvLineCandidate(url: url, headers: channel.entry.headers.asMap(), health: verdict),
        index: index,
        bucket: verdict == null ? 1 : (verdict.ok ? 0 : 2),
      ),
    );
  }
  ranked.sort((a, b) {
    if (a.bucket != b.bucket) {
      return a.bucket.compareTo(b.bucket);
    }
    final byLatency = compareIptvProbeLatency(a.candidate.health?.latency, b.candidate.health?.latency);
    if (byLatency != 0) {
      return byLatency;
    }
    final byFailures = (a.candidate.health?.failures ?? 0).compareTo(b.candidate.health?.failures ?? 0);
    if (byFailures != 0) {
      return byFailures;
    }
    return a.index.compareTo(b.index);
  });
  return List.unmodifiable([for (final line in ranked) line.candidate]);
}

/// One ranked address, with the bucket and the playlist order it keeps.
class _RankedLine {
  const new({required this.candidate, required this.index, required this.bucket});

  final IptvLineCandidate candidate;
  final int index;
  final int bucket;
}

/// Folds the verdicts of [reports] into [previous], keyed by URL.
///
/// An address nobody probed — because the walk stopped at a good line, or
/// because the caller cancelled — keeps the verdict it already had: silence
/// is not a retraction, and a probe that abstained must not quietly promote
/// a known-dead mirror back to the front of the ranking.
Map<String, IptvLineHealth> mergeIptvLineHealth(
  Iterable<IptvProbeReport> reports, {
  Map<String, IptvLineHealth> previous = const {},
  DateTime? now,
}) {
  final moment = now ?? DateTime.now();
  final next = {...previous};
  for (final report in reports) {
    for (final result in report.results) {
      // An abstention writes nothing: the line keeps the verdict it already
      // had, or no verdict at all, which is what keeps an unprobeable
      // address ahead of a known-dead one in the ranking.
      if (result.outcome.inconclusive) {
        continue;
      }
      final outcome = result.outcome;
      next[result.url] = outcome.ok
          ? IptvLineHealth.probe(
              url: result.url,
              checkedAt: moment,
              latency: outcome.latency ?? Duration.zero,
              message: outcome.message,
            )
          : IptvLineHealth.failed(
              url: result.url,
              checkedAt: moment,
              message: outcome.message,
              previous: previous[result.url],
            );
    }
  }
  return Map.unmodifiable(next);
}
