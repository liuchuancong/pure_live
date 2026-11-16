import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';

/// What came out of a legacy document: the v2 document to restore and the
/// legacy sections this build could not carry over (named for the confirm
/// so the user knows what stays behind).
final class LegacyImport {
  /// The import.
  const LegacyImport({required this.document, required this.skipped});

  /// The document in this app's shape.
  final BackupDocument document;

  /// The legacy section names left behind.
  final List<String> skipped;
}

/// Reads the reference app's backup (`backupVersion` 1–3, or the flat
/// pre-version form) into a [BackupDocument], so the cloud documents and
/// the files the old builds wrote restore into this one.
///
/// What crosses over: `favorite.favoriteRooms` → follows, `favorite.favoriteAreas`
/// → followed areas, `history.historyRooms` → watch history (with
/// `lastWatchedAt`), `cookie.*` → the vault's cookies (secrets). The legacy
/// settings sections (`theme`, `danmaku`, `player`…) spoke the old
/// controllers' keys and have no mapping here; they are reported as
/// skipped rather than guessed at.
abstract final class LegacyBackupImporter {
  /// The legacy sections this importer reads; everything else is skipped.
  static const Set<String> _carried = {'favorite', 'history', 'cookie'};

  /// The root keys that are bookkeeping, not data.
  static const Set<String> _meta = {'backupVersion', 'backupScope', 'sensitiveDataIncluded'};

  /// Whether [root] is a legacy document: it carries `backupVersion`, or the
  /// flat form's `favoriteRooms` at the root, and is not tagged as this
  /// app's. (The legacy `history` section shares its name with a v2
  /// section, so the tag, not the keys, tells the two apart.)
  static bool looksLegacy(Map<String, Object?> root) {
    final version = root['version'];
    if (version is Map && version['app'] == BackupDocument.appTag) return false;
    return root.containsKey('backupVersion') || root.containsKey('favoriteRooms') || root.containsKey('favorite');
  }

  /// Converts [root]; null when it is not a legacy document.
  static LegacyImport? tryImport(Map<String, Object?> root) {
    if (!looksLegacy(root)) return null;
    final versioned = root.containsKey('backupVersion');
    // The flat form keeps every list at the root; the sectioned form nests
    // them under their controller's name.
    final favorite = versioned ? _section(root['favorite']) : root;
    final history = versioned ? _section(root['history']) : root;
    final cookie = versioned ? _section(root['cookie']) : null;

    final follows = <String, Map<String, Object?>>{};
    for (final item in _objectList(favorite['favoriteRooms'])) {
      final room = _roomOf(item);
      if (room != null) follows[room.identityKey] = room.toJson();
    }
    final areas = <String, Map<String, Object?>>{};
    for (final item in _objectList(favorite['favoriteAreas'])) {
      final area = _areaOf(item);
      if (area != null) areas[area.identityKey] = _areaMapOf(area);
    }
    final watched = <String, Map<String, Object?>>{};
    for (final item in _objectList(history['historyRooms'])) {
      final room = _roomOf(item);
      if (room == null) continue;
      final at = switch (item['lastWatchedAt']) {
        final num millis => DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true),
        final String text => DateTime.tryParse(text),
        _ => null,
      };
      watched[room.identityKey] = {...room.toJson(), 'lastWatchedAt': (at ?? DateTime.now().toUtc()).toIso8601String()};
    }
    final secrets = <String, String>{};
    if (cookie != null) {
      for (final entry in cookie.entries) {
        final value = entry.value;
        if (value is! String || value.trim().isEmpty) continue;
        final ref = _credentialRefOf(entry.key);
        if (ref == null) continue;
        final stored = _credentialValueOf(entry.key, value);
        if (stored != null) secrets[ref] = stored;
      }
    }

