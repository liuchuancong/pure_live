import io

p = 'lib/src/platforms/douyu/parsers/douyu_parser.dart'
with io.open(p, 'r', encoding='utf-8') as f: t = f.read()

addition = '''
  /// `japi/search/api/searchShow` → the rooms matching a keyword.
  ///
  /// The rows are the same shape as the directory's *older* endpoints
  /// (`roomName`, `nickName`, `roomSrc`), not the `rn`/`nn`/`rs16` spelling
  /// the directory itself uses — one platform, two vocabularies, which is
  /// why the two parsers stay separate rather than sharing a mapper.
  ///
  /// `isLive` 1 with `roomType` 0 is on air; `roomType` 1 is a rebroadcast
  /// channel and `roomType` 2 a recording, and both are a *replay* rather
  /// than live.
  static LivePage<LiveRoom> searchRooms(Map<String, Object?> root) {
    final data = SiteJson.object(root['data']);
    final rows = SiteJson.objects(data['relateShow']);
    final rooms = <LiveRoom>[
      for (final item in rows)
        if (SiteText.trimmed(item['rid']) case final id when id.isNotEmpty) _searchRoom(item, id),
    ];
    return LivePage<LiveRoom>(items: rooms, hasMore: rows.length >= 30);
  }

  static LiveRoom _searchRoom(Map<String, Object?> item, String id) {
    final live = SiteCounts.integer(item['isLive']) == 1;
    final roomType = SiteCounts.integer(item['roomType']) ?? 0;
    return LiveRoom(
      platform: SiteIds.douyu,
      roomId: id,
      title: SiteText.title(SiteText.text(item['roomName'])),
      nick: SiteText.title(SiteText.text(item['nickName'])),
      avatar: SiteText.trimmed(item['avatar']).isEmpty ? null : SiteText.trimmed(item['avatar']),
      cover: SiteText.trimmed(item['roomSrc']).isEmpty ? null : SiteText.trimmed(item['roomSrc']),
      areaName: SiteText.trimmed(item['cateName']),
      watching: SiteCounts.scaled(item['hot']),
      status: live ? (roomType == 0 ? LiveStatus.live : LiveStatus.replay) : LiveStatus.offline,
    );
  }

  /// `japi/search/api/searchUser` → the streamers matching a keyword.
  ///
  /// Each row wraps its person in `anchorInfo`, so a row without one (an
  /// advertisement, a game) names nobody and is skipped. The room id is the
  /// anchor's own `rid` — a streamer who is not broadcasting still has one,
  /// which is what makes them followable before they go live.
  static LivePage<LiveAnchor> searchAnchors(Map<String, Object?> root) {
    final data = SiteJson.object(root['data']);
    final rows = SiteJson.objects(data['relateUser']);
    final anchors = <LiveAnchor>[
      for (final item in rows)
        if (SiteJson.object(item['anchorInfo']) case final anchor when anchor.isNotEmpty)
          if (SiteText.trimmed(anchor['rid']) case final id when id.isNotEmpty)
            LiveAnchor(
              id: id,
              roomId: id,
              name: SiteText.title(SiteText.text(anchor['nickName'])),
              avatar: SiteText.trimmed(anchor['avatar']).isEmpty ? null : SiteText.trimmed(anchor['avatar']),
              live: SiteCounts.integer(anchor['isLive']) == 1 && (SiteCounts.integer(anchor['roomType']) ?? 0) == 0,
              count: SiteCounts.scaled(anchor['fansCount'] ?? anchor['fans']),
              areaName: SiteText.trimmed(SiteJson.object(anchor['cateInfo'])['cateName']),
            ),
    ];
    return LivePage<LiveAnchor>(items: anchors, hasMore: rows.length >= 30);
  }
'''
marker = "  /// A directory payload → one page of rooms."
assert marker in t
t = t.replace(marker, addition.strip('\n') + '\n\n' + marker)
with io.open(p, 'w', encoding='utf-8', newline='\n') as f: f.write(t)

p = 'lib/src/platforms/douyu/douyu_site.dart'
with io.open(p, 'r', encoding='utf-8') as f: t = f.read()
t = t.replace("final class DouyuSite with SiteRoomGuard implements LiveSite, LiveDirectoryCapability, LiveAreaCatalog {",
"""final class DouyuSite
    with SiteRoomGuard
    implements LiveSite, LiveDirectoryCapability, LiveAreaCatalog, LiveSearchCapability, LiveAnchorSearch {""")
old = """  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    throw UnimplementedError('douyu search lands with its migration');
  }"""
new = """  /// The rooms matching a keyword, 30 a page.
  @override
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty) {
      return const LivePage<LiveRoom>(items: []);
    }
    final number = page < 1 ? 1 : page;
    return DouyuParser.searchRooms(
      await _getJson('https://www.douyu.com/japi/search/api/searchShow?kw=${Uri.encodeQueryComponent(text)}&page=$number&pageSize=30'),
    );
  }

  /// The streamers matching a keyword, as anchors.
  ///
  /// Douyu searches people through a different endpoint from rooms, and the
  /// two are worth keeping apart: a streamer search returns people who are
  /// not broadcasting, and the old implementation — which only had rooms —
  /// had to invent a room for them.
  @override
  Future<LivePage<LiveAnchor>> searchAnchors(String keyword, {int page = 1}) async {
    final text = keyword.trim();
    if (text.isEmpty) {
      return const LivePage<LiveAnchor>(items: []);
    }
    final number = page < 1 ? 1 : page;
    return DouyuParser.searchAnchors(
      await _getJson(
        'https://www.douyu.com/japi/search/api/searchUser?kw=${Uri.encodeQueryComponent(text)}&page=$number&pageSize=30&filterType=1',
      ),
    );
  }"""
assert old in t
t = t.replace(old, new)
with io.open(p, 'w', encoding='utf-8', newline='\n') as f: f.write(t)
print('ok')
