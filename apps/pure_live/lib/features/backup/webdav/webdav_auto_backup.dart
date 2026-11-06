import 'dart:convert' show jsonEncode;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/webdav/webdav_accounts.dart' show WebDavAccount;
import 'package:pure_live/features/backup/webdav/webdav_client.dart' show WebDavEntry;

// The scheduled WebDAV backup's own vocabulary: what the user chose (the
// settings), what the last runs left behind (the meta), the file names the
// uploads take, and the pure rules that decide when a run is due and which
// old files go. Nothing here touches the network; the scheduler does.

/// The pref key of the switch.
const String kWebDavAutoEnabledPref = 'backup.webdav.auto.enabled';

/// The pref key of the hours between two uploads.
const String kWebDavAutoHoursPref = 'backup.webdav.auto.hours';

/// The pref key of the scope: `all` or `follows`.
const String kWebDavAutoScopePref = 'backup.webdav.auto.scope';

/// The pref key of the remote folder, relative to the account's root.
const String kWebDavAutoFolderPref = 'backup.webdav.auto.folder';

/// The pref key of how many automatic files the folder keeps.
const String kWebDavAutoKeepPref = 'backup.webdav.auto.keep';

/// The pref key of whether the vault's secrets ride along.
const String kWebDavAutoIncludeSecretsPref = 'backup.webdav.auto.includeSecrets';

/// The pref key of the last successful upload (ISO 8601, UTC).
const String kWebDavAutoLastSuccessPref = 'backup.webdav.auto.lastSuccess';

/// The pref key of the last attempt, successful or not (ISO 8601, UTC).
const String kWebDavAutoLastAttemptPref = 'backup.webdav.auto.lastAttempt';

/// The pref key of the failures in a row since the last success.
const String kWebDavAutoFailuresPref = 'backup.webdav.auto.failures';

/// The pref key of the target fingerprint the last success went to.
const String kWebDavAutoLastTargetPref = 'backup.webdav.auto.lastTarget';

/// What an automatic backup carries: everything (but the secrets unless the
/// switch says so), or the follows alone.
enum WebDavAutoBackupScope {
  /// Every section.
  all('all'),

  /// Followed rooms and areas only.
  follows('follows');

  WebDavAutoBackupScope(this.id);

  /// The stored id.
  final String id;

  /// The scope with the stored id [value]; an unknown one reads as [all].
  static WebDavAutoBackupScope of(String? value) => value == follows.id ? follows : all;

  /// The sections this scope captures. The secrets join only on [all] and
  /// only when [includeSecrets] asks for them; the repository drops them
  /// again when the vault never opened.
  Set<BackupSection> sections({required bool includeSecrets}) => switch (this) {
    all => includeSecrets ? {...BackupSection.all, BackupSection.secrets} : BackupSection.all,
    follows => BackupSection.followsOnly,
  };
}

/// The automatic WebDAV backup's settings: the switch, the schedule, the
/// contents, the remote folder and how many files it keeps.
///
/// The folder is a relative path below the selected account's root, typed
/// by the user and checked by [parseWebDavAutoFolder] before any upload.
/// It is independent of the folder the file manager page is browsing.
@immutable
final class WebDavAutoBackupSettings {
  /// Creates the settings.
  const WebDavAutoBackupSettings({
    this.enabled = false,
    this.hours = defaultHours,
    this.scope = WebDavAutoBackupScope.all,
    this.folder = defaultFolder,
    this.keep = defaultKeep,
    this.includeSecrets = false,
  });

  /// The hours between two uploads unless the user chose otherwise.
  static const int defaultHours = 24;

  /// The remote folder unless the user chose otherwise.
  static const String defaultFolder = 'pure_live';

  /// How many automatic files the folder keeps unless the user chose
  /// otherwise.
  static const int defaultKeep = 7;

  /// The intervals the pane offers, in hours.
  static const List<int> hourChoices = [1, 6, 12, 24, 48, 72, 168];

  /// The retention counts the pane offers.
  static const List<int> keepChoices = [1, 3, 7, 15, 30];

  /// The smallest and largest interval a stored value is clamped to.
  static const int minHours = 1;

  /// See [minHours].
  static const int maxHours = 168;

  /// The smallest and largest retention a stored value is clamped to.
  static const int minKeep = 1;

  /// See [minKeep].
  static const int maxKeep = 100;

  /// Whether uploads happen at all.
  final bool enabled;

  /// Hours between two uploads.
  final int hours;

  /// What the upload carries.
  final WebDavAutoBackupScope scope;

  /// The remote folder, as typed; see [parseWebDavAutoFolder].
  final String folder;

  /// How many automatic files the folder keeps, newest first.
  final int keep;

  /// Whether the vault's secrets ride along on a full backup. The hub's own
  /// `backup.includeSecrets` switch still has the last word: off there, no
  /// upload carries them whatever this says.
  final bool includeSecrets;

