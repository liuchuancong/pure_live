import 'package:live_library/live_library.dart';
import 'package:live_sites/live_sites.dart';

/// Writes one shield list under one of the shield page's keys; the same
/// keyed box the shield page owns, handed in by the service.
typedef ShieldListSink = Future<void> Function(String key, List<String> values);

/// The sync payload codec: the bridge between the 3.x backup wire format and
/// this app's own stores.
///
/// The 3.x sender POSTs a `BackupController.exportAllSettings` document —
/// one top-level key per settings module (`favorite`, `history`, `tags`,
/// ...), each a self-contained map. This app persists follows, watch history
/// and the danmaku shield lists, and only those three sections carry data a
/// local store can hold, so only they are produced and consumed here:
///
/// - `favorite` → [FollowRepository] rooms (with `shieldList` /
///   `blockedDanmakuUsers` mapping onto the shield's keywords / users);
/// - `history` → [HistoryRepository];
/// - `tags` → follow groups and each record's group memberships.
///
/// Everything else the 3.x payload can carry (app, theme, player, danmaku,
/// iptv, ...) has no store on this side and is skipped by the importer.
/// Application is a merge, not a replace: sync converges the devices
/// instead of clobbering them.
abstract final class RemoteSyncPayload {
  /// The sections this app exports and applies.
  static const List<String> sectionNames = <String>['favorite', 'history', 'tags'];


  /// The 3.x backup format version reproduced on export.
  static const int _backupVersion = 3;

  /// The meta keys that ride along every 3.x document.
  static const Set<String> _metaKeys = <String>{'backupVersion', 'backupScope', 'sensitiveDataIncluded'};

  /// The 3.x `LiveStatus` order — the wire carries enum indexes, and the
  /// 3.x order differs from this app's `LiveStatus` order.
  static const List<String> _referenceStatusNames = <String>[
    'live',
    'offline',
    'replay',
    'unknown',
    'banned',
    'carousel',
  ];

  /// Builds a 3.x-shaped export from this device's stores, narrowed to
  /// [sections] when the picker ticked a subset.
  static Map<String, dynamic> buildExport({
    required List<LibraryRoom> follows,
    required List<FollowGroup> groups,
    required List<WatchRecord> history,
    required List<String> shieldKeywords,
    required List<String> shieldUsers,
    Iterable<String>? sections,
  }) {
    final data = <String, dynamic>{
      'backupVersion': _backupVersion,
      'sensitiveDataIncluded': false,
      'favorite': <String, dynamic>{
        'shieldList': List<String>.from(shieldKeywords),
        'blockedDanmakuUsers': List<String>.from(shieldUsers),
        'favoriteRooms': [for (final record in follows) referenceRoomJson(record.room)],
        'favoriteAreas': <Map<String, dynamic>>[],
      },
      'history': <String, dynamic>{
        'historyRooms': [for (final record in history) referenceRoomJson(record.room)],
      },
      'tags': <String, dynamic>{
        'tags': [
          for (final group in groups)
            {'id': group.id, 'name': group.name, 'description': '', 'order': group.position},
        ],
        'roomTagsMap': {
          for (final record in follows)
            if (record.groupIds.isNotEmpty) record.identity: List<String>.from(record.groupIds),
        },
      },
    };
    if (sections == null) {
      return data;
    }
    final selected = sections.toSet();
    return <String, dynamic>{
      for (final entry in data.entries)
        if (_metaKeys.contains(entry.key) || selected.contains(entry.key)) entry.key: entry.value,
    };
  }

  /// The sections of [payload] this app can apply, in canonical order.
  static List<String> presentSections(Map<String, dynamic> payload) {
    bool has(String section, String key) => payload[section] is Map && (payload[section] as Map).containsKey(key);
    return <String>[
      if (has('favorite', 'favoriteRooms')) 'favorite',
      if (has('history', 'historyRooms')) 'history',
      if (has('tags', 'tags') || has('tags', 'roomTagsMap')) 'tags',
    ];
  }

