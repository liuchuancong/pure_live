import 'dart:async' show Timer, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show EpgSourceX;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/features/iptv/iptv_epg_controller.dart';
import 'package:pure_live/features/iptv/iptv_sources_controller.dart';
import 'package:pure_live/l10n/translations.dart';

/// The intervals the guide updater offers, in the reference's own scale:
/// six and twelve hours, a day, three days and a week.
enum IptvUpdateInterval {
  /// Every two hours.
  twoHours(2),

  /// Every six hours.
  sixHours(6),

  /// Every twelve hours.
  twelveHours(12),

  /// Every day.
  day(24),

  /// Every two days.
  twoDays(48),

  /// Every three days.
  threeDays(72);

  IptvUpdateInterval(this.hours);

  /// The interval in hours.
  final int hours;

  /// The interval as the source rounds' schedule.
  Duration get duration => Duration(hours: hours);

  /// The localized name: hours up to a day, days above it.
  String label(Translations t) =>
      hours <= 24 ? t.iptv.updateIntervalHours(hours: hours) : t.iptv.updateIntervalDays(days: hours ~/ 24);
}

/// The preference the interval is kept under.
const String _intervalPref = 'iptv.update.hours';

/// The chosen update interval: a preference read once at boot, written on
/// every change, so the updater and the settings card never disagree.
final class IptvUpdateIntervalController extends Notifier<IptvUpdateInterval> {
  @override
  IptvUpdateInterval build() {
    try {
      final hours = StoragePrefs.getInt(_intervalPref);
      for (final interval in IptvUpdateInterval.values) {
        if (interval.hours == hours) return interval;
      }
    } on Object {
      // A closed store falls back to the default.
    }
    return IptvUpdateInterval.day;
  }

  /// Chooses [interval] and stores it for the next start.
  void select(IptvUpdateInterval interval) {
    if (interval == state) return;
    state = interval;
    try {
      unawaited(StoragePrefs.setInt(_intervalPref, interval.hours));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The chosen interval.
final iptvUpdateIntervalProvider = NotifierProvider<IptvUpdateIntervalController, IptvUpdateInterval>(
  IptvUpdateIntervalController.new,
);

/// The reference's launch auto-sync switch: off by default, so an ordinary
/// launch stays network-idle. When off, the guide updater does nothing even
/// for sources whose own auto-update flag is on.
const String _autoSyncPref = 'iptv.autoSync';

/// Owns that switch.
final class IptvAutoSyncController extends Notifier<bool> {
  @override
  bool build() {
    try {
      return StoragePrefs.getBool(_autoSyncPref) ?? false;
    } on Object {
      return false;
    }
  }

  /// Flips auto-sync, writing through.
  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(_autoSyncPref, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The launch auto-sync switch.
final iptvAutoSyncProvider = NotifierProvider<IptvAutoSyncController, bool>(IptvAutoSyncController.new);

/// Keeps the network guides that asked for automatic updates current.
///
/// Every minute it looks for a remote guide whose `autoUpdate` flag is on
/// and whose last refresh is older than the chosen interval, then syncs it
/// through the guide controller — one at a time, never over a manual round.
/// A failed attempt is not retried until the interval has passed again, so
/// a dead address cannot hit the network once a minute.
///
/// The app starts this once at boot; the timer belongs to the process, not
/// to a page, so changing tabs does not stop the schedule. A mobile
/// platform may suspend the process in the background — the schedule then
/// resumes the next time the app runs, which is the most a timer in the
/// app process can honestly promise.
final class IptvAutoUpdater {
  /// Starts the schedule.
  IptvAutoUpdater(this._ref) {
    _first = Timer(const Duration(seconds: 20), () => unawaited(_tick()));
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(_tick()));
  }

  final Ref _ref;
  late final Timer _timer;
  late final Timer _first;

  /// The last attempt per guide id, so a failure waits a full interval.
  final Map<String, DateTime> _attempted = {};

  bool _running = false;

  /// Stops both timers.
  void dispose() {
    _first.cancel();
    _timer.cancel();
  }

  Future<void> _tick() async {
    if (_running || !_ref.read(iptvAutoSyncProvider)) return;
    final epg = _ref.read(iptvEpgProvider);
    final sources = _ref.read(iptvSourcesProvider);
    // A manual import, a sync round or a single-source operation owns the
    // network and the guide store; the schedule waits for the next minute.
    if (!epg.ready ||
        !sources.ready ||
        sources.syncAll != null ||
        epg.busy.isNotEmpty ||
        sources.busy.isNotEmpty ||
        epg.importing ||
        sources.importing) {
      return;
    }
    final interval = _ref.read(iptvUpdateIntervalProvider).duration;
    final now = DateTime.now();
    final due = [
      for (final source in epg.sources)
        if (source.isRemote && source.autoUpdate && _isDue(source.id, source.lastRefresh, interval, now)) source,
    ];
    if (due.isEmpty) return;
    _running = true;
    try {
      final controller = _ref.read(iptvEpgProvider.notifier);
      for (final source in due) {
        if (!_ref.mounted) return;
        _attempted[source.id] = DateTime.now();
        await controller.syncSource(source);
        // A manual round started meanwhile takes the rest of the queue.
        if (_ref.read(iptvSourcesProvider).syncAll != null) break;
      }
    } finally {
      _running = false;
    }
  }

  bool _isDue(String id, DateTime? lastRefresh, Duration interval, DateTime now) {
    if (lastRefresh != null && now.difference(lastRefresh) < interval) return false;
    final attempt = _attempted[id];
    return attempt == null || now.difference(attempt) >= interval;
  }
}

/// The process-wide guide updater, started by the app root.
final iptvAutoUpdaterProvider = Provider<IptvAutoUpdater>((ref) {
  final updater = IptvAutoUpdater(ref);
  ref.onDispose(updater.dispose);
  return updater;
});