  /// The interval as a duration.
  Duration get interval => Duration(hours: hours);

  /// A copy with the named fields replaced.
  WebDavAutoBackupSettings copyWith({
    bool? enabled,
    int? hours,
    WebDavAutoBackupScope? scope,
    String? folder,
    int? keep,
    bool? includeSecrets,
  }) => WebDavAutoBackupSettings(
    enabled: enabled ?? this.enabled,
    hours: hours ?? this.hours,
    scope: scope ?? this.scope,
    folder: folder ?? this.folder,
    keep: keep ?? this.keep,
    includeSecrets: includeSecrets ?? this.includeSecrets,
  );

  @override
  bool operator ==(Object other) =>
      other is WebDavAutoBackupSettings &&
      other.enabled == enabled &&
      other.hours == hours &&
      other.scope == scope &&
      other.folder == folder &&
      other.keep == keep &&
      other.includeSecrets == includeSecrets;

  @override
  int get hashCode => Object.hash(enabled, hours, scope, folder, keep, includeSecrets);
}

/// Owns the automatic backup's settings: read once from the prefs, written
/// through on every change so the scheduler and the pane never disagree.
final class WebDavAutoBackupSettingsController extends Notifier<WebDavAutoBackupSettings> {
  @override
  WebDavAutoBackupSettings build() {
    try {
      return WebDavAutoBackupSettings(
        enabled: StoragePrefs.getBool(kWebDavAutoEnabledPref) ?? false,
        hours: _clamp(
          StoragePrefs.getInt(kWebDavAutoHoursPref),
          WebDavAutoBackupSettings.defaultHours,
          WebDavAutoBackupSettings.minHours,
          WebDavAutoBackupSettings.maxHours,
        ),
        scope: WebDavAutoBackupScope.of(StoragePrefs.getString(kWebDavAutoScopePref)),
        folder: StoragePrefs.getString(kWebDavAutoFolderPref) ?? WebDavAutoBackupSettings.defaultFolder,
        keep: _clamp(
          StoragePrefs.getInt(kWebDavAutoKeepPref),
          WebDavAutoBackupSettings.defaultKeep,
          WebDavAutoBackupSettings.minKeep,
          WebDavAutoBackupSettings.maxKeep,
        ),
        includeSecrets: StoragePrefs.getBool(kWebDavAutoIncludeSecretsPref) ?? false,
      );
    } on Object {
      // A closed store answers the defaults.
      return const WebDavAutoBackupSettings();
    }
  }

  /// Turns the schedule on or off.
  Future<void> setEnabled({required bool enabled}) => _write(state.copyWith(enabled: enabled));

  /// Sets the hours between two uploads, clamped to the allowed range.
  Future<void> setHours(int hours) => _write(
    state.copyWith(hours: hours.clamp(WebDavAutoBackupSettings.minHours, WebDavAutoBackupSettings.maxHours)),
  );

  /// Sets what the upload carries.
  Future<void> setScope(WebDavAutoBackupScope scope) => _write(state.copyWith(scope: scope));

  /// Sets the remote folder. Answers false and keeps the old value when
  /// [folder] is not a safe relative path; the pane shows the message.
  Future<bool> setFolder(String folder) async {
    final segments = parseWebDavAutoFolder(folder);
    if (segments == null) return false;
    await _write(state.copyWith(folder: segments.join('/')));
    return true;
  }

  /// Sets how many automatic files the folder keeps, clamped.
  Future<void> setKeep(int keep) =>
      _write(state.copyWith(keep: keep.clamp(WebDavAutoBackupSettings.minKeep, WebDavAutoBackupSettings.maxKeep)));

  /// Sets whether the secrets ride along.
  Future<void> setIncludeSecrets({required bool include}) => _write(state.copyWith(includeSecrets: include));