  /// Applies the received [payload] through this app's real repositories,
  /// narrowed to [sections] when the receiver ticked a subset.
  ///
  /// Reads and writes the shield lists through [shield], the same keyed
  /// box the shield page owns. Returns whether anything applied.
  static Future<bool> apply(
    Map<String, dynamic> payload, {
    required FollowRepository follows,
    required HistoryRepository history,
    required ShieldListSink shield,
    Iterable<String>? sections,
  }) async {
    final selected = sections?.toSet();
    bool wanted(String section) => selected == null || selected.contains(section);
    final favorite = _section(payload, 'favorite');
    final tags = _section(payload, 'tags');
    var applied = false;

    if (wanted('favorite') && favorite != null) {
      final rooms = _referenceRooms(favorite['favoriteRooms']);
      // Wire order is the sender's list order; `follow` appends with
      // increasing positions, so walking it forward preserves the order.
      for (final room in rooms) {
        await follows.follow(room);
      }
      final keywords = _stringList(favorite['shieldList']);
      final users = _stringList(favorite['blockedDanmakuUsers']);
      if (keywords.isNotEmpty) {
        await shield('shield.keywords', keywords);
      }
      if (users.isNotEmpty) {
        await shield('shield.users', users);
      }
      applied = true;
    }

    if (wanted('history')) {
      final rooms = _referenceRooms(_section(payload, 'history')?['historyRooms']);
      // Oldest first, so `record` lands the newest on top.
      for (final room in rooms.reversed) {
        await history.record(room);
      }
      if (rooms.isNotEmpty) {
        applied = true;
      }
    }

    if (wanted('tags') && tags != null) {
      final mapped = await _applyGroups(tags, follows: follows);
      applied = applied || mapped;
    }
    return applied;
  }

  /// Maps the 3.x `tags` section onto follow groups: one group per incoming
  /// tag (matched by name), then every room's membership rewritten.
  static Future<bool> _applyGroups(Map<String, dynamic> tags, {required FollowRepository follows}) async {
    final incoming = <({String id, String name, int order})>[];
    final rawTags = tags['tags'];
    if (rawTags is List) {
      for (final entry in rawTags) {
        if (entry is! Map) {
          continue;
        }
        final name = entry['name']?.toString().trim() ?? '';
        if (name.isEmpty) {
          continue;
        }
        incoming.add((
          id: entry['id']?.toString() ?? '',
          name: name,
          order: int.tryParse(entry['order']?.toString() ?? '') ?? 0,
        ));
      }
    }
    var applied = false;
    if (incoming.isNotEmpty) {
      final byName = {for (final group in follows.groups) group.name: group};
      final idMap = <String, String>{};
      for (final tag in incoming) {
        final known = byName[tag.name];
        if (known != null) {
          idMap[tag.id] = known.id;
          continue;
        }
        final created = await follows.createGroup(tag.name);
        byName[tag.name] = follows.groups.lastWhere((group) => group.id == created);
        if (tag.id.isNotEmpty) {
          idMap[tag.id] = created;
        }
        applied = true;
      }
      final mapping = tags['roomTagsMap'];
      if (mapping is Map) {
        for (final entry in mapping.entries) {
          final identity = entry.key.toString().trim();
          final record = follows.rooms.where((item) => item.identity == identity).firstOrNull;
          if (record == null) {
            continue;
          }
          final groupIds = <String>[
            for (final tagId in _stringList(entry.value))
              if (idMap[tagId] != null) idMap[tagId]!,
          ];
          await follows.setGroups(record.room, groupIds);
          applied = true;
        }
      }
    }
    return applied;
  }

  /// The 3.x room JSON this app's [room] serializes into.
  static Map<String, dynamic> referenceRoomJson(LiveRoom room) {
    final audience = room.audience;
    return <String, dynamic>{
      'roomId': room.roomId,
      'userId': room.anchor?.anchorId,
      'title': room.content.title,
      'nick': room.anchor?.name,
      'avatar': room.anchor?.avatarUrl ?? '',
      'cover': room.content.coverUrl,
      'area': room.area?.areaName ?? '',
      // The legacy single audience field: the primary metric's reading.
      'watching': switch (audience.primaryMetric) {
        LiveAudienceMetricType.onlineViewers => audience.onlineViewers,
        LiveAudienceMetricType.totalViewers => audience.totalViewers,
        LiveAudienceMetricType.followers => room.anchor?.followerCount,
        _ => audience.popularity,
      }?.toString(),
      'audienceMetricType': audience.primaryMetric?.name,
      'popularity': audience.popularity?.toString(),
      'onlineViewers': audience.onlineViewers?.toString(),
      'totalViewers': audience.totalViewers?.toString(),
      'followers': room.anchor?.followerCount?.toString(),
      'platform': room.platform,
      'tagIds': <String>[],
      // The 3.x wire carries the status as an index into its own enum order.
      'liveStatus': _referenceStatusNames.indexOf(room.broadcast.effectiveLiveStatus.name),
      'isRecord': room.broadcast.isRecord,
      'status': room.broadcast.isLiveNow,
      'notice': room.content.notice,
      'introduction': room.content.introduction,
      'lastWatchedAt': room.local.lastWatchedAt?.millisecondsSinceEpoch,
    };
  }

