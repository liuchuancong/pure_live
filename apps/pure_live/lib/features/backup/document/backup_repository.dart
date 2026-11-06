import 'dart:async' show Completer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show IptvKeys;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_settings.dart';
import 'package:pure_live/features/backup/document/restore_preview.dart';
import 'package:pure_live/features/backup/webdav/webdav_settings.dart' show appSecretStoreProvider;
import 'package:pure_live/modules/live/areas/areas.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/multiview/multiview_controller.dart' show multiviewRepositoryProvider;
import 'package:pure_live/modules/live/recorder/data/recording_repository.dart';
import 'package:pure_live/modules/live/recorder/data/recording_task.dart';

/// Why a restore was refused before it touched anything: this device is
/// still recording or finishing a take, and the restore would clear the
/// task entry the engine writes to.
///
/// The surfaces translate it into their own message; anything else the
/// restore throws is a genuine failure.
final class BackupRecordingsBusy implements Exception {
  /// The restore cannot run while a take is live.
  const BackupRecordingsBusy();
}

/// Why a restore found nothing to do: the document carries no entry in any
/// of its sections. Restoring it would only empty the stores, which is
/// never what a reader of an empty file means.
final class BackupDocumentEmpty implements Exception {
  /// The document is empty.
  const BackupDocumentEmpty();
}

/// Why a restore was refused before it touched anything: another restore
/// is still running on this device, and two would interleave their clears
/// and writes into a mix of both documents.
final class BackupRestoreBusy implements Exception {
  /// Another restore holds the lock.
  const new();
}

/// One restore at a time. Every way in — a local file, the cloud, a WebDAV
/// server — restores through [BackupRepository.apply], and [run] holds the
/// lock for the restore it runs: a second one is refused with
/// [BackupRestoreBusy] rather than queued behind the first, so the user who
/// started it hears at once that it did not happen.
final class BackupRestoreLock {
  /// A free lock.
  new();

  Future<void>? _busy;

  /// Whether a restore holds the lock right now. The entries ask before
  /// they read or download anything, so a second restore is turned away
  /// before the user picks and confirms it.
  bool get busy => _busy != null;

  /// Completes when the restore holding the lock now has ended — at once
  /// when none does: for work that must not read the stores halfway
  /// through a restore.
  Future<void> get idle => _busy ?? Future<void>.value();

  /// Runs [restore] holding the lock; throws [BackupRestoreBusy], before
  /// [restore] starts, when another restore holds it.
  Future<T> run<T>(Future<T> Function() restore) async {
    if (_busy != null) throw const BackupRestoreBusy();
    final done = Completer<void>();
    _busy = done.future;
    try {
      return await restore();
    } finally {
      _busy = null;
      done.complete();
    }
  }
}

/// The backup feature's own view of the user data: it reads the four
/// user-data namespaces, the settings subset and (on request) the vault
/// into a [BackupDocument] and writes a document back, section by section.
///
/// The repositories stay the single writers of their stores — capture and
/// restore go through the same handles the favorites, history, areas and
/// recorder pages use, so every watch stream fires and the pages refresh
/// at once.
final class BackupRepository {
  /// Serves the four user-data namespaces and, when the vault opened, the
  /// secrets. [restoreLock] is the process's one lock (the provider's);
  /// left out, the repository gets one of its own.
  BackupRepository({
    required this.follows,
    required this.history,
    required this.areaFollows,
    required this.recordings,
    this.iptv,
    this.multiview,
    this.secrets,
    BackupRestoreLock? restoreLock,
  }) : _restoreLock = restoreLock ?? BackupRestoreLock();

  final BackupRestoreLock _restoreLock;

  /// The IPTV store keys a backup carries: what the user set up. The
  /// channels, guide channels, programmes and line health are fetched
  /// from those and rebuilt by a refresh.
  static const List<String> iptvSetupKeys = [
    IptvKeys.playlists,
    IptvKeys.groups,
    IptvKeys.guideSources,
    IptvKeys.guideMappings,
  ];

  /// The followed rooms.
  final FollowRepository follows;

  /// The watch history.
  final HistoryRepository history;

  /// The followed areas.
  final AreaFollowRepository areaFollows;

  /// The recorder's tasks.
  final RecordingTaskRepository recordings;

  /// The IPTV library's store; null when it did not open.
  final JsonStore? iptv;

  /// The multiview store; null when it did not open.
  final JsonStore? multiview;

  /// The device vault; null when it never opened (an unsupported platform
  /// or a locked keychain), in which case the secrets section cannot be
  /// captured or restored and the picker does not offer it.
  final SecretStore? secrets;

