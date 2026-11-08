import 'dart:async' show Future, TimeoutException;
import 'dart:io' show File, Platform;

import 'package:live_net/live_net.dart' show DioFactory;
import 'package:live_sites/live_sites.dart' show LiveRoom, LiveRoomProvider, LiveSiteRegistry, createBuiltInLiveSites;
import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/boot/user_notification_providers.dart'
    show enableUserNotifications, postLiveAlert;
import 'package:pure_live/features/settings/browse/live_alert_settings.dart' show kLiveAlertCheckInterval;
import 'package:pure_live/modules/live/favorites/alerts/live_alert_watch.dart' show LiveAlertRoom, LiveAlertWatchFile;
import 'package:pure_live/modules/live/favorites/alerts/live_alerts.dart' show LiveAlertTracker;
import 'package:workmanager/workmanager.dart' show Constraints, ExistingPeriodicWorkPolicy, NetworkType, Workmanager;

/// The periodic task's name, both unique name and task name: one schedule,
/// replaced when the covered follows or the state file's path change.
const String kLiveAlertTaskName = 'pure_live.live_alert_check';

/// The input key the state file's path rides under.
const String kLiveAlertFileInput = 'file';

/// Hands the periodic task to the dispatcher: the background engine reads
/// the shared state, checks the covered follows, posts what began and
/// writes what it saw back.
@pragma('vm:entry-point')
void liveAlertCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final path = inputData?[kLiveAlertFileInput];
    if (path is! String || path.isEmpty) return true;
    try {
      await runLiveAlertBackgroundCheck(file: LiveAlertWatchFile(File(path)));
      return true;
    } on Object {
      // A failed check re-runs at the system's own cadence; the state file
      // still carries what the app knows.
      return false;
    }
  });
}

/// Initializes the background dispatcher where a periodic check exists.
/// Android's WorkManager is the only transport; the desktops keep the
/// in-app watcher alone. Best-effort: a platform whose plugin fails to
/// initialize loses the background check, not the app.
Future<void> initializeLiveAlertBackground() async {
  if (!Platform.isAndroid) return;
  try {
    await Workmanager().initialize(liveAlertCallbackDispatcher);
  } on Object catch (error) {
    // The in-app watcher still covers the room checks while the app runs.
    appLog.forCategory('alerts').warning(
      'WorkManager init failed; background alerts will not run',
      fields: {'error': '$error'},
    );
  }
}

/// Turns the periodic background check on or off. Android only; the file's
/// current path rides the schedule, so a storage move re-registers through
/// the same call.
Future<void> scheduleLiveAlertCheck({required bool on, required String filePath}) async {
  if (!Platform.isAndroid) return;
  try {
    if (!on) {
      await Workmanager().cancelByUniqueName(kLiveAlertTaskName);
      return;
    }
    await Workmanager().registerPeriodicTask(
      kLiveAlertTaskName,
      kLiveAlertTaskName,
      frequency: kLiveAlertCheckInterval,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      inputData: {kLiveAlertFileInput: filePath},
    );
  } on Object {
    // A schedule the system refused costs the background check only.
  }
}

/// How long past the app's next own check the background check waits (a
/// late timer is not a frozen app).
const Duration kLiveAlertBackgroundGrace = Duration(minutes: 5);

/// One background check: reads the state, and unless the app checks itself
/// now, asks the covered follows for their live states, posts the ones
/// that began a broadcast and writes what it saw back (merged with what
/// the app wrote meanwhile). No database, no cookies.
Future<void> runLiveAlertBackgroundCheck({
  required LiveAlertWatchFile file,
  DateTime Function() now = DateTime.now,
}) async {
  final watch = await file.read();
  if (watch == null || watch.rooms.isEmpty) return;
  final next = watch.nextCheck;
  if (next != null && now().isBefore(next.add(kLiveAlertBackgroundGrace))) return;
  await enableUserNotifications();
  final tracker = LiveAlertTracker(now: now)..adopt(watch.states);
  final registry = LiveSiteRegistry(createBuiltInLiveSites(http: DioFactory().create()));
  final started = tracker.observe(await fetchLiveAlertStates(registry, watch.rooms));
  for (final room in started) {
    final row = watch.roomOf(room);
    if (row == null) continue;
    final content = row.contentOf(watch.texts, liveTitle: room.content.title);
    try {
      await postLiveAlert(
        identityKey: '${room.ref.platform}:${room.ref.roomId}',
        title: content.title,
        body: content.body,
      );
    } on Object {
      // One room's refusal does not stop the walk; the tracker has already
      // seen the broadcast, so this check does not repeat it.
    }
  }
  final latest = await file.read() ?? watch;
  final merged = LiveAlertTracker(now: now)
    ..adopt(latest.states)
    ..adopt(tracker.states);
  await file.write(latest.withStates(merged.states));
}

/// How many rooms one check asks at once: the follows refresh pool's own
/// shape, one slow platform occupying its slot while the others keep
/// asking.
const int kLiveAlertConcurrency = 3;

/// How long one room's ask may take.
const Duration kLiveAlertPerSiteTimeout = Duration(seconds: 12);

/// The rooms' live states as one walk; failures answer rooms the platform
/// did not name, which the tracker treats as no evidence.
Future<List<LiveRoom>> fetchLiveAlertStates(LiveSiteRegistry registry, List<LiveAlertRoom> rooms) async {
  final fresh = <LiveRoom>[];
  var next = 0;
  Future<void> worker() async {
    while (next < rooms.length) {
      final row = rooms[next++];
      final provider = registry.getById(row.platform)?.capability<LiveRoomProvider>();
      if (provider == null) continue;
      try {
        final answer = await provider.getRoom(row.roomId).timeout(kLiveAlertPerSiteTimeout);
        answer.match((_) {}, (detail) {
          // A platform may answer under another id for the same room;
          // the tracker judges by the follow's identity.
          final same = detail.ref.platform == row.platform && detail.ref.roomId == row.roomId;
          fresh.add(
            same
                ? detail
                : detail.rebuild(
                    (b) => b
                      ..ref.roomId = row.roomId
                      ..ref.platform = row.platform,
                  ),
          );
        });
      } on TimeoutException {
        // Only a site that took the room can time out; the walk keeps
        // going.
      } on Object {
        // The same trouble, and one room's trouble is no evidence.
      }
    }
  }

  await Future.wait<void>([for (var i = 0; i < kLiveAlertConcurrency; i++) worker()]);
  return fresh;
}
