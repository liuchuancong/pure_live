/// Probing a channel's addresses and ranking them.
///
/// One public unit per folder, as in `src/model/`: the seam and its verdict
/// (`iptv_probe_outcome/`), what a round produced (`iptv_probe_report/`), the
/// ranking over the stored verdicts (`iptv_line_ranking/`), the walk that
/// fills them in (`iptv_line_prober/`), and the transport adapter
/// (`live_net_line_probe/`).
///
/// The transport is a seam — `IptvLineProbe` — exactly as the importer's
/// `IptvFetcher` is: this package does not know dio, a proxy rule, or how
/// many bytes make a stream count as alive. It only knows how to walk a list
/// of addresses without stampeding the server, how long to wait for one, and
/// what to do with the answer.
library;

export 'iptv_line_prober/iptv_line_prober.dart';
export 'iptv_line_ranking/iptv_line_ranking.dart';
export 'iptv_probe_outcome/iptv_probe_outcome.dart';
export 'iptv_probe_report/iptv_probe_report.dart';
export 'live_net_line_probe/live_net_line_probe.dart';