  /// What the pane's summary shows: the entries per section as they are
  /// now.
  Map<BackupSection, int> summary() => {
    BackupSection.follows: follows.store.keys.length,
    BackupSection.history: history.store.keys.length,
    BackupSection.areaFollows: areaFollows.store.keys.length,
    BackupSection.recordings: recordings.store.keys.length,
    BackupSection.settings: captureSettingsSnapshot().length,
    BackupSection.iptv: _iptvEntries().values.fold(0, (sum, entry) => sum + ((entry['items'] as List?)?.length ?? 0)),
    BackupSection.multiview: multiview?.keys.length ?? 0,
    BackupSection.secrets: secrets?.refs.length ?? 0,
  };

  /// The IPTV setup as keyed entries: store key → `{items: [...]}`.
  Map<String, Map<String, Object?>> _iptvEntries() => {
    for (final MapEntry(:key, value: items) in _iptvItems().entries) key: {'items': items},
  };

  /// The IPTV setup's items now: setup key → its items.
  Map<String, List<Object?>> _iptvItems() {
    final store = iptv;
    if (store == null) return const {};
    final entries = store.entries;
    return {
      for (final key in iptvSetupKeys)
        if (entries[key] case final List<Object?> items) key: items,
    };
  }

  /// Bundles the selected [sections] into one document. A section not
  /// selected is absent from the document, which is what tells a restore
  /// to keep that box as it is. The secrets ride only when selected and
  /// the vault is open.
  BackupDocument capture({Set<BackupSection> sections = BackupSection.all}) {
    final vault = secrets;
    final present = {...sections};
    if (vault == null) present.remove(BackupSection.secrets);
    if (iptv == null) present.remove(BackupSection.iptv);
    if (multiview == null) present.remove(BackupSection.multiview);
    return BackupDocument(
      exportedAt: DateTime.now().toUtc(),
      follows: present.contains(BackupSection.follows) ? _entriesOf(follows.store) : const {},
      history: present.contains(BackupSection.history) ? _entriesOf(history.store) : const {},
      areaFollows: present.contains(BackupSection.areaFollows) ? _entriesOf(areaFollows.store) : const {},
      recordings: present.contains(BackupSection.recordings) ? _entriesOf(recordings.store) : const {},
      settings: present.contains(BackupSection.settings) ? captureSettingsSnapshot() : const {},
      iptv: present.contains(BackupSection.iptv) ? _iptvEntries() : const {},
      multiview: present.contains(BackupSection.multiview) && multiview != null ? _entriesOf(multiview!) : const {},
      secrets: present.contains(BackupSection.secrets) && vault != null
          ? {for (final ref in vault.refs) ref: vault.value(ref) ?? ''}
          : const {},
      presentSections: present,
    );
  }

  /// Restores [document]: every present section clears its store and takes
  /// the document's entries; the settings keys it carries are written
  /// back; the secrets it carries are set in the vault (refs it does not
  /// name stay). A section the document does not carry is left alone.
  ///
  /// One restore at a time: this holds the process's restore lock from the
  /// first check to the last write, and throws [BackupRestoreBusy] when
  /// another restore holds it. Throws [BackupRecordingsBusy] when a restore
  /// would clear the task store under a take this device is recording or
  /// still finishing, and [BackupDocumentEmpty] when the document carries
  /// nothing — no write happens in any of these cases.
  Future<void> apply(BackupDocument document) => _restoreLock.run(() async {
    if (document.isEmpty) throw const BackupDocumentEmpty();
    // The guard runs before the first write, so a refused restore leaves
    // every box exactly as it was rather than half-applying the document.
    if (document.hasRecordings && _hasLiveTake()) throw const BackupRecordingsBusy();
    // A section the document does not carry is left alone: an old export
    // that predates a store must not empty it. A section it does carry,
    // even empty, is the document's word on that data and replaces it.
    if (document.hasFollows) await _restore(follows.store, document.follows);
    if (document.hasAreas) await _restore(areaFollows.store, document.areaFollows);
    if (document.hasHistory) await _restore(history.store, document.history);
    if (document.hasRecordings) await _restoreRecordings(document.recordings);
    if (document.hasSettings) await applySettingsSnapshot(document.settings);
    if (document.hasIptv) await _restoreIptv(document.iptv);
    if (document.hasMultiview && multiview != null) await _restore(multiview!, document.multiview);
    if (document.hasSecrets) await _restoreSecrets(document.secrets);
  });

