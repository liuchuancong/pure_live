// Module: lib/src/spider_contract.dart
// Purpose: The Dart mirror of the TVBox spider interface, and the mappers from
// its raw JSON answers to the shapes the platform consumes.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/adr/0017-tvbox-python-runtime.md and the reference
// webtv-main chaquo/src/main/python/base/spider.py. A spider - whichever
// runtime executes it - answers these methods with plain JSON maps. The
// contract here is deliberately the spider's own vocabulary (vod, class, flag,
// play_url): the adapter layer, not each spider, is where those names map to
// ContentRef and MediaTicket. Field parsing is lenient on purpose; TVBox
// configs in the wild vary, and a missing optional field degrades to null
// rather than failing the whole page.

/// One execution environment able to drive a spider. A Python host, the JS
/// host or a debug in-process interpreter implements this; the provider
/// below never knows which.
abstract interface class SpiderHandle {
  /// Brings the spider up. [extend] is the repo's ext payload for this site.
  Future<Map<String, Object?>?> init(String extend);

  /// The home page: classes (category ids) plus featured vods.
  Future<Map<String, Object?>?> homeContent(Map<String, Object?> filter);

  /// Featured vods only, when a spider splits them from homeContent.
  Future<Map<String, Object?>?> homeVideoContent();

  /// One category page. [pg] is a page STRING in the spider vocabulary and
  /// stays one here: several spiders treat it as text.
  Future<Map<String, Object?>?> categoryContent(String tid, String pg, bool filter, Map<String, Object?> extend);

  /// The full record of one vod: info plus its play flags and episodes.
  Future<Map<String, Object?>?> detailContent(List<String> ids);

  /// Search. [quick] marks the fast path some spiders serve from cache.
  Future<Map<String, Object?>?> searchContent(String key, bool quick, String pg);

  /// The play answer for one episode: play url, headers, and whether the url
  /// still needs a webview sniffer (parse) or a jx resolver.
  Future<Map<String, Object?>?> playerContent(String flag, String id, bool vipFlags);

  /// Live channel lists for spiders that serve them.
  Future<Map<String, Object?>?> liveContent(String url);

  /// Releases whatever the spider holds.
  Future<void> destroy();
}

/// One category a spider exposes on its home page.
final class SpiderClass {
  const SpiderClass({required this.typeId, required this.typeName});

  final String typeId;
  final String typeName;
}

/// One vod card, as lists and search results carry it.
final class SpiderVod {
  const SpiderVod({required this.vodId, required this.vodName, this.vodPic, this.remarks, this.typeName});

  final String vodId;
  final String vodName;
  final String? vodPic;
  final String? remarks;
  final String? typeName;
}

/// One page of vods, with the spider's own page accounting kept so "load more"
/// can ask for the next page in the source's vocabulary.
final class SpiderPage {
  const SpiderPage({required this.vods, this.page, this.pageCount, this.limit, this.total});

  final List<SpiderVod> vods;
  final int? page;
  final int? pageCount;
  final int? limit;
  final int? total;

  bool get hasMore => pageCount != null && page != null ? page! < pageCount! : vods.isNotEmpty;
}

/// One playable episode inside one play flag (source line).
final class SpiderEpisode {
  const SpiderEpisode({required this.flag, required this.name, required this.url});

  /// The play flag this episode belongs to, for example 'qiyi' or 'm3u8'.
  final String flag;
  final String name;
  final String url;
}

/// One vod's full record: card fields plus its episodes grouped by flag.
final class SpiderDetail {
  const SpiderDetail({required this.vod, required this.episodes, this.description});

  final SpiderVod vod;

  /// Every episode of every flag, in the order the spider returned them.
  final List<SpiderEpisode> episodes;
  final String? description;
}

/// The play answer: where to open the stream and what opening it requires.
final class SpiderPlay {
  const SpiderPlay({
    required this.playUrl,
    this.headers = const <String, String>{},
    this.parse = false,
    this.jx = false,
  });

  final String playUrl;
  final Map<String, String> headers;

  /// True when playUrl is a web page a sniffer must watch, not a media url.
  final bool parse;

  /// True when playUrl names a jx (json resolver) endpoint.
  final bool jx;
}

