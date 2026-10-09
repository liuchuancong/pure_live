import io

p = 'packages/providers/huya/lib/src/huya_source.dart'
s = io.open(p, encoding='utf-8').read()

old = "final class HuyaSource implements FeedCapability, ResolveCapability {"
new = "final class HuyaSource implements FeedCapability, BrowseCapability, SearchCapability, ResolveCapability {"
assert old in s, 'class decl'
s = s.replace(old, new)

old = """  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final result = await _client.getJson(
      'https://mp.huya.com/cache.php',
      headers: _webHeaders,
      queryParameters: <String, Object?>{
        'm': 'Live',
        'do': 'profileRoom',
        'roomid': ref.contentId,
        'showSecret': '1',
      },
    );
    if (result['status'] != 200) {
      throw StateError('Huya room ${ref.contentId} answered status ${result['status']}');
    }
    final data = result['data'] as Map<String, Object?>?;
    final stream = data?['stream'] as Map<String, Object?>?;
    final bases = stream?['baseSteamInfoList'] as List?;
    if (stream == null || bases == null || bases.isEmpty) {
      throw StateError('Huya room ${ref.contentId} is not streaming');
    }

    // First usable base entry: each one carries the same stream on a different
    // CDN; line selection is a later slice, so the first entry is the line.
    final Map<String, Object?> entry = bases.first! as Map<String, Object?>;"""
new = """  /// The profileRoom document for one room. Shared by resolve and detail: it
  /// is the one endpoint that describes a room fully.
  Future<Map<String, Object?>?> _profileRoom(String roomId) async {
    final result = await _client.getJson(
      'https://mp.huya.com/cache.php',
      headers: _webHeaders,
      queryParameters: <String, Object?>{
        'm': 'Live',
        'do': 'profileRoom',
        'roomid': roomId,
        'showSecret': '1',
      },
    );
    if (result['status'] != 200) {
      throw StateError('Huya room $roomId answered status ${result['status']}');
    }
    return result['data'] as Map<String, Object?>?;
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) {
    // An empty category is the home listing, which for huya is the recommend
    // feed; a named category is its game id from the category tree.
    final category = query.category;
    if (category == null || category.isEmpty) {
      return feed(query.page);
    }
    return _listRooms(<String, Object?>{'gameId': category}, query.page);
  }

  Future<PageResult<ContentSummary>> _listRooms(Map<String, Object?> extra, PageRequest page) async {
    final result = await _client.getJson(
      'https://www.huya.com/cache.php',
      headers: _webHeaders,
      queryParameters: <String, Object?>{
        'm': 'LiveList',
        'do': 'getLiveListByPage',
        'tagAll': 0,
        ...extra,
        'page': page.page,
      },
    );
    final data = result['data'] as Map<String, Object?>?;
    final rows = data?['datas'] as List?;
    if (data == null || rows == null) {
      throw FormatException('Huya room list answered without data.datas (page ${page.page})');
    }
    final items = <ContentSummary>[for (final row in rows) _summaryFromListRow(row! as Map<String, Object?>)];
    final hasMore = _asInt(data['page']) < _asInt(data['totalPage']);
    return PageResult<ContentSummary>(items: items, page: page.page, pageSize: page.pageSize, hasMore: hasMore);
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final data = await _profileRoom(ref.contentId);
    final liveData = data?['liveData'] as Map<String, Object?>?;
    final introduction = '${liveData?['introduction'] ?? ''}';
    return ContentDetail(
      summary: ContentSummary(
        ref: ref,
        title: introduction.isNotEmpty ? introduction : '${liveData?['sRoomName'] ?? ref.contentId}',
        subtitle: '${liveData?['nick'] ?? ''}',
        cover: liveData?['screenshot']?.toString(),
        metadata: ContentMetadata(popularity: _asInt(liveData?['userCount'])),
      ),
      description: introduction,
    );
  }

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    // Rows here are capped at 50 and paging runs through start, so hasMore is
    // "this page came back full", the only signal the endpoint gives.
    final pageSize = query.page.pageSize.clamp(1, 50);
    final result = await _client.getJson(
      'https://search.cdn.huya.com/',
      headers: <String, String>{'user-agent': _userAgent},
      queryParameters: <String, Object?>{
        'm': 'Search',
        'do': 'getSearchContent',
        'q': query.keyword,
        'uid': 0,
        'v': 4,
        'typ': -5,
        'livestate': 0,
        'rows': pageSize,
        'start': (query.page.page - 1) * pageSize,
      },
    );
    final docs = ((result['response'] as Map<String, Object?>?)?['3'] as Map<String, Object?>?)?['docs'] as List?;
    final items = <ContentSummary>[
      if (docs != null)
        for (final doc in docs) _summaryFromSearchRow(doc! as Map<String, Object?>),
    ];
    return PageResult<ContentSummary>(
      items: items,
      page: query.page.page,
      pageSize: pageSize,
      hasMore: docs != null && items.length >= pageSize,
    );
  }

  ContentSummary _summaryFromSearchRow(Map<String, Object?> row) {
    var cover = '${row['game_screenshot'] ?? ''}';
    if (cover.isNotEmpty && !cover.contains('?')) {
      cover += '?x-oss-process=style/w338_h190&';
    }
    final title = '${row['game_introduction'] ?? ''}';
    final nick = '${row['game_nick'] ?? ''}';
    final area = '${row['gameName'] ?? ''}';
    return ContentSummary(
      ref: ContentRef(sourceId: huyaSourceId, contentId: '${row['room_id'] ?? ''}', kind: ContentKind.liveRoom),
      title: title.isNotEmpty ? title : '${row['game_roomName'] ?? ''}',
      subtitle: <String>[if (nick.isNotEmpty) nick, if (area.isNotEmpty) area].join(' · '),
      cover: cover.isNotEmpty ? cover : row['game_imgUrl']?.toString(),
    );
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final data = await _profileRoom(ref.contentId);
    final stream = data?['stream'] as Map<String, Object?>?;
    final bases = stream?['baseSteamInfoList'] as List?;
    if (stream == null || bases == null || bases.isEmpty) {
      throw StateError('Huya room ${ref.contentId} is not streaming');
    }

    // First usable base entry: each one carries the same stream on a different
    // CDN; line selection is a later slice, so the first entry is the line.
    final Map<String, Object?> entry = bases.first! as Map<String, Object?>;"""
assert old in s, 'resolve refactor'
s = s.replace(old, new)

old = """  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) async {
    final result = await _client.getJson(
      'https://www.huya.com/cache.php',
      headers: _webHeaders,
      queryParameters: <String, Object?>{'m': 'LiveList', 'do': 'getLiveListByPage', 'tagAll': 0, 'page': page.page},
    );
    final data = result['data'] as Map<String, Object?>?;
    final rows = data?['datas'] as List?;
    if (data == null || rows == null) {
      throw FormatException('Huya feed answered without data.datas (page ${page.page})');
    }
    final items = <ContentSummary>[for (final row in rows) _summaryFromListRow(row! as Map<String, Object?>)];
    final hasMore = _asInt(data['page']) < _asInt(data['totalPage']);
    return PageResult<ContentSummary>(items: items, page: page.page, pageSize: page.pageSize, hasMore: hasMore);
  }"""
new = """  @override
  Future<PageResult<ContentSummary>> feed(PageRequest page) => _listRooms(const <String, Object?>{}, page);"""
assert old in s, 'feed collapse'
s = s.replace(old, new)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('huya extended')