  /// What restoring [document] would change on this device, worked out by
  /// the rules [apply] writes by — the same tasks come back idle, the same
  /// IPTV keys are written, the same settings pass the same gate — so the
  /// confirm never promises what the restore will not do. Reads only.
  ///
  /// The keyed sections compare by identity (room, area and task keys, the
  /// IPTV items' ids, the multiview's rooms), the settings by value, and
  /// the credentials are counted as written. [followsOnlyFile] says the
  /// file was a follows-only backup; [document] may since have been
  /// narrowed to fewer sections.
  RestorePreview preview(BackupDocument document, {bool followsOnlyFile = false}) {
    var skipped = 0;
    for (final MapEntry(key: section, value: count) in document.skipped.entries) {
      if (_holds(section)) skipped += count;
    }
    final parts = <RestorePart>[
      if (document.hasFollows) RestorePart.compare(BackupSection.follows, follows.store.keys, document.follows.keys),
      if (document.hasAreas)
        RestorePart.compare(BackupSection.areaFollows, areaFollows.store.keys, document.areaFollows.keys),
      if (document.hasHistory) RestorePart.compare(BackupSection.history, history.store.keys, document.history.keys),
    ];
    if (document.hasRecordings) {
      final tasks = _restoredTasks(document.recordings);
      skipped += document.recordings.length - tasks.length;
      parts.add(RestorePart.compare(BackupSection.recordings, recordings.store.keys, tasks.keys));
    }
    var settings = (written: 0, changed: 0, skipped: 0);
    if (document.hasSettings) {
      settings = settingsSnapshotChanges(document.settings);
      skipped += settings.skipped;
    }
    if (document.hasIptv && iptv != null) {
      final now = _iptvItems();
      final written = _restorableIptv(document.iptv);
      skipped += document.iptv.keys.where(iptvSetupKeys.contains).length - written.length;
      // The keys the document does not carry keep their items.
      final after = {...now, ...written};
      parts.add(RestorePart.compare(BackupSection.iptv, iptvItemIdentities(now), iptvItemIdentities(after)));
    }
    final board = multiview;
    if (document.hasMultiview && board != null) {
      parts.add(
        RestorePart.compare(BackupSection.multiview, multiviewRooms(board.entries), multiviewRooms(document.multiview)),
      );
    }
    return RestorePreview(
      parts: parts,
      kept: [
        for (final section in BackupSection.values)
          if (!document.presentSections.contains(section) && _holds(section)) section,
      ],
      followsOnlyFile: followsOnlyFile,
      settingsInFile: settings.written,
      settingsChanged: settings.changed,
      accounts: document.hasSecrets && secrets != null
          ? document.secrets.values.where((value) => value.isNotEmpty).length
          : 0,
      skipped: skipped,
    );
  }

  /// Whether this device has a box for [section] at all: the IPTV and
  /// multiview stores and the vault may not have opened.
  bool _holds(BackupSection section) => switch (section) {
    BackupSection.iptv => iptv != null,
    BackupSection.multiview => multiview != null,
    BackupSection.secrets => secrets != null,
    BackupSection.follows ||
    BackupSection.areaFollows ||
    BackupSection.history ||
    BackupSection.recordings ||
    BackupSection.settings => true,
  };

  /// Writes the setup keys the document carries; the keys it does not
  /// name, and the fetched channels and programmes, stay as they are.
  Future<void> _restoreIptv(Map<String, Map<String, Object?>> entries) async {
    final store = iptv;
    if (store == null) return;
    for (final MapEntry(:key, value: items) in _restorableIptv(entries).entries) {
      await store.put(key, items);
    }
    await store.flush();
  }

  /// The setup keys [entries] carries with a list of items — what a restore
  /// writes. A key whose items are not a list is skipped; keys outside the
  /// setup are never written.
  static Map<String, List<Object?>> _restorableIptv(Map<String, Map<String, Object?>> entries) => {
    for (final key in iptvSetupKeys)
      if (entries[key]?['items'] case final List<Object?> items) key: items,
  };

  /// Whether this device has a take the engine still owns: a session
  /// capturing, or a finished one whose join, transcode and rename are
  /// still running. Both write their task entry by id, which a cleared
  /// store would leave them writing to nothing.
  bool _hasLiveTake() => recordings.list().any((task) => task.isRunning || task.postProcessing);

  /// Clears the task store and writes [entries] back as idle tasks.
  Future<void> _restoreRecordings(Map<String, Map<String, Object?>> entries) async {
    final tasks = _restoredTasks(entries);
    await recordings.store.clear();
    await recordings.store.putAll(tasks);
    await recordings.store.flush();
  }

