import io

def edit(path, pairs):
    with io.open(path, 'r', encoding='utf-8') as f:
        t = f.read()
    for a, b in pairs:
        assert a in t, (path, a[:70])
        t = t.replace(a, b)
    with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(t)

# The area rows use `id`/`name` (the tree endpoint) with `area_id`/`area_name`
# as the detail payload's spelling: read both.
edit('lib/src/platforms/bilibili/parsers/bilibili_parser.dart', [
    ("""  static List<LiveArea> areaList(List<Object?> rows) => [
    for (final row in rows)
      if (row is Map<String, Object?>)
        if (SiteText.trimmed(row['area_id']) case final id when id.isNotEmpty)
          LiveArea(
            id: id,
            name: SiteText.title(SiteText.text(row['area_name'])),
            parentId: SiteText.trimmed(row['parent_id']).isEmpty ? null : SiteText.trimmed(row['parent_id']),
            sort: SiteCounts.integer(row['sort']) ?? 0,
          ),
  ];""",
     """  static List<LiveArea> areaList(List<Object?> rows) => [
    for (final row in rows)
      if (row is Map<String, Object?>)
        if (SiteText.trimmed(row['id'] ?? row['area_id']) case final id when id.isNotEmpty)
          LiveArea(
            id: id,
            name: SiteText.title(SiteText.text(row['name'] ?? row['area_name'])),
            parentId: SiteText.trimmed(row['parent_id']).isEmpty ? null : SiteText.trimmed(row['parent_id']),
            sort: SiteCounts.integer(row['sort']) ?? 0,
          ),
  ];

  /// `Area/getList` rows → the whole area tree, parents first.
  ///
  /// One request answers both levels: each parent carries its children in a
  /// nested `list`, which is what the site's own side bar draws. The children
  /// get their parent's id when they do not carry one, so `parentId` is
  /// always usable for grouping.
  static List<LiveArea> areaTree(List<Object?> parents) {
    final areas = <LiveArea>[];
    for (final parent in parents) {
      if (parent is! Map<String, Object?>) {
        continue;
      }
      final parentAreas = areaList([parent]);
      if (parentAreas.isEmpty) {
        continue;
      }
      final head = parentAreas.first;
      areas.add(head);
      for (final child in areaList(SiteJson.list(parent['list']))) {
        areas.add(child.parentId == null ? child.copyWith(parentId: head.id) : child);
      }
    }
    return areas;
  }"""),
])

edit('lib/src/platforms/bilibili/bilibili_site.dart', [
    ("""  /// The endpoint answers the *parent* areas only; each parent's children
  /// come from a second request, and a picker needs both (the parents group
  /// the children, which is what the area's parent id records). Two levels is
  /// all the site has — asking a child for its own children answers nothing —
  /// so the walk stops there rather than recursing.
  @override
  Future<List<LiveArea>> getAreas() async {
    final parents = await _areas('0');
    final areas = <LiveArea>[...parents];
    for (final parent in parents) {
      if (parent.id.isEmpty) {
        continue;
      }
      for (final child in await _areas(parent.id)) {
        areas.add(child.parentId == null ? child.copyWith(parentId: parent.id) : child);
      }
    }
    return areas;
  }""",
     """  /// One request answers the whole tree: the parents, each carrying its
  /// children in a nested list — which is exactly what the site's own side
  /// bar draws, and why a second request per parent (as this first did)
  /// wasted a round trip each.
  @override
  Future<List<LiveArea>> getAreas() async {
    final response = await session.getRaw('/room/v1/Area/getList', {
      'need_entrance': '1',
      'parent_id': '0',
    });
    return BilibiliParser.areaTree(
      BilibiliParser.checkedList(response.text, status: response.statusCode, what: 'Area/getList'),
    );
  }"""),
    ("""  /// One level of the area tree.
  ///
  /// The answer's `data` is an array, so it is read with the list-shaped
  /// envelope rule rather than through the object-shaped helper the rest of
  /// this adapter uses — the codes and the error mapping are the same.
  Future<List<LiveArea>> _areas(String parentId) async {
    final response = await session.getRaw('/room/v1/Area/getList', {
      'need_entrance': '1',
      'parent_id': parentId,
    });
    return BilibiliParser.areaList(
      BilibiliParser.checkedList(response.text, status: response.statusCode, what: 'Area/getList'),
    );
  }

""", ""),
])

edit('lib/src/platforms/kuaishou/kuaishou_site.dart', [
    ("""    implements LiveSite, LiveDirectoryCapability, LiveSearchCapability, LiveDanmakuCapability {""",
     """    implements\n        LiveSite,\n        LiveDirectoryCapability,\n        LiveSearchCapability,\n        LiveDanmakuCapability,\n        LiveAreaCatalog {"""),
])
print('ok')
