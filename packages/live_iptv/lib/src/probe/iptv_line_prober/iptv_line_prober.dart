import 'dart:async';

import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/probe/iptv_line_ranking/iptv_line_ranking.dart';
import 'package:live_iptv/src/probe/iptv_probe_outcome/iptv_probe_outcome.dart';
import 'package:live_iptv/src/probe/iptv_probe_report/iptv_probe_report.dart';

/// Walks a channel's addresses and asks each one how it is.
///
/// [concurrency] bounds how many probes run at once, because the point of
/// probing is to be asked about a hundred channels and a hundred channels
/// have a hundred addresses each; unbounded, that is a denial-of-service
/// attempt against whoever sold the list. [timeout] is applied per address,
/// so one black-holed host cannot hold up the report — a probe that never
/// answers is a failure, not an unfinished future.
///
/// By default a channel stops being probed as soon as an address answers
/// ([stopOnFirstOk]): the user is waiting for a picture, and timing the
/// remaining addresses tells them nothing they need before it starts. A
/// deliberate health check of the whole list passes `stopOnFirstOk: false`.
final class IptvLineProber {
  /// A prober asking [probe] about each address.
  new({
    required this.probe,
    this.concurrency = 4,
    this.timeout = const Duration(seconds: 6),
    this.stopOnFirstOk = true,
  });

  /// The transport seam.
  final IptvLineProbe probe;

  /// How many addresses are asked at once, at most.
  final int concurrency;

  /// How long one address may take before it counts as silent.
  final Duration timeout;

  /// Whether a channel's probe stops at its first working address.
  final bool stopOnFirstOk;

  bool _cancelled = false;

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled;

  /// Stops handing out more addresses.
  ///
  /// Probes already in flight are not aborted — the transport owns those,
  /// and this package will not guess how to interrupt one — but no further
  /// address is asked, and the report says [IptvProbeReport.aborted].
  void cancel() => _cancelled = true;

  /// Probes every address of [channel].
  Future<IptvProbeReport> probeChannel(IptvChannel channel, {bool? stopOnFirstOk}) async {
    final urls = iptvLineUrls(channel.entry);
    if (urls.isEmpty) {
      return IptvProbeReport(channelId: channel.id, results: const [], aborted: true);
    }
    final stopFirst = stopOnFirstOk ?? this.stopOnFirstOk;
    final answers = List<IptvLineResult?>.filled(urls.length, null);
    var cursor = 0;
    var settled = false;

    Future<void> worker() async {
      while (true) {
        if (_cancelled || (stopFirst && settled)) {
          return;
        }
        final index = cursor++;
        if (index >= urls.length) {
          return;
        }
        final outcome = await _ask(urls[index], channel.entry.headers);
        answers[index] = IptvLineResult(urls[index], outcome);
        if (outcome.ok) {
          settled = true;
        }
      }
    }

    await Future.wait([for (var start = 0; start < concurrency.clamp(1, urls.length); start++) worker()]);
    final results = [for (final answer in answers) ?answer];
    return IptvProbeReport(
      channelId: channel.id,
      results: results,
      aborted: _cancelled || results.length != urls.length,
    );
  }

  /// Probes [channels] a channel at a time, reporting each as it finishes.
  ///
  /// Channels are walked one after another rather than all at once: the
  /// concurrency limit is per channel, and running a hundred channels in
  /// parallel would multiply it into a hundred times the traffic the caller
  /// agreed to. [onReport] exists so a screen can fill in as it goes.
  ///
  /// Returns the reports for the channels it got through; [cancel] stops it
  /// handing out new ones, and what was already collected comes back rather
  /// than being discarded.
  Future<List<IptvProbeReport>> probeChannels(
    List<IptvChannel> channels, {
    void Function(IptvProbeReport report)? onReport,
    int? limit,
  }) async {
    final reports = <IptvProbeReport>[];
    final wanted = limit == null ? channels.length : limit.clamp(0, channels.length);
    for (final channel in channels.take(wanted)) {
      if (_cancelled) {
        break;
      }
      final report = await probeChannel(channel);
      reports.add(report);
      onReport?.call(report);
    }
    return List.unmodifiable(reports);
  }

  /// One address, with the timeout and the exceptions turned into a verdict.
  Future<IptvProbeOutcome> _ask(String url, Map<String, String> headers) async {
    final started = DateTime.now();
    try {
      final outcome = await probe(url, headers).timeout(timeout);
      return outcome.withLatency(DateTime.now().difference(started));
    } on TimeoutException {
      return IptvProbeOutcome.down('no answer in ${timeout.inSeconds}s');
    } on Object catch (error) {
      return IptvProbeOutcome.down('$error');
    }
  }
}