  /// The tasks a restore writes for [entries], each one idle, by id.
  ///
  /// A document is a record of what the user set up, not of what a machine
  /// was doing: no session runs behind a restored task, so a take that was
  /// recording becomes a waiting one (the live check starts it when the
  /// room goes live), and a half-finished post-processing flag, its
  /// progress and the warning codes that came with it are dropped. The
  /// facts a take left behind — its file, size, length and error — are kept
  /// as the document tells them.
  static Map<String, Map<String, Object?>> _restoredTasks(Map<String, Map<String, Object?>> entries) {
    final tasks = <String, Map<String, Object?>>{};
    for (final entry in entries.entries) {
      final task = RecordingTask.fromJson(entry.value);
      // An entry without a room cannot be recorded or listed usefully; a
      // newer writer's odd shape reads as an empty task and is skipped.
      if (task.platform.isEmpty || task.roomId.isEmpty) continue;
      final idle = task.copyWith(
        id: entry.key,
        state: task.isRunning ? RecordingTaskState.waiting : task.state,
        postProcessing: false,
        postProcessingProgress: -1,
        warning: '',
      );
      tasks[entry.key] = idle.toJson();
    }
    return tasks;
  }

  /// Sets every secret the document names. Secrets it does not name are
  /// kept: a backup from another device must not log this one out of the
  /// platforms it never knew about. An empty value removes the ref.
  Future<void> _restoreSecrets(Map<String, String> entries) async {
    final vault = secrets;
    if (vault == null) return;
    for (final entry in entries.entries) {
      if (entry.value.isEmpty) {
        await vault.remove(entry.key);
      } else {
        await vault.set(entry.key, entry.value);
      }
    }
  }

  /// Clears [store] and writes [entries] back, key for key, then flushes —
  /// a restore is whole or nothing per section.
  Future<void> _restore(JsonStore store, Map<String, Map<String, Object?>> entries) async {
    await store.clear();
    await store.putAll(<String, Object?>{for (final entry in entries.entries) entry.key: entry.value});
    await store.flush();
  }

  /// The store's entries as the JSON maps the document stores.
  static Map<String, Map<String, Object?>> _entriesOf(JsonStore store) => {
    for (final entry in store.entries.entries) entry.key: _jsonOf(entry.value),
  };

  static Map<String, Object?> _jsonOf(Object? value) =>
      value is Map<String, Object?> ? value : Map<String, Object?>.from(value! as Map);
}

/// The process's one restore lock, which [backupRepositoryProvider] hands
/// every repository it builds and the restore entries ask before they
/// start. Its own provider rather than the repository's field: the
/// repository is rebuilt when a store it reads reopens, and a lock that
/// went with it would let a second restore start under the first.
final backupRestoreLockProvider = Provider<BackupRestoreLock>((ref) => BackupRestoreLock());

/// The backup repository (the four user-data namespaces, the vault when
/// it opens, one process).
final backupRepositoryProvider = FutureProvider<BackupRepository>((ref) async {
  final restoreLock = ref.watch(backupRestoreLockProvider);
  final follows = await ref.watch(followRepositoryProvider.future);
  final history = await ref.watch(historyRepositoryProvider.future);
  final areaFollows = await ref.watch(areaFollowRepositoryProvider.future);
  final recordings = await ref.watch(recordingRepositoryProvider.future);
  JsonStore? iptv;
  JsonStore? multiview;
  try {
    iptv = await StorageStores.instance.openStore(IptvKeys.table);
    multiview = (await ref.watch(multiviewRepositoryProvider.future)).store;
  } on Object {
    // A store that did not open is simply not offered.
  }
  SecretStore? secrets;
  try {
    secrets = await ref.watch(appSecretStoreProvider.future);
  } on Object {
    // No vault on this platform: the secrets section is simply not offered.
  }
  return BackupRepository(
    follows: follows,
    history: history,
    areaFollows: areaFollows,
    recordings: recordings,
    iptv: iptv,
    multiview: multiview,
    secrets: secrets,
    restoreLock: restoreLock,
  );
});

/// What the stores, the settings subset and the vault hold right now, per
/// section, for the pane's summary row and the picker's counts.
///
/// Derived, not a `FutureProvider`: once the repository is up, a
/// `FutureProvider` awaiting its `.future` would complete synchronously on
/// its next (re)build — and a rebuild forced by a restore's `invalidate`
/// then lands inside a widget build, which Riverpod refuses ("tried to
/// modify a provider while the widget tree was building").
final backupSummaryProvider = Provider<AsyncValue<Map<BackupSection, int>>>(
  (ref) => ref.watch(backupRepositoryProvider).whenData((repository) => repository.summary()),
);
