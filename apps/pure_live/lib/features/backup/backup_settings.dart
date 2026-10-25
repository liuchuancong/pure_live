import 'package:live_storage/live_storage.dart';

/// The settings subset the backup document carries: the simple prefs a
/// restore writes back through `StoragePrefs`' typed setters.
///
/// The list is the current keys at the time of writing; a new surface that
/// adds a pref adds it here and every older backup keeps restoring (the
/// document's `settings` section is read per key, absent keys stay
/// untouched). The danmaku shield, playback, IPTV, recording, follow tags
/// and per-room orientation all carry their prefs here.
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
///
/// The list is the current prefs at the time of writing. A key that later
/// disappears is harmless — capture simply finds no value; a new surface
/// adds its pref here so its first backup carries it. Restoring only ever
/// writes keys the document carries, so an older backup never resets a
/// newer pref.
const List<BackupPrefEntry> kBackedUpPrefs = [
  // Browsing: which site each surface opens on, which module leads, the
  // grid's card/page measure, the tools' order, the search history.
  ('browse.site', BackupPrefKind.string),
  ('browse.module', BackupPrefKind.string),
  ('browse.popular.site', BackupPrefKind.string),
  ('browse.areas.site', BackupPrefKind.string),
  ('browse.search.site', BackupPrefKind.string),
  ('browse.layout', BackupPrefKind.string),
  ('browse.pageSize', BackupPrefKind.integer),
  ('browse.cardExtent', BackupPrefKind.floating),
  ('browse.crossSpacing', BackupPrefKind.floating),
  ('browse.mainSpacing', BackupPrefKind.floating),
  ('browse.audienceMetric', BackupPrefKind.string),
  ('nav.multiview', BackupPrefKind.boolean),
  ('tools.order', BackupPrefKind.stringList),
  ('shell.closeAction', BackupPrefKind.string),
  ('search.history', BackupPrefKind.stringList),
  // The platform display and its order/preference.
  ('sites.display', BackupPrefKind.stringList),
  ('sites.display.order', BackupPrefKind.stringList),
  ('sites.display.preferred', BackupPrefKind.string),
  // Follows refresh and the history cap.
  ('refresh.follows.auto', BackupPrefKind.boolean),
  ('refresh.follows.minutes', BackupPrefKind.integer),
  ('history.limit', BackupPrefKind.integer),
  // Appearance.
  ('theme.mode', BackupPrefKind.string),
  ('theme.seed', BackupPrefKind.string),
  ('theme.corners', BackupPrefKind.string),
  ('theme.density', BackupPrefKind.string),
  ('theme.contrast', BackupPrefKind.string),
  ('theme.selection', BackupPrefKind.string),
  ('theme.autoClash', BackupPrefKind.string),
  ('theme.font', BackupPrefKind.string),
  ('app.locale', BackupPrefKind.string),
  // The wallpaper: its kind and every source it can hold.
  ('background.kind', BackupPrefKind.string),
  ('background.imageUrl', BackupPrefKind.string),
  ('background.imagePath', BackupPrefKind.string),
  ('background.videoUrl', BackupPrefKind.string),
  ('background.videoPath', BackupPrefKind.string),
  ('background.solid', BackupPrefKind.string),
  ('background.gradient', BackupPrefKind.string),
  ('background.fit', BackupPrefKind.string),
  ('background.mask', BackupPrefKind.floating),
  ('background.blur', BackupPrefKind.floating),
  // Playback and the flying layer's own look.
  ('playback.quality', BackupPrefKind.string),
  ('playback.muted', BackupPrefKind.boolean),
  ('playback.volume', BackupPrefKind.floating),
  ('playback.fit', BackupPrefKind.string),
  ('playback.danmaku', BackupPrefKind.boolean),
  ('playback.miniDanmaku', BackupPrefKind.boolean),
  ('playback.hwdec', BackupPrefKind.boolean),
  ('playback.autoPip', BackupPrefKind.boolean),
  ('danmaku.style.fontSize', BackupPrefKind.floating),
  ('danmaku.style.baseSpeed', BackupPrefKind.floating),
  ('danmaku.style.area', BackupPrefKind.floating),
  ('danmaku.style.opacity', BackupPrefKind.floating),
  ('danmaku.style.showStroke', BackupPrefKind.boolean),
  // The network and the danmaku shield.
  ('proxy.enabled', BackupPrefKind.boolean),
  ('proxy.host', BackupPrefKind.string),
  ('proxy.port', BackupPrefKind.integer),
  ('danmaku.block.enabled', BackupPrefKind.boolean),
  ('danmaku.block.users', BackupPrefKind.stringList),
  ('danmaku.block.keywords', BackupPrefKind.stringList),
  // The image cache's cap.
  ('cache.maxMB', BackupPrefKind.integer),
  // IPTV: the schedule, the active guide and the source order.
  ('iptv.update.hours', BackupPrefKind.integer),
  ('iptv.guide.active', BackupPrefKind.string),
  ('iptv.sources.order', BackupPrefKind.stringList),
  // The recorder's 15 tunables (and the old gigabyte cap for upgrades).
  ('recorder.dir', BackupPrefKind.string),
  ('recorder.naming', BackupPrefKind.string),
  ('recorder.maxSizeMb', BackupPrefKind.integer),
  ('recorder.maxSizeGb', BackupPrefKind.floating),
  ('recorder.segment', BackupPrefKind.integer),
  ('recorder.rwTimeout', BackupPrefKind.integer),
  ('recorder.queue', BackupPrefKind.integer),
  ('recorder.preferBest', BackupPrefKind.boolean),
  ('recorder.keepAlive', BackupPrefKind.boolean),
  ('recorder.verify', BackupPrefKind.boolean),
  ('recorder.restartLimit', BackupPrefKind.integer),
  ('recorder.restartBackoff', BackupPrefKind.integer),
  ('recorder.stallTimeout', BackupPrefKind.integer),
  ('recorder.diskWatermark', BackupPrefKind.integer),
  ('recorder.maxTasks', BackupPrefKind.integer),
  ('recorder.container', BackupPrefKind.string),
  // Local follow tags and per-room picture orientation.
  ('follow.tags', BackupPrefKind.string),
  ('room.orientation', BackupPrefKind.string),
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
