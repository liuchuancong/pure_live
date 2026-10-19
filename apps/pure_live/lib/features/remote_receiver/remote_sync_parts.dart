/// A part of the device-sync payload the user can take or leave on its own
/// (the reference's `SyncPart`, docs/J05.1): the pick-list both the send and
/// the receive run through, mapped onto this app's payload sections.
enum RemoteSyncPart {
  /// The preference groups (room card, refresh, page, proxy, loading).
  settings('settings'),

  /// Followed rooms.
  follows('follows'),

  /// Watch history.
  history('history'),

  /// Follow groups and their memberships.
  groups('groups'),

  /// Danmaku keyword blocks.
  keywords('keywords'),

  /// Danmaku user blocks.
  users('users'),

  /// WebDAV servers with their vault passwords (only with "同步账号 Cookie").
  webdav('webdav'),

  /// Platform sign-ins (only with "同步账号 Cookie").
  accounts('accounts');

  new(this.wireName);

  /// The name this part travels under (the status answer's list, the
  /// dialog's checkbox keys).
  final String wireName;

  /// The part named [wireName]; null for a name this build does not know.
  static RemoteSyncPart? maybeFromWire(String? name) {
    for (final part in RemoteSyncPart.values) {
      if (part.wireName == name) {
        return part;
      }
    }
    return null;
  }
}

/// The payload's keys that describe the document rather than hold data; a
/// pick always keeps them.
const Set<String> _fileKeys = {'backupVersion', 'backupScope', 'sensitiveDataIncluded'};

/// Sections that are one part each.
const Map<String, RemoteSyncPart> _wholeSections = {
  'tags': RemoteSyncPart.groups,
  'webdav': RemoteSyncPart.webdav,
  'accounts': RemoteSyncPart.accounts,
};

/// Lists inside a section that are one part each; the rest of those sections
/// is settings (`favoriteAreas`, and every preference section).
const Map<String, Map<String, RemoteSyncPart>> _listsIn = {
  'favorite': {
    'favoriteRooms': RemoteSyncPart.follows,
    'shieldList': RemoteSyncPart.keywords,
    'blockedDanmakuUsers': RemoteSyncPart.users,
  },
  'history': {'historyRooms': RemoteSyncPart.history},
};

RemoteSyncPart _partOf(String section, String key) =>
    _wholeSections[section] ?? _listsIn[section]?[key] ?? RemoteSyncPart.settings;

/// Whether the payload of [data] can be picked apart: the sectioned document
/// (`backupVersion`, which 3.x and this app both write); the oldest flat
/// files go whole.
bool syncPartsSplittable(Map<String, Object?> data) => data['backupVersion'] != null;

/// The parts [data] holds, in [RemoteSyncPart] order.
List<RemoteSyncPart> syncPartsIn(Map<String, Object?> data) {
  final found = <RemoteSyncPart>{};
  for (final MapEntry(key: section, value: body) in data.entries) {
    if (_fileKeys.contains(section) || body is! Map) {
      continue;
    }
    if (_wholeSections[section] case final part?) {
      found.add(part);
      continue;
    }
    for (final key in body.keys) {
      found.add(_partOf(section, '$key'));
    }
  }
  return [
    for (final part in RemoteSyncPart.values)
      if (found.contains(part)) part,
  ];
}

/// Whether [parts] leave out something [data] holds (null leaves out
/// nothing; neither does a flat file).
bool syncPartsLeaveOut(Map<String, Object?> data, Set<RemoteSyncPart>? parts) =>
    parts != null && syncPartsSplittable(data) && !syncPartsIn(data).every(parts.contains);

/// [data] when [parts] leave nothing out of it, [pickSyncParts] otherwise.
Map<String, Object?> onlySyncParts(Map<String, Object?> data, Set<RemoteSyncPart>? parts) =>
    syncPartsLeaveOut(data, parts) ? pickSyncParts(data, parts!) : data;

