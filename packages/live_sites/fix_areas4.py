import io

def edit(path, pairs):
    with io.open(path, 'r', encoding='utf-8') as f:
        t = f.read()
    for a, b in pairs:
        assert a in t, (path, a[:70])
        t = t.replace(a, b)
    with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(t)

edit('lib/src/platforms/bilibili/parsers/bilibili_parser.dart', [
    ("""  /// The envelope rule for endpoints a *guest* is allowed to call.""",
     """  /// Like [checked], but for the endpoints whose `data` is an array.
  ///
  /// `Area/getList` answers `{"code":0,"data":[…]}` — the same envelope with
  /// a list where the others put an object — so the object-shaped rule
  /// rejects an answer that is perfectly fine.
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

  /// The envelope rule for endpoints a *guest* is allowed to call."""),
])

old_area = """  /// `Area/getList` payload → the top-level area list.
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
  }"""
new_area = """  /// `Area/getList` rows → one level of the area tree.
  ///
  /// A row without an area id is skipped: an area nobody can browse by is a
  /// picker entry that does nothing.
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
  ];"""
assert old_area in t or True
with io.open('lib/src/platforms/bilibili/parsers/bilibili_parser.dart', 'r', encoding='utf-8') as f:
    t = f.read()
assert old_area in t
t = t.replace(old_area, new_area)
with io.open('lib/src/platforms/bilibili/parsers/bilibili_parser.dart', 'w', encoding='utf-8', newline='\n') as f:
    f.write(t)

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
  ///
  /// The answer's `data` is an array, so it is read with the list-shaped
  /// envelope rule rather than through [_get] (which insists on an object).
  Future<List<LiveArea>> _areas(String parentId) async {
    final response = await session.getRaw('/room/v1/Area/getList', {
      'need_entrance': '1',
      'parent_id': parentId,
    });
    return BilibiliParser.areaList(
      BilibiliParser.checkedList(response.text, status: response.statusCode, what: 'Area/getList'),
    );
  }"""),
])

edit('lib/src/platforms/kuaishou/kuaishou_site.dart', [
    ("final class KuaishouSite with SiteRoomGuard implements LiveSite, LiveDirectoryCapability, LiveSearchCapability, LiveDanmakuCapability {",
     "final class KuaishouSite\n    with SiteRoomGuard\n    implements\n        LiveSite,\n        LiveDirectoryCapability,\n        LiveSearchCapability,\n        LiveDanmakuCapability,\n        LiveAreaCatalog {"),
    ("""  Future<List<LiveArea>> getAreas({String type = '1', int maxPages = 4}) async {""",
     """  @override
  Future<List<LiveArea>> getAreas() => _areas(type: '1');

  Future<List<LiveArea>> _areas({String type = '1', int maxPages = 4}) async {"""),
])
print('ok')
