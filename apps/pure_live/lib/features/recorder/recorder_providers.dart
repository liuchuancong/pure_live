import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_record_core/live_record_core.dart'
    show AnchorDirectoryStyle, RecordNaming, RecordPolicy, statusIsTerminal;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/environment/app_directory.dart';
import 'package:pure_live/app/environment/app_paths.dart' show AppPaths;
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/recorder/record_storage_cleaner.dart';
import 'package:pure_live/features/recorder/recorder_engine.dart';
import 'package:pure_live/features/recorder/recorder_preferences.dart';

/// The recorder's persisted choices, opened lazily on its first reader — the
/// store owns an open box, and unlike the boot-time documents nothing here
/// is needed before the first frame.
final recorderPreferencesStoreProvider = FutureProvider<RecorderPreferencesStore>((ref) async {
  final box = await StorageBoxManager().keyed<Map<dynamic, dynamic>>(RecorderKeys.box);
  final store = RecorderPreferencesStore(repository: HiveStorageRepository<Map<dynamic, dynamic>>(box: box));
  await store.load();
  ref.onDispose(store.dispose);
  return store;
});

/// The recorder's choices as a stream: the loaded value, then every change
/// applied through the store.
final recorderPreferencesProvider = StreamProvider<RecorderPreferences>((ref) async* {
  final store = await ref.watch(recorderPreferencesStoreProvider.future);
  yield store.value;
  yield* store.changes;
});

/// Applies [transform] to the persisted recorder choices; completes once the
/// change is durable. A reader that arrives before the store has opened
/// waits for it.
Future<void> updateRecorderPreferences(
  Future<RecorderPreferencesStore> Function() storeOf,
  RecorderPreferences Function(RecorderPreferences preferences) transform,
) async {
  final store = await storeOf();
  await store.update(transform);
}

/// The output root recordings are written under: the user's directory when
/// one is set, the app's own recordings tree otherwise. Re-resolves on every
/// preference change.
final recorderRootProvider = FutureProvider<String>((ref) async {
  final paths = ref.watch(pathsProvider);
  final preferences = await ref.watch(recorderPreferencesProvider.future);
  return await _resolveRoot(paths, preferences.outputDirectory);
});

/// The recording session: the ledger restored (a previous run's unjoined
/// segments joined, their display names applied) and the site graph wired in
/// behind the kernel's contracts.
///
/// The runtime reads the output root once at open and is rebuilt when it
/// changes — the naming layer is fixed inside the orchestrator. Tasks already
/// stored keep the directory they were created with, because their paths
/// travel inside the task; a rebuild joins what the previous one had running.
///
/// Everything else the recorder settings answer is applied live onto this
/// one runtime: the shared [RecordPolicy]'s fields and the naming style are
/// rewritten on every preference change (a rebuild would stop the recordings
/// that are running), captures read the FFmpeg trio at their own opening,
/// and the cache-limit prune runs as tasks complete.
final recorderRuntimeProvider = FutureProvider<RecorderRuntime>((ref) async {
  final root = await ref.watch(recorderRootProvider.future);
  final store = await ref.watch(recorderPreferencesStoreProvider.future);
  final sites = ref.watch(sitesProvider);
  final settings = store.value;

  final slotsBox = await StorageBoxManager().keyed<String>(RecorderKeys.tasksBox);
  final policy = RecordPolicy(
    maxConcurrent: settings.maxTaskCount,
    pollInterval: Duration(seconds: settings.liveCheckInterval),
    retryInterval: Duration(seconds: settings.retryDelaySeconds),
    maxCaptureFailures: settings.autoReconnect ? settings.maxRetryCount : 0,
    enablePolling: settings.enablePolling,
    pollBackoff: settings.enableBackoff,
    maxPollInterval: Duration(seconds: settings.maxCheckInterval),
  );
  final naming = RecordNaming(
    rootDirectory: root,
    anchorDirectoryStyle: settings.pinyinFolders ? AnchorDirectoryStyle.pinyin : AnchorDirectoryStyle.identifier,
  );

  // The tray's receiving end: the live count goes into its menu and hint,
  // and the kernel's composed lines go out as system notifications.
  final tray = ref.watch(desktopTrayPortProvider);
  final runtime = await RecorderRuntime.open(
    services: AppRecordServices(
      registry: sites.registry,
      settingsOf: () => store.value,
      onNotice: (title, body) => tray.notifyTray(title: title, body: body),
    ),
    slots: BoxRecordSlots(slotsBox),
    policy: policy,
    naming: naming,
  );
  ref.onDispose(runtime.dispose);

  // 开机自动开始: waiting and interrupted tasks re-watch themselves on the
  // runtime's first open — a room that is up by now starts capturing with
  // the rest. The reference's "应用启动时恢复等待与中断的录制", off by
  // default: the watcher only re-checks what the user left watching when on.
  if (settings.autoStartOnBoot) {
    for (final task in runtime.tasks) {
      if (!statusIsTerminal(task.status)) {
        unawaited(runtime.watch(task.target).catchError((Object _) => task));
      }
    }
  }

  // The settings' live door: rewrite the shared objects the orchestrator
  // reads per decision, and prune the folder when the cap answer changes.
  final changes = store.changes.listen((next) {
    policy
      ..maxConcurrent = next.maxTaskCount
      ..pollInterval = Duration(seconds: next.liveCheckInterval)
      ..retryInterval = Duration(seconds: next.retryDelaySeconds)
      ..maxCaptureFailures = next.autoReconnect ? next.maxRetryCount : 0
      ..enablePolling = next.enablePolling
      ..pollBackoff = next.enableBackoff
      ..maxPollInterval = Duration(seconds: next.maxCheckInterval);
    naming.anchorDirectoryStyle = next.pinyinFolders
        ? AnchorDirectoryStyle.pinyin
        : AnchorDirectoryStyle.identifier;
    if (next.enableCacheLimit) {
      unawaited(RecordStorage.pruneToLimit(root: root, maxMB: next.maxCacheMB));
    }
  });
  ref.onDispose(() => unawaited(changes.cancel()));

  // 录制完成即检查容量: the cap is about finished files, so the moment one
  // lands is the moment it can be exceeded. The same beat carries the tray's
  // recording count — the rooms the orchestrator still has work for, in the
  // menu's first row and the hint (the reference's A16.1 T4).
  void reportTrayCount() =>
      tray.reportRecordingCount(runtime.tasks.where((task) => !statusIsTerminal(task.status)).length);
  final completions = runtime.onChanged.listen((task) {
    reportTrayCount();
    if (statusIsTerminal(task.status) && store.value.enableCacheLimit) {
      unawaited(RecordStorage.pruneToLimit(root: root, maxMB: store.value.maxCacheMB));
    }
  });
  ref.onDispose(() => unawaited(completions.cancel()));
  reportTrayCount();

  if (settings.enableCacheLimit) {
    unawaited(RecordStorage.pruneToLimit(root: root, maxMB: settings.maxCacheMB));
  }

  return runtime;
});

Future<String> _resolveRoot(AppPaths paths, String outputDirectory) async {
  if (outputDirectory.trim().isNotEmpty) {
    return outputDirectory;
  }
  return (await paths.directory(AppDirectory.recordings)).path;
}
