import 'package:live_iptv/src/import/iptv_import_result.dart';
import 'package:live_iptv/src/import/iptv_importer.dart';
import 'package:live_iptv/src/model/model.dart';
import 'package:live_iptv/src/sync/iptv_sync_policy/iptv_sync_policy.dart';

/// What one refresh round did.
///
/// Kept with the coordinator that returns it: a report nobody can build by
/// hand is the coordinator's own answer shape, not a type of its own.
class IptvSyncReport {
  /// A report of one finished round.
  const new({
    required this.startedAt,
    required this.finishedAt,
    this.playlists = const [],
    this.guides = const [],
    this.mappingsWritten = 0,
  });

  /// The instant the round began.
  final DateTime startedAt;

  /// The instant it finished; equal to [startedAt] when nothing was asked.
  final DateTime finishedAt;

  /// What each expired playlist answered with.
  final List<IptvImportResult> playlists;

  /// What each expired guide answered with.
  final List<IptvImportResult> guides;

  /// How many channel-to-guide mappings the round re-decided after a guide
  /// landed — the step that turns "the guide was refreshed" into "the
  /// channel list shows tonight's programmes".
  final int mappingsWritten;

  /// Whether any source was refreshed rather than skipped or failed.
  bool get didAnything => refreshed > 0 || mappingsWritten > 0;

  /// How many sources ended up replaced by a newer copy.
  int get refreshed => [...playlists, ...guides].where((result) => result.isImported).length;

  /// How many sources could not be refreshed at all.
  int get failures => [...playlists, ...guides]
      .where((result) => result.status == IptvImportStatus.networkFailed || result.status == IptvImportStatus.failed)
      .length;

  /// How long the round took.
  Duration get elapsed => finishedAt.difference(startedAt);

  @override
  String toString() =>
      'IptvSyncReport(refreshed: $refreshed, failed: $failures, mappings: $mappingsWritten, in ${elapsed.inSeconds}s)';
}

/// Runs the due refreshes of a library, one round at a time.
///
/// The coordinator exists because two triggers fire at once in real life:
/// start-up and returning to the foreground, each reading the same policy and
/// each wanting the same thing. Overlapping rounds would be worse than
/// wasteful — two imports of one playlist both reconcile against the stored
/// list, and the second writes over the first's channels. So a round already
/// in flight is handed back to whoever asks next, and a policy that asks for
/// nothing returns an empty report without touching the network.
final class IptvSyncCoordinator {
  /// A coordinator refreshing through [importer].
  new({required this.importer});

  /// The importer whose library and sources this refreshes.
  final IptvImporter importer;

  Future<IptvSyncReport>? _running;

  /// Whether a round is in flight.
  bool get isRunning => _running != null;

  /// The remote playlists older than the policy allows.
  ///
  /// Local imports (no recorded address) are never due: there is nothing to
  /// re-download, and calling them stale would offer a sync that can only
  /// fail.
  List<IptvPlaylist> duePlaylists(IptvSyncPolicy policy, {DateTime? now}) {
    if (!policy.playlists) {
      return const [];
    }
    final moment = now ?? DateTime.now();
    return List.unmodifiable([
      for (final playlist in importer.library.playlists)
        if ((playlist.url ?? '').isNotEmpty && moment.difference(playlist.importedAt) >= policy.playlistInterval)
          playlist,
    ]);
  }

  /// The remote guide sources older than the policy allows, automatic refresh
  /// on, and address-backed (a guide imported from a file cannot be synced by
  /// nobody but the viewer).
  List<EpgSource> dueGuides(IptvSyncPolicy policy, {DateTime? now}) {
    if (!policy.guides) {
      return const [];
    }
    final moment = now ?? DateTime.now();
    return List.unmodifiable([
      for (final source in importer.library.guideSources)
        if (source.isRemote &&
            source.autoUpdate &&
            (source.lastRefresh == null || moment.difference(source.lastRefresh!) >= policy.guideInterval))
          source,
    ]);
  }

  /// Refreshes what [policy] says is due, and re-runs the guide matcher when
  /// a guide landed.
  Future<IptvSyncReport> syncDue(IptvSyncPolicy policy, {DateTime? now}) {
    final moment = now ?? DateTime.now();
    final running = _running;
    if (running != null) {
      return running;
    }
    if (policy.isIdle) {
      return Future<IptvSyncReport>.value(IptvSyncReport(startedAt: moment, finishedAt: moment));
    }
    late final Future<IptvSyncReport> round;
    round = _run(policy, moment).whenComplete(() {
      if (identical(_running, round)) {
        _running = null;
      }
    });
    _running = round;
    return round;
  }

  Future<IptvSyncReport> _run(IptvSyncPolicy policy, DateTime moment) async {
    final playlistResults = policy.playlists
        ? await importer.syncExpired(olderThan: policy.playlistInterval, now: moment)
        : const <IptvImportResult>[];
    final guideResults = policy.guides
        ? await importer.syncExpiredGuides(olderThan: policy.guideInterval, now: moment)
        : const <IptvImportResult>[];
    var mappings = 0;
    if (guideResults.any((result) => result.isImported)) {
      for (final source in importer.library.guideSources) {
        mappings += await importer.library.autoMatch(sourceId: source.id);
      }
    }
    return IptvSyncReport(
      startedAt: moment,
      finishedAt: DateTime.now(),
      playlists: playlistResults,
      guides: guideResults,
      mappingsWritten: mappings,
    );
  }
}
