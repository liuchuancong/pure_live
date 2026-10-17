import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/environment/app_directory.dart';
import 'package:pure_live/app/environment/app_paths.dart' show AppPaths;
import 'package:pure_live/app/providers/app_providers.dart';
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
final recorderRuntimeProvider = FutureProvider<RecorderRuntime>((ref) async {
  final root = await ref.watch(recorderRootProvider.future);
  final store = await ref.watch(recorderPreferencesStoreProvider.future);
  final sites = ref.watch(sitesProvider);

  final slotsBox = await StorageBoxManager().keyed<String>(RecorderKeys.tasksBox);
  final runtime = await RecorderRuntime.open(
    services: AppRecordServices(
      registry: sites.registry,
      // Read per capture, not once: a settings change reaches the next
      // recording without a restart.
      segmentSecondsOf: () => store.value.clampedSegmentMinutes * 60,
    ),
    slots: BoxRecordSlots(slotsBox),
    rootDirectory: root,
  );
  ref.onDispose(runtime.dispose);

  return runtime;
});

Future<String> _resolveRoot(AppPaths paths, String outputDirectory) async {
  if (outputDirectory.trim().isNotEmpty) {
    return outputDirectory;
  }
  return (await paths.directory(AppDirectory.recordings)).path;
}
