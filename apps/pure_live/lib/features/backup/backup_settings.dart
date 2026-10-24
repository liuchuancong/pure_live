import 'package:live_storage/live_storage.dart';

/// The settings subset the backup document carries: the simple prefs a
/// restore writes back through `StoragePrefs`' typed setters.
///
/// The list is the known keys at the time of writing; a new surface that
/// adds a pref adds it here and every older backup keeps restoring (the
/// document's `settings` section is read per key, absent keys stay
/// untouched). The `danmaku.block.*` pair is what the danmaku filter will
/// persist when its settings UI arrives with the player stack
/// (`DanmakuFilterPolicy`'s blocked users and keywords); nothing writes
/// them yet, and the backup handles them defensively — absent means
/// skipped.
enum BackupPrefKind {
  /// A string value.
  string,

  /// A boolean value.
  boolean,

  /// An integer value.
  integer,

  /// A floating-point value.
  floating,

  /// A list of strings.
  stringList,
}

/// One backed-up pref: its key and the kind its reader and writer speak.
typedef BackupPrefEntry = (String key, BackupPrefKind kind);

/// The backed-up keys, grouped as the settings surface presents them.
const List<BackupPrefEntry> kBackedUpPrefs = [
  // Browsing: which site each surface opens on, which module leads.
  ('browse.site', BackupPrefKind.string),
  ('browse.module', BackupPrefKind.string),
  ('browse.popular.site', BackupPrefKind.string),
  ('browse.areas.site', BackupPrefKind.string),
  ('browse.search.site', BackupPrefKind.string),
  ('sites.display', BackupPrefKind.stringList),
  // The follows page's auto refresh and the history's cap.
  ('refresh.follows.auto', BackupPrefKind.boolean),
  ('refresh.follows.minutes', BackupPrefKind.integer),
  ('history.limit', BackupPrefKind.integer),
  // Appearance.
  ('theme.mode', BackupPrefKind.string),
  ('theme.seed', BackupPrefKind.string),
  ('theme.corners', BackupPrefKind.string),
  ('theme.density', BackupPrefKind.string),
  ('app.locale', BackupPrefKind.string),
  // IPTV guide source and the recorder's tunables.
  ('iptv.epg.url', BackupPrefKind.string),
  ('recorder.dir', BackupPrefKind.string),
  ('recorder.naming', BackupPrefKind.string),
  ('recorder.maxSizeGb', BackupPrefKind.floating),
  // The danmaku filter's block lists (written once its UI arrives).
  ('danmaku.block.users', BackupPrefKind.stringList),
  ('danmaku.block.keywords', BackupPrefKind.stringList),
];

/// Reads every backed-up pref that currently has a value.
///
/// A closed store answers an empty snapshot — capture runs where a
/// failure means "back up the boxes only", not "the export fails".
Map<String, Object?> captureSettingsSnapshot() {
  final snapshot = <String, Object?>{};
  for (final (key, kind) in kBackedUpPrefs) {
    try {
      final value = switch (kind) {
        BackupPrefKind.string => StoragePrefs.getString(key),
        BackupPrefKind.boolean => StoragePrefs.getBool(key),
        BackupPrefKind.integer => StoragePrefs.getInt(key),
        BackupPrefKind.floating => StoragePrefs.getDouble(key),
        BackupPrefKind.stringList => StoragePrefs.getStringList(key),
      };
      if (value != null) snapshot[key] = value;
    } on Object {
      // One unreadable key loses itself; the rest still go in.
    }
  }
  return snapshot;
}

/// Writes [snapshot]'s known keys back through the typed setters.
///
/// Keys the snapshot does not carry stay as they are (an older backup
/// must not reset a newer app's new prefs); a value of the wrong shape is
/// skipped. A closed store loses the restore, like every pref write.
Future<void> applySettingsSnapshot(Map<String, Object?> snapshot) async {
  for (final (key, kind) in kBackedUpPrefs) {
    final value = snapshot[key];
    if (value == null) continue;
    try {
      switch (kind) {
        case BackupPrefKind.string:
          if (value is String) await StoragePrefs.setString(key, value);
        case BackupPrefKind.boolean:
          if (value is bool) await StoragePrefs.setBool(key, value);
        case BackupPrefKind.integer:
          if (value is int) await StoragePrefs.setInt(key, value);
        case BackupPrefKind.floating:
          if (value is num) await StoragePrefs.setDouble(key, value.toDouble());
        case BackupPrefKind.stringList:
          if (value is List && value.every((entry) => entry is String)) {
            await StoragePrefs.setStringList(key, List<String>.from(value));
          }
      }
    } on Object {
      // One unwritable key loses itself; the rest still land.
    }
  }
}
