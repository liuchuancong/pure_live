// Module: test/bilibili_vod_source_test.dart
// Purpose: Drive the source over a scripted transport: listing, detail, signed search and guest resolve.
// Author: liuchuancong
// Created: 2026-10-11
//
// There were no tests in this package at all, so nothing here proves what the live site answers - the bodies
// are hand-written from the endpoint notes. What it does pin is the parts that were wrong: a refusal decoded
// as an empty page, a ticket that could not be re-minted after its cache entry was gone, and a signed query
// that the caller re-encoded into something else.

import 'package:pure_live_bilibili/pure_live_bilibili.dart';
import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_network/testing.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:test/test.dart';

const String _nav =
    '{"code":0,"message":"0","data":{"wbi_img":{'
    '"img_url":"https://i0.hdslb.com/bfs/wfi/7cd08494133a40833e9ee1a137569020.png",'
    '"sub_url":"https://i0.hdslb.com/bfs/wfi/4932caff0ff746eab6f01bf08b0283d5.png"}}}';

const String _popular = '''
{"code":0,"message":"0","data":{"list":[
  {"bvid":"BV1aa","title":"&quot;热门&quot; 视频","pic":"http://i0.hdslb.com/1.jpg","owner":{"name":"UP甲"},
   "stat":{"view":4321}},
  {"bvid":"BV1bb","title":"第二条","pic":"https://i0.hdslb.com/2.jpg","owner":{"name":"UP乙"},"stat":{"view":"x"}}
]}}''';

const String _view = '''
{"code":0,"message":"0","data":{"title":"多 P 视频","pic":"http://i0.hdslb.com/c.jpg","duration":600,
 "owner":{"name":"UP甲"},"stat":{"view":10},
 "pages":[{"cid":111,"part":"P1"},{"cid":222,"part":"P2"}]}}''';

const String _search = '''
{"code":0,"message":"0","data":{"result":[
  {"bvid":"BVcs1","title":"<em class=\\"keyword\\">命中</em> &amp; 结果","author":"UP丙","pic":"http://i/p.jpg",
   "duration":"12:34","play":99},
  {"bvid":"BVcs2","title":"无时长","author":"","duration":"--:--","play":null}
]}}''';

const String _playurl = '''
{"code":0,"message":"0","data":{"durl":[
  {"url":"https://dx.example.com/video.m4s?key=abc","length":600,"size":12345,"order":1}]}}''';

const String _playurl2 = '''
{"code":0,"message":"0","data":{"durl":[
  {"url":"https://dx.example.com/video.m4s?key=refreshed","length":600,"size":12345}]}}''';

/// Path-keyed script of bodies; a path may hold several, answered in order and repeating the last. This is the
/// transport `pure_live_network` publishes for exactly this job - the file used to implement dio's
/// `HttpClientAdapter` itself, which dragged a dio dev dependency into the provider for one fake.
typedef _ScriptedTransport = ScriptedTransport;

_ScriptedTransport _transport({List<String> playurl = const <String>[_playurl]}) =>
    _ScriptedTransport(<String, List<String>>{
      '/x/web-interface/nav': <String>[_nav],
      '/x/web-interface/popular': <String>[_popular],
      '/x/web-interface/view': <String>[_view],
      '/x/web-interface/search/type': <String>[_search],
      '/x/player/playurl': playurl,
    });

