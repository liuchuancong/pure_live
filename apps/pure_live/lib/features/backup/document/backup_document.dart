import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/foundation.dart' show setEquals;

/// One section of a backup document: a box of user data the codec knows
/// how to carry. A selection of sections is what every transport asks the
/// user for — a local file, a WebDAV upload, the cloud, a LAN peer — so the
/// same picker and the same document serve all of them.
enum BackupSection {
  /// The followed rooms.
  follows('follows'),

  /// The followed areas.
  areaFollows('areaFollows'),

  /// The watch history.
  history('history'),

  /// The recording tasks.
  recordings('recordings'),

  /// The named subset of the simple settings.
  settings('settings'),

  /// The IPTV library's setup: playlists, groups, guide sources and
  /// channel mappings. The channels and programmes they fetch are not
  /// carried — a refresh rebuilds them.
  iptv('iptv'),

  /// The multiview layout: which rooms sit in which slots.
  multiview('multiview'),

  /// The vault's secrets: platform cookies, WebDAV passwords. Off the
  /// default selection, and only offered at all when the user turned
  /// `backup.includeSecrets` on.
  secrets('secrets');

  BackupSection(this.key);

  /// The wire key of the section in the document's root.
  final String key;

  /// Every section but the secrets: what a plain "back up everything"
  /// means.
  static const Set<BackupSection> all = {follows, areaFollows, history, recordings, settings, iptv, multiview};

  /// The reference app's "favorites only" backup: rooms and areas.
  static const Set<BackupSection> followsOnly = {follows, areaFollows};

  /// The section with wire key [key], or null for one this codec does not
  /// know (a newer writer's addition).
  static BackupSection? byKey(String key) {
    for (final section in values) {
      if (section.key == key) return section;
    }
    return null;
  }
}

/// One backup document: the app's user data bundled into a single JSON
/// object — the followed rooms, the watch history, the followed areas, the
/// recording tasks, a named subset of the simple settings and, when the
/// user asked for it, the vault's secrets.
///
/// The shape is plain and forward-compatible: every section is an object
/// keyed by identity (`platform:roomId`, `platform:areaId`, the task id, the
/// pref key itself, the secret ref), so an older reader skips what a newer
/// writer added and a missing section restores as "nothing". The decode side
/// tolerates unknown keys and sections on purpose. A section the writer did
/// not select is simply absent from the root — that absence is what tells a
/// restore to leave that box alone.
final class BackupDocument {
  /// A document carrying [presentSections]; a present but empty section
  /// restores as "clear".
  BackupDocument({
    required this.exportedAt,
    this.follows = const {},
    this.history = const {},
    this.areaFollows = const {},
    this.recordings = const {},
    this.settings = const {},
    this.iptv = const {},
    this.multiview = const {},
    this.secrets = const {},
    Set<BackupSection>? presentSections,
  }) : presentSections = presentSections ?? BackupSection.all;

