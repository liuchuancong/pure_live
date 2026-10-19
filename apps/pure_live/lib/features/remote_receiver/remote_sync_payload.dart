import 'package:live_library/live_library.dart';
import 'package:live_sites/live_sites.dart';

import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';

/// Writes one shield list under one of the shield page's keys; the same
/// keyed box the shield page owns, handed in by the service.
typedef ShieldListSink = Future<void> Function(String key, List<String> values);

/// Stores one incoming WebDAV server (name, address, username, directory and
/// the vault password); the WebDAV store's own `saveServer`, handed in by
/// the service.
typedef WebDavServerSink = Future<void> Function(Map<String, dynamic> server);

/// Stores one incoming platform credential (site + the login repository's
/// credential document); the login side's save, handed in by the service.
typedef AccountCredentialSink = Future<void> Function(Map<String, dynamic> credential);

/// The sync payload codec: the bridge between the 3.x backup wire format and
/// this app's own stores.
///
/// The 3.x sender POSTs a `BackupController.exportAllSettings` document —
/// one top-level key per settings module (`favorite`, `history`, `tags`,
/// ...), each a self-contained map. The sections this app produces and
/// consumes are the ones a local store can hold:
///
/// - `favorite` → [FollowRepository] rooms (with `shieldList` /
///   `blockedDanmakuUsers` mapping onto the shield's keywords / users);
/// - `history` → [HistoryRepository];
/// - `tags` → follow groups and each record's group memberships;
/// - `roomCard`, `refresh`, `page`, `proxy`, `loading` → the general
///   preference document ([AppPreferences]), the same groups the settings
///   pages edit.
///
/// The preference sections keep the 3.x wire shapes — the keys its own
/// controllers serialize — so a 3.x peer applies them and theirs apply here.
/// Where the 3.x shape has no key for a value this app holds (the page
/// group's branch order), the app's own keys ride inside the section; a 3.x
/// receiver reads only its own keys and ignores the rest. `loading` is a new
/// section: the 3.x build keeps the loading style inside its `theme`
/// section, and the importer reads it from there too.
///
/// `webdav` and `accounts` are this build's sensitive sections: they are
/// exported only while "同步账号 Cookie" is on, and applied through sinks
/// the service hands in (the WebDAV store and the login repositories) — a
/// receiver without them leaves that part untouched.
///
/// Everything else the 3.x payload can carry (app, theme, player, danmaku,
/// iptv, ...) has no store on this side and is skipped by the importer.
/// Application is a merge, not a replace: sync converges the devices
/// instead of clobbering them.
abstract final class RemoteSyncPayload {
  /// The sections this app exports and applies.
  static const List<String> sectionNames = <String>[
    'favorite',
    'history',
    'tags',
    'roomCard',
    'refresh',
    'page',
    'proxy',
    'loading',
  ];

  /// The sensitive sections: they travel only when the user ticks
  /// "同步账号 Cookie" (the reference's `includeAccounts` /
  /// `includeSensitiveData`).
  static const List<String> sensitiveSectionNames = <String>['webdav', 'accounts'];

  /// The sections the settings part covers — the preference groups the
  /// settings pages edit (the receive preview diffs these).
  static const List<String> preferenceSectionNames = <String>['roomCard', 'refresh', 'page', 'proxy', 'loading'];

  /// The 3.x `RefreshConfigController` shipping defaults, emitted for the
  /// keys this app holds no answer for.
  static const int _referenceDefaultInterval = 30;

  /// The 3.x `ProxySettingsController`'s second (per-app) proxy, emitted off
  /// because this app holds one proxy only.
  static const int _referenceDefaultProxyPort = 7890;