/// [data] with only the [parts] chosen: the other lists and sections are
/// left out, so the receiver's apply never sees them and they stay as they
/// are. Sections left empty go too. A flat file goes as it is.
Map<String, Object?> pickSyncParts(Map<String, Object?> data, Set<RemoteSyncPart> parts) {
  if (!syncPartsSplittable(data)) {
    return data;
  }
  final picked = <String, Object?>{};
  for (final MapEntry(key: section, value: body) in data.entries) {
    if (_fileKeys.contains(section)) {
      picked[section] = body;
    } else if (body is! Map) {
      // Not a section (an unknown value): it travels with the settings.
      if (parts.contains(RemoteSyncPart.settings)) {
        picked[section] = body;
      }
    } else if (_wholeSections[section] case final part?) {
      if (parts.contains(part)) {
        picked[section] = body;
      }
    } else {
      final kept = {
        for (final MapEntry(key: field, value: entry) in body.entries)
          if (parts.contains(_partOf(section, '$field'))) '$field': entry,
      };
      if (kept.isNotEmpty) {
        picked[section] = kept;
      }
    }
  }
  if (picked.containsKey('sensitiveDataIncluded')) {
    picked['sensitiveDataIncluded'] = picked.containsKey('accounts') || picked.containsKey('webdav');
  }
  return picked;
}

/// The sections of [data] that hold data (what the packet's `sections`
/// lists — the sender's narrowing the receiver re-reads).
List<String> syncSectionsOf(Map<String, Object?> data) => [
  for (final key in data.keys)
    if (!_fileKeys.contains(key)) key,
];

/// [data] with only the [sections] a packet lists (and the file keys); all
/// of it when the packet lists none (a 3.x sender, a whole send).
Map<String, Object?> withinSyncSections(Map<String, Object?> data, List<String>? sections) {
  if (sections == null || sections.isEmpty) {
    return data;
  }
  final wanted = sections.toSet();
  return {
    for (final MapEntry(key: field, value: entry) in data.entries)
      if (_fileKeys.contains(field) || wanted.contains(field)) field: entry,
  };
}

/// How many entries each part of [data] has, read the way the importer
/// reads them; parts the payload does not hold are left out.
Map<RemoteSyncPart, int> syncPartCounts(Map<String, Object?> data) {
  int listLength(Object? raw) => raw is List ? raw.length : 0;
  Map<Object?, Object?>? body(String name) => data[name] is Map ? data[name]! as Map<Object?, Object?> : null;
  final favorite = body('favorite');
  final history = body('history');
  final tags = body('tags');
  final webdav = body('webdav');
  final accounts = body('accounts');
  var settings = 0;
  for (final key in data.keys) {
    if (_fileKeys.contains(key) || _listsIn.containsKey(key) || _wholeSections.containsKey(key)) {
      continue;
    }
    final entry = data[key];
    settings += entry is Map ? entry.length : 1;
  }
  return {
    if (settings > 0) RemoteSyncPart.settings: settings,
    if (favorite != null && favorite.containsKey('favoriteRooms'))
      RemoteSyncPart.follows: listLength(favorite['favoriteRooms']),
    if (history != null && history.containsKey('historyRooms'))
      RemoteSyncPart.history: listLength(history['historyRooms']),
    if (tags != null && tags.containsKey('tags')) RemoteSyncPart.groups: listLength(tags['tags']),
    if (favorite != null && favorite.containsKey('shieldList'))
      RemoteSyncPart.keywords: listLength(favorite['shieldList']),
    if (favorite != null && favorite.containsKey('blockedDanmakuUsers'))
      RemoteSyncPart.users: listLength(favorite['blockedDanmakuUsers']),
    if (webdav != null && webdav.containsKey('servers')) RemoteSyncPart.webdav: listLength(webdav['servers']),
    if (accounts != null && accounts.containsKey('credentials'))
      RemoteSyncPart.accounts: listLength(accounts['credentials']),
  };
}