    final present = <BackupSection>{
      if (favorite.containsKey('favoriteRooms')) BackupSection.follows,
      if (favorite.containsKey('favoriteAreas')) BackupSection.areaFollows,
      if (history.containsKey('historyRooms')) BackupSection.history,
      if (secrets.isNotEmpty) BackupSection.secrets,
    };
    final skipped = [
      for (final key in root.keys)
        if (!_meta.contains(key) && !_carried.contains(key) && (versioned || !_flatCarried.contains(key))) key,
    ];
    return LegacyImport(
      document: BackupDocument(
        exportedAt: DateTime.now().toUtc(),
        follows: follows,
        areaFollows: areas,
        history: watched,
        secrets: secrets,
        presentSections: present,
      ),
      skipped: skipped..sort(),
    );
  }

  /// The flat form's own data keys, so they do not count as skipped.
  static const Set<String> _flatCarried = {'favoriteRooms', 'favoriteAreas', 'historyRooms'};

  static Map<String, Object?> _section(Object? value) =>
      value is Map ? Map<String, Object?>.from(value) : const <String, Object?>{};

  /// A list whose items are maps, or JSON strings of maps (older builds
  /// stored stringified objects).
  static List<Map<String, Object?>> _objectList(Object? value) {
    if (value is! List) return const [];
    final out = <Map<String, Object?>>[];
    for (final item in value) {
      if (item is Map) {
        out.add(Map<String, Object?>.from(item));
      } else if (item is String) {
        final decoded = _tryJson(item);
        if (decoded is Map) out.add(Map<String, Object?>.from(decoded));
      }
    }
    return out;
  }

  static Object? _tryJson(String text) {
    try {
      return jsonDecode(text);
    } on Object {
      return null;
    }
  }

  static String _text(Object? value) => value is String ? value.trim() : '';

  /// The reference room → this app's room. Only what the old model carried
  /// that this one has a place for; the rest is refreshed from the site on
  /// the next load.
  static LiveRoom? _roomOf(Map<String, Object?> json) {
    final platform = _text(json['platform']).toLowerCase();
    final roomId = _text(json['roomId']);
    if (platform.isEmpty || roomId.isEmpty) return null;
    final nick = _text(json['nick']);
    final userId = _text(json['userId']);
    final tags = switch (json['tagIds']) {
      final List<Object?> list => [
        for (final tag in list)
          if (tag is String) tag,
      ],
      _ => const <String>[],
    };
    final status = switch (_text(json['liveStatus']).toLowerCase()) {
      'live' => LiveStatus.live,
      'replay' => LiveStatus.replay,
      'offline' => LiveStatus.offline,
      'banned' => LiveStatus.banned,
      _ => null,
    };
    return LiveRoom.normalized(
      platform: platform,
      roomId: roomId,
      content: RoomContent(
        (b) => b
          ..title = _text(json['title'])
          ..coverUrl = _text(json['cover'])
          ..introduction = _nullable(json['introduction'])
          ..notice = _nullable(json['notice']),
      ),
      anchor: nick.isEmpty && userId.isEmpty
          ? null
          : LiveAnchor(
              (b) => b
                ..platform = platform
                ..anchorId = userId.isEmpty ? roomId : userId
                ..name = nick
                ..avatarUrl = _nullable(json['avatar']),
            ),
      broadcast: status == null ? null : RoomBroadcast((b) => b..liveStatus = status),
      local: tags.isEmpty ? null : RoomLocal((b) => b..tagIds.addAll(tags)),
      area: _areaOf({'platform': platform, 'areaId': json['area'], 'areaName': json['area']}),
    );
  }

  static String? _nullable(Object? value) {
    final text = _text(value);
    return text.isEmpty ? null : text;
  }

  /// The followed-areas store's own shape (`AreaFollowRepository`).
  static Map<String, Object?> _areaMapOf(LiveArea area) => {
    'platform': area.platform,
    'areaId': area.areaId,
    'areaName': area.areaName,
    if (area.parentAreaId != null) 'parentAreaId': area.parentAreaId,
    if (area.parentAreaName != null) 'parentAreaName': area.parentAreaName,
    if (area.iconUrl != null) 'iconUrl': area.iconUrl,
    if (area.shortName != null) 'shortName': area.shortName,
  };

  static LiveArea? _areaOf(Map<String, Object?> json) {
    final platform = _text(json['platform']).toLowerCase();
    final areaId = _text(json['areaId']);
    final areaName = _text(json['areaName']);
    if (platform.isEmpty || areaId.isEmpty) return null;
    return LiveArea.of(
      platform: platform,
      areaId: areaId,
      areaName: areaName.isEmpty ? areaId : areaName,
      parentAreaId: _nullable(json['areaType']),
      parentAreaName: _nullable(json['typeName']),
      iconUrl: _nullable(json['areaPic']),
      shortName: _nullable(json['shortName']),
    );
  }

  /// The reference cookie controller's keys → this app's credential refs:
  /// a site cookie becomes the `credentials/<site>` document the account
  /// repository reads, and the douyu renewal pair keeps its own sub-refs.
  static String? _credentialRefOf(String key) => switch (key) {
    'bilibiliCookie' => 'credentials/bilibili',
    'huyaCookie' => 'credentials/huya',
    'douyuCookie' => 'credentials/douyu',
    'douyinCookie' => 'credentials/douyin',
    'kuaishouCookie' => 'credentials/kuaishou',
    'douyuLtp0' => 'credentials/douyu.ltp0',
    'douyuDid' => 'credentials/douyu.did',
    _ => null,
  };

  /// A legacy value in the stored form its ref names. A cookie header
  /// (`name=value; …`) becomes the credential document; the douyu renewal
  /// pair is kept raw. A header with no readable pairs is left out rather
  /// than stored as a document the app would call unreadable.
  static String? _credentialValueOf(String key, String value) {
    if (key == 'douyuLtp0' || key == 'douyuDid') return value;
    final site = switch (key) {
      'bilibiliCookie' => 'bilibili',
      'huyaCookie' => 'huya',
      'douyuCookie' => 'douyu',
      'douyinCookie' => 'douyin',
      'kuaishouCookie' => 'kuaishou',
      _ => null,
    };
    if (site == null) return null;
    final cookies = <String, String>{};
    for (final part in value.split(';')) {
      final pair = part.trim();
      final equals = pair.indexOf('=');
      if (equals <= 0) continue;
      final name = pair.substring(0, equals).trim();
      final fieldValue = pair.substring(equals + 1).trim();
      if (name.isEmpty || fieldValue.isEmpty) continue;
      cookies[name] = fieldValue;
    }
    if (cookies.isEmpty) return null;
    return jsonEncode({'siteId': site, 'cookies': cookies});
  }
}