  factory BackupDocument._fromRoot(Map<String, Object?> root) {
    final version = _objectMap(root['version']);
    final exportedAt =
        DateTime.tryParse(version?['exportedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    // Only the sections the document actually carries may be restored: an
    // older writer that never knew a section must not clear it.
    var present = {
      for (final section in BackupSection.values)
        if (root[section.key] is Map) section,
    };
    // Schema 1 wrote every section even for a follows-only document (the
    // rest as empty maps) and relied on the scope to keep a restore off
    // them; honour that scope so those files still restore the two boxes
    // they meant.
    if (version?['scope'] == 'follows') present = present.intersection(BackupSection.followsOnly);
    return BackupDocument(
      exportedAt: exportedAt,
      follows: _entries(root['follows']),
      history: _entries(root['history']),
      areaFollows: _entries(root['areaFollows']),
      recordings: _entries(root['recordings']),
      settings: _settingsOf(root['settings']),
      iptv: _entries(root['iptv']),
      multiview: _entries(root['multiview']),
      secrets: _secretsOf(root['secrets']),
      presentSections: present,
    );
  }

  /// When the document was written (UTC; an unknown moment restores as
  /// the epoch).
  final DateTime exportedAt;

  /// The followed rooms: identity key → the room's storage JSON.
  final Map<String, Map<String, Object?>> follows;

  /// The watch history: identity key → the room's storage JSON with
  /// `lastWatchedAt` beside it.
  final Map<String, Map<String, Object?>> history;

  /// The followed areas: identity key → the area's stored fields.
  final Map<String, Map<String, Object?>> areaFollows;

  /// The recording tasks: task id → the task's storage JSON. A restore
  /// reads these as idle tasks — a take that was still recording becomes a
  /// waiting one, and a half-finished post-processing flag is dropped.
  final Map<String, Map<String, Object?>> recordings;

  /// The backed-up settings: pref key → the stored value (bool, int,
  /// double, String or String list).
  final Map<String, Object?> settings;

  /// The IPTV setup: store key (`iptv.playlists.v1`…) → `{items: [...]}`.
  final Map<String, Map<String, Object?>> iptv;

  /// The multiview documents: store key → the layout document.
  final Map<String, Map<String, Object?>> multiview;

  /// The vault's secrets: secret ref → plain text. Present only when the
  /// writer selected the section.
  final Map<String, String> secrets;

  /// The sections the document actually carries. A document from an older
  /// writer that lacked one leaves that box untouched on restore, rather
  /// than clearing data the document never knew about.
  final Set<BackupSection> presentSections;

  /// Whether the document is the reference app's "favorites only" backup:
  /// rooms and areas and nothing else.
  bool get followsOnly => setEquals(presentSections, BackupSection.followsOnly);

  /// Whether the document carries followed rooms.
  bool get hasFollows => presentSections.contains(BackupSection.follows);

  /// Whether it carries watch history.
  bool get hasHistory => presentSections.contains(BackupSection.history);

  /// Whether it carries followed areas.
  bool get hasAreas => presentSections.contains(BackupSection.areaFollows);

  /// Whether it carries recording tasks.
  bool get hasRecordings => presentSections.contains(BackupSection.recordings);

  /// Whether it carries settings.
  bool get hasSettings => presentSections.contains(BackupSection.settings);

  /// Whether it carries the IPTV setup.
  bool get hasIptv => presentSections.contains(BackupSection.iptv);

  /// Whether it carries the multiview layout.
  bool get hasMultiview => presentSections.contains(BackupSection.multiview);

  /// Whether it carries secrets.
  bool get hasSecrets => presentSections.contains(BackupSection.secrets);

  /// The schema this writer emits; a reader accepts any, and reports what
  /// it saw so a future migration can branch on it. Schema 2 added the
  /// secrets section and stopped writing the sections it did not select.
  static const int schemaVersion = 2;

  /// The document's app tag.
  static const String appTag = 'pure_live';

  /// The file name the WebDAV sync and the export settle on.
  static const String backupFileName = 'pure_live_backup.json';

  /// The export's file name, stamped with the local date and time so
  /// repeated backups in one day do not collide: `pure_live_backup_…json`
  /// or `pure_live_follows_…json` for a follows-only document.
  static String exportFileName(DateTime localNow, {bool followsOnly = false}) {
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${localNow.year}${two(localNow.month)}${two(localNow.day)}'
        '_${two(localNow.hour)}${two(localNow.minute)}${two(localNow.second)}';
    final kind = followsOnly ? 'follows' : 'backup';
    return 'pure_live_${kind}_$stamp.json';
  }

  /// The entries of [section], whatever its shape.
  int countOf(BackupSection section) => switch (section) {
    BackupSection.follows => follows.length,
    BackupSection.areaFollows => areaFollows.length,
    BackupSection.history => history.length,
    BackupSection.recordings => recordings.length,
    BackupSection.settings => settings.length,
    BackupSection.iptv => iptv.values.fold(0, (sum, entry) => sum + _itemCount(entry)),
    BackupSection.multiview => multiview.length,
    BackupSection.secrets => secrets.length,
  };

  static int _itemCount(Map<String, Object?> entry) => switch (entry['items']) {
    final List<Object?> items => items.length,
    _ => 0,
  };

  /// Whether nothing at all would be restored: every present section is
  /// empty.
  bool get isEmpty => presentSections.every((section) => countOf(section) == 0);

  /// The counts the pane's summary shows.
  ({int follows, int history, int areas, int recordings, int settings, int secrets}) get counts => (
    follows: follows.length,
    history: history.length,
    areas: areaFollows.length,
    recordings: recordings.length,
    settings: settings.length,
    secrets: secrets.length,
  );

  /// This document narrowed to [sections]: the ones it carries that the
  /// user still wants restored. The rest drop out of [presentSections], so
  /// a restore leaves their boxes alone.
  BackupDocument only(Set<BackupSection> sections) => BackupDocument(
    exportedAt: exportedAt,
    follows: follows,
    history: history,
    areaFollows: areaFollows,
    recordings: recordings,
    settings: settings,
    iptv: iptv,
    multiview: multiview,
    secrets: secrets,
    presentSections: presentSections.intersection(sections),
  );

  /// The document as the wire JSON, so a file or a server payload stays
  /// readable.
  String encode() => jsonEncode(toJson());

  /// The document as plain JSON objects. Only the present sections are
  /// written: the absence of a key is the reader's cue to leave that box
  /// untouched.
  Map<String, Object?> toJson() => {
    'version': <String, Object?>{
      'app': appTag,
      'schema': schemaVersion,
      'scope': followsOnly ? 'follows' : 'all',
      'sections': [for (final section in presentSections) section.key],
      'exportedAt': exportedAt.toUtc().toIso8601String(),
    },
    if (hasFollows) 'follows': follows,
    if (hasHistory) 'history': history,
    if (hasAreas) 'areaFollows': areaFollows,
    if (hasRecordings) 'recordings': recordings,
    if (hasSettings) 'settings': settings,
    if (hasIptv) 'iptv': iptv,
    if (hasMultiview) 'multiview': multiview,
    if (hasSecrets) 'secrets': secrets,
  };

  /// Parses [raw] as a backup document; answers null when it is not one.
  ///
  /// Defensive by design: a section of the wrong shape is dropped, not a
  /// failure — an export from a newer app still restores what this one
  /// understands. A root with neither this app's tag nor a single known
  /// section is not a backup at all, so `{}` can never wipe a device.
  static BackupDocument? tryDecode(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on Object {
      return null;
    }
    return tryFromJson(decoded);
  }

  /// Parses an already-decoded JSON value; see [tryDecode].
  static BackupDocument? tryFromJson(Object? decoded) {
    if (decoded is! Map) return null;
    final root = Map<String, Object?>.from(decoded);
    final tagged = _objectMap(root['version'])?['app'] == appTag;
    final hasSection = BackupSection.values.any((section) => root[section.key] is Map);
    if (!tagged && !hasSection) return null;
    return BackupDocument._fromRoot(root);
  }

  /// One keyed section: identity key → a stored JSON map. Entries that
  /// are not maps (a future writer's new shape) are skipped.
  static Map<String, Map<String, Object?>> _entries(Object? section) {
    if (section is! Map) return const {};
    final entries = <String, Map<String, Object?>>{};
    for (final entry in section.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String && value is Map) entries[key] = Map<String, Object?>.from(value);
    }
    return entries;
  }

  /// The settings section: pref key → the stored value as-is.
  static Map<String, Object?> _settingsOf(Object? section) =>
      section is Map ? Map<String, Object?>.from(section) : const {};

  /// The secrets section: ref → plain text; anything but a string is
  /// skipped.
  static Map<String, String> _secretsOf(Object? section) {
    if (section is! Map) return const {};
    return {
      for (final entry in section.entries)
        if (entry.key is String && entry.value is String) entry.key as String: entry.value as String,
    };
  }

  /// A nested object with string keys, or null when [value] is not one.
  static Map<String, Object?>? _objectMap(Object? value) => value is Map ? Map<String, Object?>.from(value) : null;
}
