import 'dart:convert' show jsonDecode, jsonEncode;

/// What a document carries: every section the codec knows, or just the
/// follows (the reference app's "favorites only" backup).
enum BackupScope {
  /// Followed rooms, watch history, followed areas and settings.
  all,

  /// Followed rooms and followed areas only.
  follows,
}

/// One backup document: the app's user data bundled into a single JSON
/// object — the followed rooms, the watch history, the followed areas and
/// a named subset of the simple settings.
///
/// The shape is plain and forward-compatible: every section is an object
/// keyed by identity (`platform:roomId`, `platform:areaId`, the pref key
/// itself), so an older reader skips what a newer writer added and a
/// missing section restores as "nothing". The decode side tolerates
/// unknown keys and sections on purpose.
final class BackupDocument {
  /// A document with the given sections; empty ones restore as "clear".
  BackupDocument({
    required this.exportedAt,
    this.scope = BackupScope.all,
    this.follows = const {},
    this.history = const {},
    this.areaFollows = const {},
    this.settings = const {},
    Set<String>? presentSections,
  }) : presentSections = presentSections ?? const {'follows', 'history', 'areaFollows', 'settings'};

  factory BackupDocument._fromRoot(Map<String, Object?> root) {
    final version = _objectMap(root['version']);
    final exportedAt =
        DateTime.tryParse(version?['exportedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
    return BackupDocument(
      exportedAt: exportedAt,
      scope: version?['scope'] == 'follows' ? BackupScope.follows : BackupScope.all,
      follows: _entries(root['follows']),
      history: _entries(root['history']),
      areaFollows: _entries(root['areaFollows']),
      settings: _settingsOf(root['settings']),
      // Only the sections the document actually carries may be restored:
      // an older writer that never knew a section must not clear it.
      presentSections: {
        for (final section in const ['follows', 'history', 'areaFollows', 'settings'])
          if (root[section] is Map) section,
      },
    );
  }

  /// When the document was written (UTC; an unknown moment restores as
  /// the epoch).
  final DateTime exportedAt;

  /// What this document carries. A follows-only document restores only
  /// its follows and areas; the other sections stay untouched.
  final BackupScope scope;

  /// Whether this document backs up the follows only.
  bool get followsOnly => scope == BackupScope.follows;

  /// The followed rooms: identity key → the room's storage JSON.
  final Map<String, Map<String, Object?>> follows;

  /// The watch history: identity key → the room's storage JSON with
  /// `lastWatchedAt` beside it.
  final Map<String, Map<String, Object?>> history;

  /// The followed areas: identity key → the area's stored fields.
  final Map<String, Map<String, Object?>> areaFollows;

  /// The backed-up settings: pref key → the stored value (bool, int,
  /// double, String or String list).
  final Map<String, Object?> settings;

  /// The sections the document actually carries. A document from an older
  /// writer that lacked one leaves that box untouched on restore, rather
  /// than clearing data the document never knew about.
  final Set<String> presentSections;

  /// Whether the document carries followed rooms.
  bool get hasFollows => presentSections.contains('follows');

  /// Whether it carries watch history.
  bool get hasHistory => presentSections.contains('history');

  /// Whether it carries followed areas.
  bool get hasAreas => presentSections.contains('areaFollows');

  /// Whether it carries settings.
  bool get hasSettings => presentSections.contains('settings');

  /// The schema this writer emits; a reader accepts any, and reports what
  /// it saw so a future migration can branch on it.
  static const int schemaVersion = 1;

  /// The document's app tag.
  static const String appTag = 'pure_live';

  /// The file name the WebDAV sync and the export settle on.
  static const String backupFileName = 'pure_live_backup.json';

  /// The export's file name, stamped with the local date and time so
  /// repeated backups in one day do not collide: `pure_live_backup_…json`
  /// or `pure_live_follows_…json` for a follows-only document.
  static String exportFileName(DateTime localNow, {BackupScope scope = BackupScope.all}) {
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${localNow.year}${two(localNow.month)}${two(localNow.day)}'
        '_${two(localNow.hour)}${two(localNow.minute)}${two(localNow.second)}';
    final kind = scope == BackupScope.follows ? 'follows' : 'backup';
    return 'pure_live_${kind}_$stamp.json';
  }

  /// Whether nothing at all would be restored. A follows-only document
  /// only needs follows or areas to be worth writing.
  bool get isEmpty => scope == BackupScope.follows
      ? follows.isEmpty && areaFollows.isEmpty
      : follows.isEmpty && history.isEmpty && areaFollows.isEmpty && settings.isEmpty;

  /// The counts the pane's summary shows.
  ({int follows, int history, int areas, int settings}) get counts =>
      (follows: follows.length, history: history.length, areas: areaFollows.length, settings: settings.length);

  /// The document as the wire JSON, so a file or a server payload stays
  /// readable.
  String encode() => jsonEncode(toJson());

  /// The document as plain JSON objects.
  Map<String, Object?> toJson() => {
    'version': <String, Object?>{
      'app': appTag,
      'schema': schemaVersion,
      'scope': scope.name,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
    },
    'follows': follows,
    'history': history,
    'areaFollows': areaFollows,
    'settings': settings,
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
    if (decoded is! Map) return null;
    final root = Map<String, Object?>.from(decoded);
    final tagged = _objectMap(root['version'])?['app'] == appTag;
    final hasSection = const ['follows', 'history', 'areaFollows', 'settings'].any((key) => root[key] is Map);
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

  /// A nested object with string keys, or null when [value] is not one.
  static Map<String, Object?>? _objectMap(Object? value) => value is Map ? Map<String, Object?>.from(value) : null;
}