  /// The 3.x loading-style key that means its shimmer; every other 3.x key
  /// (`AppConsts.loadingStyleKeys`) names a spinner animation.
  static const String _referenceDefaultLoadingStyle = 'default';

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
  /// [sections] when the picker ticked a subset. [webdavServers] and
  /// [accountCredentials] are the sensitive sections, handed in by the
  /// service only while "同步账号 Cookie" is on (the reference's
  /// `includeSensitiveData`); with them the document says
  /// `sensitiveDataIncluded`.
  static Map<String, dynamic> buildExport({
    required AppPreferences preferences,
    required List<LibraryRoom> follows,
    required List<FollowGroup> groups,
    required List<WatchRecord> history,
    required List<String> shieldKeywords,
    required List<String> shieldUsers,
    List<Map<String, dynamic>>? webdavServers,
    List<Map<String, dynamic>>? accountCredentials,
    Iterable<String>? sections,
  }) {
    final data = <String, dynamic>{
      'backupVersion': _backupVersion,
      'sensitiveDataIncluded': webdavServers != null || accountCredentials != null,
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
          for (final group in groups) {'id': group.id, 'name': group.name, 'description': '', 'order': group.position},
        ],
        'roomTagsMap': {
          for (final record in follows)
            if (record.groupIds.isNotEmpty) record.identity: List<String>.from(record.groupIds),
        },
      },
      'roomCard': _roomCardSection(preferences),
      'refresh': _refreshSection(preferences),
      'page': _pageSection(preferences),
      'proxy': _proxySection(preferences),
      'loading': _loadingSection(preferences),
      if (webdavServers case final servers?)
        'webdav': <String, dynamic>{
          'servers': [for (final server in servers) Map<String, dynamic>.from(server)],
        },
      if (accountCredentials case final credentials?)
        'accounts': <String, dynamic>{
          'credentials': [for (final entry in credentials) Map<String, dynamic>.from(entry)],
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

  /// The `roomCard` section: the 3.x per-viewport appearance both built from
  /// the one card style this app draws.
  static Map<String, dynamic> _roomCardSection(AppPreferences preferences) {
    final appearance = <String, dynamic>{
      'layout': 'cover',
      'showAvatar': preferences.roomCardShowAnchor,
      'showAnchorName': preferences.roomCardShowAnchor,
      'showPlatformBadge': preferences.roomCardShowPlatform,
      'automaticPlatformBadge': false,
      'showAudience': preferences.roomCardShowAudience,
      'showReplayBadge': true,
      'cornerRadius': preferences.roomCardCornerRadius,
    };
    return <String, dynamic>{
      'mobilePreset': 'custom',
      'desktopPreset': 'custom',
      'mobileConfig': appearance,
      'desktopConfig': Map<String, dynamic>.from(appearance),
    };
  }

  /// The `refresh` section: the 3.x feed-refresh answers this app keeps an
  /// equivalent of; its other keys go out at the shipping defaults.
  static Map<String, dynamic> _refreshSection(AppPreferences preferences) {
    final minutes = preferences.autoRefreshMinutes;
    return <String, dynamic>{
      'autoRefreshFavorite': minutes > 0,
      'refreshFavoriteOnResume': preferences.refreshOnResume,
      'autoRefreshInterval': minutes > 0 ? minutes.clamp(5, 360) : _referenceDefaultInterval,
      'maxConcurrentRefresh': 4,
      'autoRefreshThumbnails': false,
      'thumbnailRefreshInterval': _referenceDefaultInterval,
    };
  }

  /// The `page` section: the app's own page-group answers (launch page,
  /// branch order) ride as extra keys — a 3.x receiver reads only its own
  /// keys out of a section and ignores the rest.
  static Map<String, dynamic> _pageSection(AppPreferences preferences) => <String, dynamic>{
    'launchBranch': preferences.launchBranch.id,
    'restoreLastTab': preferences.restoreLastTab,
    'shellBranches': List<String>.from(preferences.shellBranches),
  };

  /// The `proxy` section: the one proxy this app routes through; the 3.x
  /// per-app proxy goes out off.
  static Map<String, dynamic> _proxySection(AppPreferences preferences) => <String, dynamic>{
    'enableProxy': preferences.proxyEnabled,
    'proxyHost': preferences.proxyHost,
    'proxyPort': preferences.proxyPort,
    'enableAppProxy': false,
    'appProxyHost': '',
    'appProxyPort': _referenceDefaultProxyPort,
  };

  /// The `loading` section: a new top-level section for the loading style —
  /// a 3.x receiver ignores sections it does not know.
  static Map<String, dynamic> _loadingSection(AppPreferences preferences) => <String, dynamic>{
    'loadingStyle': preferences.loadingStyle.id,
  };

  /// The sections of [payload] this app can apply, in canonical order.
  static List<String> presentSections(Map<String, dynamic> payload) {
    bool has(String section, String key) => payload[section] is Map && (payload[section] as Map).containsKey(key);
    return <String>[
      if (has('favorite', 'favoriteRooms')) 'favorite',
      if (has('history', 'historyRooms')) 'history',
      if (has('tags', 'tags') || has('tags', 'roomTagsMap')) 'tags',
      if (has('roomCard', 'mobileConfig') || has('roomCard', 'desktopConfig') || has('roomCard', 'mobilePreset'))
        'roomCard',
      if (has('refresh', 'autoRefreshFavorite') ||
          has('refresh', 'refreshFavoriteOnResume') ||
          has('refresh', 'autoRefreshInterval'))
        'refresh',
      if (has('page', 'shellBranches') ||
          has('page', 'launchBranch') ||
          has('page', 'defaultPageSize') ||
          has('page', 'showPageSizeSelector'))
        'page',
      if (has('proxy', 'enableProxy') || has('proxy', 'proxyHost')) 'proxy',
      if (has('loading', 'loadingStyle') || has('theme', 'loadingStyle')) 'loading',
      if (has('webdav', 'servers')) 'webdav',
      if (has('accounts', 'credentials')) 'accounts',
    ];
  }

  /// Applies the received [payload] through this app's real repositories,
  /// narrowed to [sections] when the receiver ticked a subset.
  ///
  /// Reads and writes the shield lists through [shield], the same keyed box
  /// the shield page owns, and the preference groups through [preferences],
  /// the store the settings pages edit. The sensitive sections go through
  /// [webdav] and [accounts] — sinks the service hands in from the WebDAV
  /// store and the login repositories; a payload that carries a section the
  /// receiver cannot store leaves that part out. Returns whether anything
  /// applied.
  static Future<bool> apply(
    Map<String, dynamic> payload, {
    required AppPreferencesStore preferences,
    required FollowRepository follows,
    required HistoryRepository history,
    required ShieldListSink shield,
    WebDavServerSink? webdav,
    AccountCredentialSink? accounts,
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

    if (wanted('roomCard')) {
      final roomCard = _section(payload, 'roomCard');
      // One card style here; the desktop viewport is the sender's fuller
      // one, the mobile config the fallback.
      final appearance =
          _referenceAppearance(roomCard?['desktopConfig']) ?? _referenceAppearance(roomCard?['mobileConfig']);
      if (appearance != null) {
        await preferences.update(
          (p) => p.copyWith(
            roomCardCornerRadius: appearance.radius ?? p.roomCardCornerRadius,
            roomCardShowPlatform: appearance.showPlatform ?? p.roomCardShowPlatform,
            roomCardShowAudience: appearance.showAudience ?? p.roomCardShowAudience,
            roomCardShowAnchor: appearance.showAnchor ?? p.roomCardShowAnchor,
          ),
        );
        applied = true;
      }
    }

    if (wanted('refresh')) {
      final refresh = _section(payload, 'refresh');
      if (refresh != null &&
          _hasAny(refresh, const {'autoRefreshFavorite', 'refreshFavoriteOnResume', 'autoRefreshInterval'})) {
        final enabled = refresh['autoRefreshFavorite'];
        final interval = _int(refresh['autoRefreshInterval']);
        final onResume = refresh['refreshFavoriteOnResume'];
        await preferences.update(
          (p) => p.copyWith(
            refreshOnResume: onResume is bool ? onResume : p.refreshOnResume,
            // The sender's master switch wins over its interval: off is off.
            autoRefreshMinutes: enabled == false
                ? 0
                : interval == null
                ? p.autoRefreshMinutes
                : interval.clamp(0, 24 * 60),
          ),
        );
        applied = true;
      }
    }

    if (wanted('page')) {
      final page = _section(payload, 'page');
      if (page != null) {
        final branches = _stringList(page['shellBranches']).where((id) => ShellBranch.maybeFromId(id) != null).toList();
        final restore = page['restoreLastTab'];
        final launch = page['launchBranch'] == null ? null : AppLaunchBranch.fromId(page['launchBranch']?.toString());
        final launchKnown = page['launchBranch'] == null
            ? null
            : ShellBranch.maybeFromId(page['launchBranch']?.toString() ?? '');
        if (branches.isNotEmpty || restore is bool || launchKnown != null) {
          await preferences.update(
            (p) => p.copyWith(
              shellBranches: branches.isNotEmpty ? branches : p.shellBranches,
              restoreLastTab: restore is bool ? restore : p.restoreLastTab,
              launchBranch: launchKnown == null ? p.launchBranch : launch,
            ),
          );
          applied = true;
        }
      }
    }

    if (wanted('proxy')) {
      final proxy = _section(payload, 'proxy');
      if (proxy != null && _hasAny(proxy, const {'enableProxy', 'proxyHost', 'proxyPort'})) {
        final enabled = proxy['enableProxy'];
        final host = proxy['proxyHost']?.toString().trim();
        final port = _int(proxy['proxyPort']);
        await preferences.update(
          (p) => p.copyWith(
            proxyEnabled: enabled is bool ? enabled : p.proxyEnabled,
            proxyHost: host != null && host.isNotEmpty ? host : p.proxyHost,
            proxyPort: port == null ? p.proxyPort : port.clamp(1, 65535),
          ),
        );
        applied = true;
      }
    }

    if (wanted('loading')) {
      // This app's own builds carry a `loading` section; a 3.x sender keeps
      // the same answer inside its `theme` section, so read both.
      final styleId =
          _section(payload, 'loading')?['loadingStyle']?.toString() ??
          _section(payload, 'theme')?['loadingStyle']?.toString();
      final style = _loadingStyleFromReference(styleId);
      if (style != null) {
        await preferences.update((p) => p.copyWith(loadingStyle: style));
        applied = true;
      }
    }

    if (wanted('webdav') && webdav != null) {
      final servers = _section(payload, 'webdav')?['servers'];
      if (servers is List) {
        for (final server in servers.whereType<Map<Object?, Object?>>()) {
          await webdav(Map<String, dynamic>.from(server));
          applied = true;
        }
      }
    }

    if (wanted('accounts') && accounts != null) {
      final credentials = _section(payload, 'accounts')?['credentials'];
      if (credentials is List) {
        for (final entry in credentials.whereType<Map<Object?, Object?>>()) {
          await accounts(Map<String, dynamic>.from(entry));
          applied = true;
        }
      }
    }
    return applied;
  }

  /// Whether [section] carries at least one of [keys].
  static bool _hasAny(Map<String, dynamic> section, Set<String> keys) => keys.any(section.containsKey);

  /// Parses the 3.x room-card appearance JSON into the fields this app's
  /// card style holds; null when the map carries none of them.
  static ({double? radius, bool? showPlatform, bool? showAudience, bool? showAnchor})? _referenceAppearance(
    Object? raw,
  ) {
    if (raw is! Map) {
      return null;
    }
    final rawRadius = raw['cornerRadius'] ?? raw['cardBorderRadius'];
    final radius = rawRadius is num ? rawRadius.toDouble() : null;
    final platform = raw['showPlatformBadge'] ?? raw['showPlatform'];
    final audience = raw['showAudience'];
    // The app draws the anchor line (avatar and name) as one; the sender's
    // anchor-name flag is the intent, its avatar flag the fallback.
    final anchor = raw['showAnchorName'] ?? raw['showAvatar'];
    if (radius == null && platform is! bool && audience is! bool && anchor is! bool) {
      return null;
    }
    return (
      radius: radius,
      showPlatform: platform is bool ? platform : null,
      showAudience: audience is bool ? audience : null,
      showAnchor: anchor is bool ? anchor : null,
    );
  }

  /// The 3.x loading-style identifier → this app's [LoadingStyle]; its own
  /// ids pass through, the 3.x `default` is its shimmer and every other 3.x
  /// key names a spinner. Unknown ids change nothing (null).
  static LoadingStyle? _loadingStyleFromReference(String? raw) {
    final id = raw?.trim() ?? '';
    if (id.isEmpty) {
      return null;
    }
    return switch (id) {
      'shimmer' => LoadingStyle.shimmer,
      'spinner' => LoadingStyle.spinner,
      'none' => LoadingStyle.none,
      _referenceDefaultLoadingStyle => LoadingStyle.shimmer,
      // A real peer's other keys are the 3.x spinner animations; junk from
      // anywhere else costs at most a cosmetic placeholder flip.
      _ => LoadingStyle.spinner,
    };
  }

  /// Parses a count that may arrive as an int or a numeric string; null when
  /// neither.
  static int? _int(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw?.toString().trim() ?? '');
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
          area: areaName.isEmpty ? null : LiveArea.normalized(platform: platform, areaId: areaName, areaName: areaName),
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
    if (raw is List)
      for (final entry in raw)
        if (entry != null) entry.toString(),
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