/// Reads one vod card out of whatever map a spider produced. Lenient: aliases
/// like `vod_id`/`id` and `vod_name`/`name` both occur in the wild.
SpiderVod parseSpiderVod(Map<String, Object?> json) {
  return SpiderVod(
    vodId: '${_firstOf(json, const ['vod_id', 'id']) ?? ''}',
    vodName: '${_firstOf(json, const ['vod_name', 'name']) ?? ''}',
    vodPic: _firstOf(json, const ['vod_pic', 'pic'])?.toString(),
    remarks: _firstOf(json, const ['vod_remarks', 'remarks'])?.toString(),
    typeName: _firstOf(json, const ['type_name', 'typeName'])?.toString(),
  );
}

/// Reads one page out of a categoryContent / searchContent / homeContent map.
SpiderPage parseSpiderPage(Map<String, Object?> json) {
  final list = json['list'];
  final vods = <SpiderVod>[
    if (list is List)
      for (final row in list)
        if (row is Map) parseSpiderVod(Map<String, Object?>.from(row)),
  ];
  return SpiderPage(
    vods: vods,
    page: _asInt(json['page']),
    pageCount: _asInt(json['pagecount']),
    limit: _asInt(json['limit']),
    total: _asInt(json['total']),
  );
}

/// Reads the classes array of a homeContent map.
List<SpiderClass> parseSpiderClasses(Map<String, Object?> json) {
  final classes = json['class'];
  return <SpiderClass>[
    if (classes is List)
      for (final row in classes)
        if (row is Map)
          SpiderClass(
            typeId: '${row['type_id'] ?? row['id'] ?? ''}',
            typeName: '${row['type_name'] ?? row['name'] ?? ''}',
          ),
  ];
}

/// Reads one detailContent answer: the vod plus its episodes, each episode's
/// url resolved from the `name#url` pairs vod_play_url packs per flag.
SpiderDetail parseSpiderDetail(Map<String, Object?> json) {
  final list = json['list'];
  final first = list is List && list.isNotEmpty && list.first is Map
      ? Map<String, Object?>.from(list.first as Map)
      : json;
  final vod = parseSpiderVod(first);
  final flags = '${first['vod_play_from'] ?? ''}'.split(r'$$$');
  final playUrls = '${first['vod_play_url'] ?? ''}'.split(r'$$$');
  final episodes = <SpiderEpisode>[];
  for (var flagIndex = 0; flagIndex < flags.length; flagIndex++) {
    final flag = flags[flagIndex].trim();
    final block = flagIndex < playUrls.length ? playUrls[flagIndex] : '';
    for (final pair in block.split('#')) {
      if (pair.trim().isEmpty) {
        continue;
      }
      final separator = pair.indexOf(r'$');
      if (separator <= 0) {
        continue;
      }
      episodes.add(
        SpiderEpisode(flag: flag, name: pair.substring(0, separator).trim(), url: pair.substring(separator + 1).trim()),
      );
    }
  }
  return SpiderDetail(vod: vod, episodes: episodes, description: first['vod_content']?.toString());
}

/// Reads one playerContent answer. A missing play url is kept as empty: the
/// caller decides whether an empty answer with parse=1 is worth a sniffer, and
/// a thrown error here would hide what the spider actually said.
SpiderPlay parseSpiderPlay(Map<String, Object?> json) {
  final data = json['data'];
  final body = data is Map ? Map<String, Object?>.from(data) : json;
  final headers = <String, String>{};
  final rawHeaders = body['headers'];
  if (rawHeaders is Map) {
    for (final entry in rawHeaders.entries) {
      headers['${entry.key}'] = '${entry.value}';
    }
  }
  return SpiderPlay(
    playUrl: '${body['play_url'] ?? body['url'] ?? ''}',
    headers: headers,
    parse: _asInt(body['parse']) == 1,
    jx: _asInt(body['jx']) == 1,
  );
}

Object? _firstOf(Map<String, Object?> json, List<String> names) {
  for (final name in names) {
    final value = json[name];
    if (value != null && '$value'.isNotEmpty) {
      return value;
    }
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('${value ?? ''}');
}
