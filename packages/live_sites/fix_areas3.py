import io

def edit(path, pairs):
    with io.open(path, 'r', encoding='utf-8') as f:
        t = f.read()
    for a, b in pairs:
        assert a in t, (path, a[:70])
        t = t.replace(a, b)
    with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(t)

# bilibili: `Area/getList` answers a bare array under `data`, which the
# object-shaped envelope check rejects.
edit('lib/src/platforms/bilibili/parsers/bilibili_parser.dart', [
    ("""  /// The `nav` payload for an anonymous session.""",
     """  /// Like [checked], but for the endpoints whose `data` is an array.
  ///
  /// `Area/getList` answers `{"code":0,"data":[…]}` — the same envelope with
  /// a list where the others put an object — so the object-shaped rule
  /// rejects an answer that is perfectly fine. The codes and the error
  /// mapping stay identical, because the envelope is what they describe.
  static List<Object?> checkedList(String body, {int status = 200, String what = 'response'}) {
    if (status == 412) {
      throw SiteRateLimitedError('bilibili $what: request intercepted (412)');
    }
    if (status != 200) {
      throw SiteApiChangedError('bilibili $what: HTTP $status');
    }
    final Object? root;
    try {
      root = jsonDecode(body);
    } on FormatException catch (error) {
      throw SiteApiChangedError('bilibili $what: body is not JSON (${error.message})');
    }
    if (root is! Map<String, Object?>) {
      throw SiteApiChangedError('bilibili $what: body is not an object');
    }
    final code = (root['code'] as num?)?.toInt();
    if (code != 0) {
      final message = root['message']?.toString() ?? root['msg']?.toString() ?? '';
      throw SiteApiChangedError('bilibili $what: code $code, $message');
    }
    final data = root['data'];
    return data is List ? data : const <Object?>[];
  }

  /// The `nav` payload for an anonymous session."""),
    ("""  /// `Area/getList` payload → the top-level area list.
  static List<LiveArea> areaList(Map<String, Object?> data) {
    final list = data['data'];
    final areas = <LiveArea>[];
    if (list is List) {
      for (final item in list) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        areas.add(
          LiveArea(
            id: item['area_id']?.toString() ?? '',
            name: item['area_name']?.toString() ?? '',
            parentId: item['parent_id']?.toString(),
            sort: (item['sort'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    return areas;
  }""",
     """  /// `Area/getList` payload → one level of the area tree.
  ///
  /// The rows carry `area_id`, `area_name`, `parent_id` and `sort`; a row
  /// whose id is missing is skipped, because an area nobody can browse by is
  /// a picker entry that does nothing.
  static List<LiveArea> areaList(List<Object?> rows) => [
    for (final row in rows)
      if (row is Map<String, Object?>)
        if (SiteText.trimmed(row['area_id']) case final id when id.isNotEmpty)
          LiveArea(
            id: id,
            name: SiteText.title(SiteText.text(row['area_name'])),
            parentId: SiteText.trimmed(row['parent_id']).isEmpty ? null : SiteText.trimmed(row['parent_id']),
            sort: SiteCounts.integer(row['sort']) ?? 0,
          ),
  ];"""),
])

edit('lib/src/platforms/bilibili/bilibili_site.dart', [
    ("""  /// One level of the area tree.
  Future<List<LiveArea>> _areas(String parentId) async {
    final root = await _get('/room/v1/Area/getList', {
      'need_entrance': '1',
      'parent_id': parentId,
    });
    return BilibiliParser.areaList(root);
  }""",
     """  /// One level of the area tree.
  Future<List<LiveArea>> _areas(String parentId) async {
    final response = await session.send(
      'api.live.bilibili.com',
      '/room/v1/Area/getList',
      {'need_entrance': '1', 'parent_id': parentId},
    );
    return BilibiliParser.areaList(
      BilibiliParser.checkedList(response.text, status: response.statusCode, what: 'Area/getList'),
    );
  }"""),
])

# kuaishou: the catalogue is the capability, not a plain method.
edit('lib/src/platforms/kuaishou/kuaishou_site.dart', [
    ("final class KuaishouSite with SiteRoomGuard implements LiveSite, LiveDirectoryCapability, LiveSearchCapability, LiveDanmakuCapability {",
     "final class KuaishouSite\n    with SiteRoomGuard\n    implements LiveSite, LiveDirectoryCapability, LiveSearchCapability, LiveDanmakuCapability, LiveAreaCatalog {"),
    ("""  /// The game categories of the site's own boards, which is what a caller
  /// browses by before it has an area to ask for.
  ///
  /// The endpoint pages its categories, so a first page that still reports
  /// more is followed: a caller that asks for the categories gets all of
  /// them, because a half-filled side bar is worse than a slow one.
  Future<List<LiveArea>> getAreas({String type = '1', int maxPages = 4}) async {""",
     """  /// The game categories of the site's own boards, which is what a caller
  /// browses by before it has an area to ask for.
  ///
  /// The endpoint pages its categories, so a first page that still reports
  /// more is followed: a caller that asks for the categories gets all of
  /// them, because a half-filled side bar is worse than a slow one.
  @override
  Future<List<LiveArea>> getAreas() => _areas(type: '1');"""),
])
print('ok')
