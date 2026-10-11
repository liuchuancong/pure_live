import io

def edit(path, pairs):
    with io.open(path, 'r', encoding='utf-8') as f:
        t = f.read()
    for a, b in pairs:
        assert a in t, (path, a[:60])
        t = t.replace(a, b)
    with io.open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(t)

# --- bilibili: the two-level area list the site's own side bar is built from.
edit('lib/src/platforms/bilibili/bilibili_site.dart', [
    ("final class BilibiliSite with SiteRoomGuard implements LiveSite, LiveDanmakuCapability, LiveDirectoryCapability, LiveSearchCapability {",
     "final class BilibiliSite\n    with SiteRoomGuard\n    implements LiveSite, LiveDanmakuCapability, LiveDirectoryCapability, LiveSearchCapability, LiveAreaCatalog {"),
    ("""  /// The anonymous ranked list, then the recommendation feed.""",
     """  /// The site's area tree, flattened.
  ///
  /// The endpoint answers the *parent* areas only; each parent's children
  /// come from a second request, and a picker needs both (the parents group
  /// the children, which is what `parentId` records). Two levels is all the
  /// site has — asking a child for its own children answers nothing — so the
  /// walk stops there rather than recursing forever.
  @override
  Future<List<LiveArea>> getAreas() async {
    final response = await http.send(
      LiveRequest.get(
        Uri.https(BilibiliConstants.apiHost, '/room/v1/Area/getList', {
          'need_entrance': '1',
          'parent_id': '0',
        }),
        headers: session.headers(),
        site: siteId,
      ),
    );
    final root = BilibiliParser.checked(response.text, status: response.statusCode, what: 'Area/getList');
    final parents = BilibiliParser.areaList(root);
    final areas = <LiveArea>[...parents];
    for (final parent in parents) {
      if (parent.id.isEmpty) {
        continue;
      }
      final childResponse = await http.send(
        LiveRequest.get(
          Uri.https(BilibiliConstants.apiHost, '/room/v1/Area/getList', {'parent_id': parent.id}),
          headers: session.headers(),
          site: siteId,
        ),
      );
      final childRoot = BilibiliParser.checked(
        childResponse.text,
        status: childResponse.statusCode,
        what: 'Area/getList(${parent.id})',
      );
      for (final child in BilibiliParser.areaList(childRoot)) {
        areas.add(child.parentId == null ? child.copyWith(parentId: parent.id) : child);
      }
    }
    return areas;
  }

  /// The anonymous ranked list, then the recommendation feed."""),
])

# --- acfun: the channel filters its own side bar shows.
edit('lib/src/platforms/acfun/acfun_site.dart', [
    ("final class AcfunSite with SiteRoomGuard implements LiveSite, LiveDirectoryCapability {",
     "final class AcfunSite with SiteRoomGuard implements LiveSite, LiveDirectoryCapability, LiveAreaCatalog {"),
    ("""  /// Every live room, by popularity.""",
     """  /// The site's channel filters, flattened.
  ///
  /// They arrive with any listing answer (`channelFilters`), which is why
  /// this asks for the smallest possible one — a single room — rather than a
  /// dedicated catalogue endpoint the site does not have. The parent grouping
  /// is the display group's name, kept in `parentId` so a picker can group
  /// the same way the site does.
  @override
  Future<List<LiveArea>> getAreas() async {
    final url = Uri.https('live.acfun.cn', '/api/channel/list', {'count': '1'});
    final response = await http.send(LiveRequest.get(url, headers: AcfunParser.apiHeaders, site: siteId));
    final root = AcfunParser.root(response.text, status: response.statusCode, what: 'channel/list');
    return AcfunParser.channelAreas(root);
  }

  /// Every live room, by popularity."""),
])
print('ok')