  /// Decodes the 3.x room list [raw] into this app's [LiveRoom]s, skipping
  /// records without a usable identity.
  static List<LiveRoom> _referenceRooms(Object? raw) {
    final rooms = <LiveRoom>[];
    if (raw is! List) {
      return rooms;
    }
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }
      final platform = entry['platform']?.toString().trim().toLowerCase() ?? '';
      final roomId = entry['roomId']?.toString().trim() ?? '';
      if (platform.isEmpty || roomId.isEmpty) {
        continue;
      }
      final metric = LiveAudienceMetricType.values
          .where((value) => value.name == entry['audienceMetricType'])
          .firstOrNull;
      final restriction = entry['restriction'] == null
          ? null
          : LiveRestriction.fromName(entry['restriction']?.toString());
      final areaName = entry['area']?.toString().trim() ?? '';
      rooms.add(
        LiveRoom.normalized(
          platform: platform,
          roomId: roomId,
          content: RoomContent(
            title: entry['title']?.toString() ?? '',
            coverUrl: entry['cover']?.toString() ?? '',
            introduction: entry['introduction']?.toString(),
            notice: entry['notice']?.toString(),
          ),
          audience: RoomAudience(
            popularity: parseCount(entry['popularity']) ?? parseCount(entry['watching']),
            onlineViewers: parseCount(entry['onlineViewers']),
            totalViewers: parseCount(entry['totalViewers']),
            primaryMetric: metric,
          ),
          broadcast: RoomBroadcast(
            liveStatus: _liveStatusFromReference(entry['liveStatus']),
            startedAt: _dateTime(entry['startedAt']),
            restriction: restriction == LiveRestriction.none ? null : restriction,
          ),
          anchor: LiveAnchor.normalized(
            platform: platform,
            anchorId: entry['userId']?.toString() ?? '',
            name: entry['nick']?.toString() ?? '',
            avatarUrl: entry['avatar']?.toString(),
            followerCount: parseCount(entry['followers']),
          ),
          // The 3.x room carries only the area's display name; it becomes
          // both the id and the name, which is all a label needs.
          area: areaName.isEmpty
              ? null
              : LiveArea.normalized(platform: platform, areaId: areaName, areaName: areaName),
          local: RoomLocal(lastWatchedAt: _dateTimeMillis(entry['lastWatchedAt'])),
        ),
      );
    }
    return rooms;
  }

  static Map<String, dynamic>? _section(Map<String, dynamic> payload, String name) {
    final section = payload[name];
    return section is Map ? Map<String, dynamic>.from(section) : null;
  }

  static List<String> _stringList(Object? raw) => [
    if (raw is List) for (final entry in raw) if (entry != null) entry.toString(),
  ];

  /// The 3.x status index → this app's [LiveStatus]; anything unreadable
  /// stays null, which for this app means "the source said nothing".
  static LiveStatus? _liveStatusFromReference(Object? raw) {
    final index = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (index == null || index < 0 || index >= _referenceStatusNames.length) {
      return null;
    }
    final name = _referenceStatusNames[index];
    return LiveStatus.values.where((value) => value.name == name).firstOrNull;
  }

  static DateTime? _dateTime(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toUtc();
    }
    return _dateTimeMillis(raw);
  }

  static DateTime? _dateTimeMillis(Object? raw) {
    final millis = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (millis == null || millis <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Parses a 3.x audience text (`"1.2万"`, `"3,400"`, `"42"`) into an
  /// absolute count; null when no number is carried. The 3.x
  /// `parseAudienceNumber` behaviour, kept local because live_sites does not
  /// export its own.
  static int? parseCount(Object? raw) {
    var text = raw?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty || text == 'null') {
      return null;
    }
    text = text.replaceAll(',', '').replaceAll('，', '');
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(亿|万|千|[kwm])?').firstMatch(text);
    final number = double.tryParse(match?.group(1) ?? '');
    if (number == null) {
      return null;
    }
    const multipliers = <String, int>{'亿': 100000000, '万': 10000, 'w': 10000, '千': 1000, 'k': 1000, 'm': 1000000};
    return (number * (multipliers[match?.group(2)] ?? 1)).round();
  }
}