  Future<void> _write(WebDavAutoBackupSettings next) async {
    state = next;
    try {
      await StoragePrefs.setPrefs({
        kWebDavAutoEnabledPref: next.enabled,
        kWebDavAutoHoursPref: next.hours,
        kWebDavAutoScopePref: next.scope.id,
        kWebDavAutoFolderPref: next.folder,
        kWebDavAutoKeepPref: next.keep,
        kWebDavAutoIncludeSecretsPref: next.includeSecrets,
      });
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  static int _clamp(int? value, int fallback, int min, int max) => (value ?? fallback).clamp(min, max);
}

/// The automatic WebDAV backup's settings.
final webdavAutoBackupSettingsProvider =
    NotifierProvider<WebDavAutoBackupSettingsController, WebDavAutoBackupSettings>(
      WebDavAutoBackupSettingsController.new,
    );

/// What the last runs left behind: when the last upload landed, when the
/// last attempt was made, how many failed in a row since, and the target
/// fingerprint the last success went to.
///
/// Device-local by nature — the record of what *this* machine sent — so the
/// four prefs stay out of the backup document.
@immutable
final class WebDavAutoBackupMeta {
  /// Creates the record.
  const WebDavAutoBackupMeta({this.lastSuccess, this.lastAttempt, this.failures = 0, this.target});

  /// The record as the prefs hold it.
  factory WebDavAutoBackupMeta.stored() {
    DateTime? time(String? value) => value == null ? null : DateTime.tryParse(value)?.toUtc();
    try {
      return WebDavAutoBackupMeta(
        lastSuccess: time(StoragePrefs.getString(kWebDavAutoLastSuccessPref)),
        lastAttempt: time(StoragePrefs.getString(kWebDavAutoLastAttemptPref)),
        failures: StoragePrefs.getInt(kWebDavAutoFailuresPref) ?? 0,
        target: StoragePrefs.getString(kWebDavAutoLastTargetPref),
      );
    } on Object {
      return none;
    }
  }

  /// The record before any run.
  static const WebDavAutoBackupMeta none = WebDavAutoBackupMeta();

  /// The last successful upload (UTC).
  final DateTime? lastSuccess;

  /// The last attempt, successful or not (UTC).
  final DateTime? lastAttempt;

  /// Failed attempts since the last success.
  final int failures;

  /// The fingerprint ([webDavAutoBackupTarget]) of [lastSuccess]'s target.
  final String? target;

  /// A copy with the named fields replaced.
  WebDavAutoBackupMeta copyWith({DateTime? lastSuccess, DateTime? lastAttempt, int? failures, String? target}) =>
      WebDavAutoBackupMeta(
        lastSuccess: lastSuccess ?? this.lastSuccess,
        lastAttempt: lastAttempt ?? this.lastAttempt,
        failures: failures ?? this.failures,
        target: target ?? this.target,
      );

  /// Writes the record.
  Future<void> write() async {
    String? iso(DateTime? moment) => moment?.toUtc().toIso8601String();
    final values = <String, Object>{kWebDavAutoFailuresPref: failures};
    final success = iso(lastSuccess);
    if (success != null) values[kWebDavAutoLastSuccessPref] = success;
    final attempt = iso(lastAttempt);
    if (attempt != null) values[kWebDavAutoLastAttemptPref] = attempt;
    final storedTarget = target;
    if (storedTarget != null) values[kWebDavAutoLastTargetPref] = storedTarget;
    try {
      await StoragePrefs.setPrefs(values);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  @override
  bool operator ==(Object other) =>
      other is WebDavAutoBackupMeta &&
      other.lastSuccess == lastSuccess &&
      other.lastAttempt == lastAttempt &&
      other.failures == failures &&
      other.target == target;

  @override
  int get hashCode => Object.hash(lastSuccess, lastAttempt, failures, target);
}

/// Owns the meta record in memory so the pane's status rows follow a run as
/// it lands; the scheduler writes through here.
final class WebDavAutoBackupMetaController extends Notifier<WebDavAutoBackupMeta> {
  @override
  WebDavAutoBackupMeta build() => WebDavAutoBackupMeta.stored();

  /// Records a successful upload to [target] at [now].
  Future<void> recordSuccess({required DateTime now, required String target}) =>
      _write(WebDavAutoBackupMeta(lastSuccess: now.toUtc(), lastAttempt: now.toUtc(), target: target));

  /// Records a failed attempt at [now]; the last success stays.
  Future<void> recordFailure({required DateTime now}) =>
      _write(state.copyWith(lastAttempt: now.toUtc(), failures: state.failures + 1));

  Future<void> _write(WebDavAutoBackupMeta next) async {
    state = next;
    await next.write();
  }
}

/// The automatic WebDAV backup's run record.
final webdavAutoBackupMetaProvider = NotifierProvider<WebDavAutoBackupMetaController, WebDavAutoBackupMeta>(
  WebDavAutoBackupMetaController.new,
);

/// Splits a typed remote folder into path segments; null when it is not a
/// safe relative path (empty, `.`, `..`, a backslash, a control character).
List<String>? parseWebDavAutoFolder(String value) {
  final text = value.trim();
  if (text.isEmpty || RegExp(r'[\x00-\x1f\x7f\\]').hasMatch(text)) return null;
  final segments = [
    for (final segment in text.split('/'))
      if (segment.trim().isNotEmpty) segment.trim(),
  ];
  if (segments.isEmpty || segments.any((segment) => segment == '.' || segment == '..')) return null;
  return segments;
}

/// The fingerprint of where and what an upload goes to: the account, the
/// folder and the contents. A changed fingerprint makes the next check due
/// at once — a new server or a wider scope should not wait a day for its
/// first copy.
String webDavAutoBackupTarget({
  required WebDavAccount account,
  required List<String> folder,
  required WebDavAutoBackupScope scope,
  required bool includeSecrets,
}) => jsonEncode({
  'account': account.id,
  'url': account.url,
  'user': account.user,
  'folder': folder.join('/'),
  'scope': scope.id,
  'secrets': scope == WebDavAutoBackupScope.all && includeSecrets,
});

/// The name of a scheduled upload: the manual export's name with `auto`
/// before the stamp, so the manual `pure_live_backup_…` and
/// `pure_live_follows_…` files never match the retention pattern.
String webDavAutoBackupFileName(DateTime localNow, {required bool followsOnly}) {
  final manual = BackupDocument.exportFileName(localNow, followsOnly: followsOnly);
  final kind = followsOnly ? 'follows' : 'backup';
  return manual.replaceFirst('pure_live_${kind}_', 'pure_live_${kind}_auto_');
}

/// Matches the files [webDavAutoBackupFileName] writes; a manual file or a
/// renamed one does not match.
final RegExp _autoBackupName = RegExp(
  r'^pure_live_(?:backup|follows)_auto_(\d{8}_\d{6})\.json$',
  caseSensitive: false,
);

/// Whether [name] is a scheduled upload's file.
bool isWebDavAutoBackupFile(String name) => webDavAutoBackupTimeKey(name) != null;

/// The stamp of a scheduled upload's file, sortable as text; null for any
/// other name.
String? webDavAutoBackupTimeKey(String name) => _autoBackupName.firstMatch(name)?.group(1);

/// The timing rules, pure so they can be read and tested on their own.
abstract final class WebDavAutoBackupRules {
  /// The waits after one, two, three … failures in a row; the last repeats.
  static const List<Duration> backoffSteps = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
    Duration(hours: 6),
  ];

  /// How long [failures] failures in a row hold the next try off: one of
  /// [backoffSteps], never longer than [interval] itself.
  static Duration backoff(int failures, Duration interval) {
    if (failures <= 0) return Duration.zero;
    final delay = backoffSteps[math.min(failures - 1, backoffSteps.length - 1)];
    return delay < interval ? delay : interval;
  }

  /// Whether a run is due at [now] for [target] under [interval], given
  /// [meta].
  ///
  /// A changed target is due at once; a target never uploaded is due at
  /// once; otherwise [interval] after the last success. Failures in a row
  /// push the earliest try back by [backoff] from the last attempt, which
  /// also holds a changed target off for that long — a server that just
  /// refused us is not retried on the next tick because a setting moved.
  static bool isDue({
    required DateTime now,
    required Duration interval,
    required String target,
    required WebDavAutoBackupMeta meta,
  }) {
    DateTime? retry;
    if (meta.failures > 0 && meta.lastAttempt != null) {
      retry = meta.lastAttempt!.add(backoff(meta.failures, interval));
    }
    if (meta.target != target) return retry == null || !now.isBefore(retry);
    final success = meta.lastSuccess;
    if (success == null) return retry == null || !now.isBefore(retry);
    var due = success.add(interval);
    if (retry != null && retry.isAfter(due)) due = retry;
    return !now.isBefore(due);
  }

  /// When the next run is due at the earliest, for the pane's status row;
  /// null when it is due now or was never set up. The same rule as [isDue],
  /// answered as a moment.
  static DateTime? nextDue({required DateTime now, required Duration interval, required WebDavAutoBackupMeta meta}) {
    final success = meta.lastSuccess;
    DateTime? retry;
    if (meta.failures > 0 && meta.lastAttempt != null) {
      retry = meta.lastAttempt!.add(backoff(meta.failures, interval));
    }
    var due = success?.add(interval) ?? retry;
    if (due == null) return null;
    if (retry != null && retry.isAfter(due)) due = retry;
    return now.isBefore(due) ? due : null;
  }

  /// The files retention deletes: the automatic files among [entries] that
  /// sit directly in [folder] (the root-relative path, `/a/b`), beyond the
  /// newest [keep] by stamp. Folders, manual files and anything a malformed
  /// listing reported from another depth are never named.
  static List<WebDavEntry> prune(List<WebDavEntry> entries, {required String folder, required int keep}) {
    final prefix = folder == '/' ? '/' : '$folder/';
    final files =
        [
          for (final entry in entries)
            if (!entry.isDirectory &&
                entry.path.startsWith(prefix) &&
                !entry.path.substring(prefix.length).contains('/') &&
                isWebDavAutoBackupFile(entry.name))
              entry,
        ]..sort((a, b) {
          final time = webDavAutoBackupTimeKey(b.name)!.compareTo(webDavAutoBackupTimeKey(a.name)!);
          return time == 0 ? b.name.compareTo(a.name) : time;
        });
    return files.skip(math.max(keep, 0)).toList();
  }
}