NetworkClient _client(_ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => DateTime.utc(2026, 10, 11),
  // One attempt per request: these tests count requests to prove a refusal never reached the socket, and the
  // production retry policy would add transport attempts on top of every one.
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

void main() {
  late _ScriptedTransport transport;
  late BilibiliVodSource source;

  setUp(() {
    transport = _transport();
    source = BilibiliVodSource(client: _client(transport), clock: () => DateTime.utc(2026, 10, 11));
  });

  tearDown(() => source.dispose());

  group('test_bilibiliVodSource_browse', () {
    test('test_browse_mapsThePopularTableAndSendsTheCookie', () async {
      final page = await source.browse(ContentQuery(page: PageRequest(page: 2, pageSize: 2)));

      expect(page.items, hasLength(2));
      expect(page.items.first.title, '"热门" 视频', reason: 'entities come back decoded');
      expect(page.items.first.cover, startsWith('https://'));
      expect(page.items.first.metadata.popularity, 4321);
      expect(page.items.last.metadata.popularity, isNull, reason: 'a non-numeric view count is not a number');
      expect(page.hasMore, isTrue);
      expect(page.mode, PageMode.fixedPage);

      final request = transport.requests.single;
      expect(request.uri.queryParameters['pn'], '2');
      expect(request.headers['cookie'], contains('buvid3=${source.buvid3}'));
    });

    test('test_browse_anUnknownCategoryIsRefusedInsteadOfServingPopular', () async {
      await expectLater(
        source.browse(ContentQuery(category: 'bangumi')),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('no category "bangumi"'))),
      );
      expect(transport.requests, isEmpty, reason: 'the request was never made');
    });

    test('test_browse_aSiteRefusalIsNotAnEmptyPage', () async {
      transport = _ScriptedTransport(<String, List<String>>{
        '/x/web-interface/popular': <String>['{"code":-352,"message":"risk control verified"}'],
      });
      final refused = BilibiliVodSource(client: _client(transport));

      await expectLater(
        refused.browse(ContentQuery()),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('code -352'), contains('risk control verified')),
          ),
        ),
      );
    });

    test('test_categories_listsTheOneNameBrowseAccepts', () async {
      final categories = await source.categories();

      expect(categories.map((row) => row.id), <String>[bilibiliPopularCategory]);
      final page = await source.browse(ContentQuery(category: bilibiliPopularCategory));
      expect(page.items, hasLength(2));
    });
  });

  group('test_bilibiliVodSource_detail', () {
    test('test_detail_givesEachPageAChildRefThatCarriesItsCid', () async {
      final detail = await source.detail(
        ContentRef(sourceId: bilibiliSourceId, contentId: 'BV1aa', kind: ContentKind.vod),
      );

      expect(detail.summary.metadata.duration, const Duration(minutes: 10));
      expect(detail.children, hasLength(2));
      expect(detail.children.first.contentId, 'BV1aa P1');
      expect(detail.children.first.parentId, 'BV1aa');
      expect(detail.children.first.metadata[bilibiliCidKey], 111);
      expect(detail.children.last.metadata['part'], 'P2');
    });

    test('test_detail_aSinglePageKeepsTheVideoIdAsTheEpisodeId', () async {
      transport = _ScriptedTransport(<String, List<String>>{
        '/x/web-interface/view': <String>['{"code":0,"data":{"title":"单P","pages":[{"cid":9,"part":"正片"}]}}'],
      });
      final single = BilibiliVodSource(client: _client(transport));

      final detail = await single.detail(
        ContentRef(sourceId: bilibiliSourceId, contentId: 'BV1s', kind: ContentKind.vod),
      );
      expect(detail.children.single.contentId, 'BV1s');
    });

    test('test_detail_aRefusalIsNamed', () async {
      transport = _ScriptedTransport(<String, List<String>>{
        '/x/web-interface/view': <String>['{"code":-404,"message":"啥都木有"}'],
      });
      final missing = BilibiliVodSource(client: _client(transport));

      await expectLater(
        missing.detail(ContentRef(sourceId: bilibiliSourceId, contentId: 'BVnope', kind: ContentKind.vod)),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('啥都木有'))),
      );
    });
  });

  group('test_bilibiliVodSource_search', () {
    test('test_search_signsNavKeysOnceAndSendsTheQueryVerbatim', () async {
      final page = await source.search(SearchQuery(keyword: 'hello world', page: PageRequest(page: 1, pageSize: 30)));

      expect(page.items, hasLength(2));
      expect(page.items.first.title, '命中 & 结果', reason: 'the highlight wrapper and the entity both go');
      expect(page.items.first.metadata.duration, const Duration(minutes: 12, seconds: 34));
      expect(page.items.last.metadata.duration, isNull, reason: '"--:--" is not a zero-second video');

      final signed = transport.requests.last;
      expect(signed.uri.path, '/x/web-interface/search/type');
      expect(signed.uri.toString(), contains('w_rid='));
      expect(Uri.decodeQueryComponent(signed.uri.queryParameters['keyword']!), 'hello world');
      expect(
        signed.uri.toString(),
        contains('keyword=hello%20world'),
        reason: 'the bytes sent are the bytes hashed, not a re-encoding of them',
      );
      expect(transport.requests.where((request) => request.uri.path.endsWith('/nav')), hasLength(1));
    });

    test('test_search_aRefusalIsNamed', () async {
      transport = _ScriptedTransport(<String, List<String>>{
        '/x/web-interface/nav': <String>[_nav],
        '/x/web-interface/search/type': <String>['{"code":-412,"message":"request was banned"}'],
      });
      final banned = BilibiliVodSource(client: _client(transport));

      await expectLater(
        banned.search(SearchQuery(keyword: 'x')),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('request was banned'))),
      );
    });
  });

  group('test_bilibiliVodSource_resolve', () {
    ContentRef _episode({int? cid = 222}) => ContentRef(
      sourceId: bilibiliSourceId,
      contentId: 'BV1aa P2',
      kind: ContentKind.episode,
      parentId: 'BV1aa',
      metadata: <String, Object?>{if (cid != null) bilibiliCidKey: cid},
    );

    test('test_resolve_mintsTheGuestStreamAndCarriesTheReferer', () async {
      final ticket = await source.resolve(_episode());

      expect(ticket.uri.toString(), startsWith('https://dx.example.com/'));
      expect(ticket.protocol, MediaProtocol.https);
      expect(ticket.kind, MediaKind.vod);
      expect(ticket.headers['referer'], 'https://www.bilibili.com/');
      expect(ticket.refresh?.supported, isTrue);
      expect(ticket.metadata.duration, const Duration(minutes: 10));
      expect(ticket.metadata.extra[bilibiliBvidKey], 'BV1aa');
      expect(ticket.metadata.extra[bilibiliCidKey], 222);
      expect(ticket.metadata.extra['bilibili.sizeBytes'], 12345);

      final sent = transport.requests.last.uri.queryParameters;
      expect(sent['bvid'], 'BV1aa');
      expect(sent['cid'], '222');
      expect(sent['try_look'], '1');
    });

    test('test_resolve_echoesTheQualityItCouldNotGive', () async {
      final ticket = await source.resolve(_episode(), quality: SelectionRef('1080p'));

      expect(
        ticket.metadata.extra['bilibili.requestedQuality'],
        '1080p',
        reason: 'a guest stream is capped; the ask must stay visible to the surface',
      );
    });

    test('test_resolve_anEpisodeWithoutACidIsRefusedByReason', () async {
      await expectLater(
        source.resolve(_episode(cid: null)),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('carries no cid'))),
      );
      expect(transport.requests.where((request) => request.uri.path.endsWith('playurl')), isEmpty);
    });

    test('test_resolve_aNamedLineIsRefusedRatherThanPlayedAsTheOnlyOne', () async {
      await expectLater(
        source.resolve(_episode(), line: SelectionRef('cdn2')),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('one guest stream'))),
      );
    });

    test('test_resolve_anEmptyDurlIsNotASilentTicket', () async {
      transport = _ScriptedTransport(<String, List<String>>{
        '/x/player/playurl': <String>['{"code":0,"data":{"durl":[]}}'],
      });
      final noStream = BilibiliVodSource(client: _client(transport));

      await expectLater(
        noStream.resolve(_episode()),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('no durl'))),
      );
    });

    test('test_refresh_remintsFromTheTicketAlone', () async {
      transport = _ScriptedTransport(<String, List<String>>{
        '/x/player/playurl': <String>[_playurl, _playurl2],
      });
      final fresh = BilibiliVodSource(client: _client(transport));

      final first = await fresh.resolve(_episode());
      final second = await fresh.refresh(first, RefreshReason.expired);

      expect(second.uri.queryParameters['key'], 'refreshed');
      expect(second.metadata.extra[bilibiliCidKey], 222, reason: 'nothing else remembered the page');
      expect(second.id, first.id);
    });

    test('test_refresh_aTicketFromSomewhereElseIsRefused', () async {
      await expectLater(
        source.refresh(
          MediaTicket(
            id: 'other/ticket',
            uri: Uri.parse('https://example.com/x'),
            kind: MediaKind.vod,
            protocol: MediaProtocol.https,
            createdAt: DateTime.utc(2026),
          ),
          RefreshReason.manual,
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('carries no bvid/cid'))),
      );
    });
  });

  group('test_bilibiliVodSource_lifetime', () {
    test('test_dispose_closesTheOneClientTheSignerShares', () async {
      await source.search(SearchQuery(keyword: 'x'));
      final own = source;
      source = BilibiliVodSource(client: _client(_transport()));
      own.dispose();

      expect(transport.closed, isTrue);
    });
  });
}
