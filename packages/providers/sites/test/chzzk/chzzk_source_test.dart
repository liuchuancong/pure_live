// Module: test/chzzk/chzzk_source_test.dart
// Purpose: The CHZZK source against a canned transport: the inclusive cursor, the exposure-gated audience, the
// playback bundle and the master-manifest renditions.
// Author: liuchuancong
// Created: 2026-10-11
//
// Bodies are written to the field names the v1 line reads, not recorded from the site (README 未验证).

import 'dart:convert';

import 'package:pure_live_network/pure_live_network.dart';
import 'package:pure_live_network/testing.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_sites/pure_live_sites.dart';
import 'package:test/test.dart';

const String _id = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
const String _otherId = '0f9e8d7c6b5a4938271605f4e3d2c1b0';

final String _livesKey = 'api.chzzk.naver.com/service/v1/lives';
final String _searchKey = 'api.chzzk.naver.com/service/v1/search/channels';
final String _channelKey = 'api.chzzk.naver.com/service/v1/channels/$_id';
final String _detailKey = 'api.chzzk.naver.com/service/v3.1/channels/$_id/live-detail';

const String _masterUrl = 'https://livewav-ap2.akamaized.net/hls/live/2039481/a/master.m3u8?cd=1';
const String _llUrl = 'https://livewav-ap2.akamaized.net/hls/live/2039481/a/llhls/master.m3u8?cd=1';
final String _masterKey = 'livewav-ap2.akamaized.net/hls/live/2039481/a/master.m3u8';
final String _llKey = 'livewav-ap2.akamaized.net/hls/live/2039481/a/llhls/master.m3u8';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
final ContentRef _room = ContentRef(sourceId: 'chzzk.live', contentId: _id, kind: ContentKind.liveRoom);

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(ScriptedTransport, ChzzkSource) _source(Map<String, List<String>> script) {
  final transport = ScriptedTransport(script);
  return (transport, ChzzkSource(client: _client(transport), clock: () => _now));
}

String _envelope(Object? content) => jsonEncode(<String, Object?>{'code': 200, 'content': content});

Map<String, Object?> _channelRow({
  String channelId = _id,
  String name = '채널',
  bool openLive = true,
  int? followers = 5000,
}) => <String, Object?>{
  'channel': <String, Object?>{
    'channelId': channelId,
    'channelName': name,
    'channelImageUrl': 'https://chzzk.pstatic.net/avatar/x.jpg',
    'channelDescription': '소개',
    'followerCount': followers,
    'openLive': openLive,
  },
};

Map<String, Object?> _liveRow({int liveId = 7788, bool cvExposure = true, int viewers = 50, String? cover}) =>
    <String, Object?>{
      'liveId': liveId,
      'liveTitle': '라이브 제목',
      'liveImageUrl': cover ?? 'https://chzzk.pstatic.net/live/{type}/cover.jpg',
      'defaultThumbnailImageUrl': '',
      'liveCategoryValue': '게임',
      'concurrentUserCount': viewers,
      'cvExposure': cvExposure,
      'adult': false,
      ..._channelRow(),
    };

String _directory(List<Object?> rows, {int? nextViewers, int? nextLiveId}) => _envelope(<String, Object?>{
  'data': rows,
  if (nextViewers != null && nextLiveId != null)
    'page': <String, Object?>{
      'next': <String, Object?>{'concurrentUserCount': nextViewers, 'liveId': nextLiveId},
    },
});

String _detail({
  String status = 'OPEN',
  Object? playback,
  bool adult = false,
  bool krOnly = false,
  bool timeMachine = false,
  String chatChannelId = 'chat-1',
  int? liveId = 7788,
}) => _envelope(<String, Object?>{
  'liveId': liveId,
  'status': status,
  'liveTitle': '라이브 제목',
  'liveImageUrl': 'https://chzzk.pstatic.net/live/{type}/cover.jpg',
  'liveCategoryValue': '게임',
  'concurrentUserCount': 50,
  'cvExposure': true,
  'adult': adult,
  'krOnlyViewing': krOnly,
  'timeMachineActive': timeMachine,
  'chatChannelId': chatChannelId,
  if (playback != null) 'livePlaybackJson': playback,
  ..._channelRow(),
});

String _bundle(List<Object?> media) => jsonEncode(<String, Object?>{'media': media});

Map<String, Object?> _media(String id, String path) => <String, Object?>{
  'protocol': 'HLS',
  'mediaId': id,
  'path': path,
};

const String _masterManifest = '''#EXTM3U
#EXT-X-INDEPENDENT-SEGMENTS
#EXT-X-STREAM-INF:BANDWIDTH=6000000,AVERAGE-BANDWIDTH=5500000,RESOLUTION=1920x1080,FRAME-RATE=60.000,CODECS="avc1.640028,mp4a.40.2"
prog_index.m3u8?cd=1
#EXT-X-STREAM-INF:BANDWIDTH=4000000,RESOLUTION=1920x1080,FRAME-RATE=30.000,CODECS="avc1.640028,mp4a.40.2"
slow_index.m3u8?cd=1
#EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720,FRAME-RATE=30.000
mid_index.m3u8
''';

void main() {
  group('test_chzzkSource_directory', () {
    test('test_theServerCursorIsInclusiveSoOneExtraRowIsAskedAndDropped', () async {
      final (transport, chzzk) = _source(<String, List<String>>{
        _livesKey: <String>[
          _directory(<Object?>[_liveRow(liveId: 1)], nextViewers: 50, nextLiveId: 1),
          // The answer repeats the boundary row it was continued from, and it is dropped rather than listed twice.
          _directory(<Object?>[_liveRow(liveId: 1), _liveRow(liveId: 2)], nextViewers: 40, nextLiveId: 2),
        ],
      });
      final first = await chzzk.feed(PageRequest.first);
      expect(first.mode, PageMode.cursor);
      expect(first.hasMore, isTrue);
      expect(first.nextCursor, isNotNull);
      final second = await chzzk.feed(PageRequest(page: 2, cursor: first.nextCursor));
      expect(second.items.map((item) => item.title), <String>['라이브 제목']);
      expect(second.items.single.ref.contentId, _id);
      final sent = transport.requests.last.uri.queryParameters;
      expect(sent['size'], '${chzzkDirectoryPageSize + 1}');
      expect(sent['concurrentUserCount'], '50');
      expect(sent['liveId'], '1');
    });

    test('test_aNextBlockNamingTheCursorWeSentEndsTheList', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _livesKey: <String>[
          _directory(<Object?>[_liveRow(liveId: 1)], nextViewers: 50, nextLiveId: 1),
          _directory(<Object?>[_liveRow(liveId: 2)], nextViewers: 50, nextLiveId: 1),
        ],
      });
      final first = await chzzk.feed(PageRequest.first);
      final second = await chzzk.feed(PageRequest(page: 2, cursor: first.nextCursor));
      // The site handed back the same position: continuing would show the same page forever.
      expect(second.hasMore, isFalse);
      expect(second.nextCursor, isNull);
    });

    test('test_aSecondPageWithoutItsCursorIsRefused', () async {
      final (transport, chzzk) = _source(<String, List<String>>{
        _livesKey: <String>[
          _directory(<Object?>[_liveRow()], nextViewers: 50, nextLiveId: 1),
        ],
      });
      await expectLater(chzzk.feed(const PageRequest(page: 2)), throwsA(isA<ChzzkFailure>()));
      expect(transport.requestsTo(_livesKey), 0);
    });

    test('test_anUnknownListingIsRefused', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _livesKey: <String>[
          _directory(<Object?>[_liveRow()]),
        ],
      });
      await expectLater(
        chzzk.browse(const ContentQuery(category: 'sports')),
        throwsA(isA<ChzzkFailure>().having((ChzzkFailure e) => e.message, 'message', contains('one live directory'))),
      );
    });

    test('test_theHiddenViewerCountStaysHidden', () {
      final shown = chzzkDirectoryLive(_liveRow(cvExposure: true, viewers: 50)).toLiveRoom();
      final hidden = chzzkDirectoryLive(_liveRow(cvExposure: false, viewers: 50)).toLiveRoom();
      expect(shown.audiencePrimary, 50);
      // `cvExposure` is the site choosing not to publish; drawing 0 there invents a number it withheld.
      expect(hidden.audience, isNull);
    });

    test('test_theCoverTemplateIsExpandedAndForeignHostsAreDropped', () {
      final room = chzzkDirectoryLive(_liveRow()).toLiveRoom();
      expect(room.cover, 'https://chzzk.pstatic.net/live/480/cover.jpg');
      final foreign = _liveRow(cover: 'https://evil.example/cover.jpg');
      expect(chzzkDirectoryLive(foreign).toLiveRoom().cover, isNull);
    });

    test('test_aRowWithoutAChannelIdIsASchemaChange', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _livesKey: <String>[
          _directory(<Object?>[
            <String, Object?>{
              'liveId': 1,
              'liveTitle': 'x',
              'channel': <String, Object?>{'channelId': 'not-hex'},
            },
          ]),
        ],
      });
      await expectLater(chzzk.feed(PageRequest.first), throwsA(isA<ChzzkFailure>()));
    });

    test('test_anEnvelopeRefusalIsNamedAndAFourOhFourIsMissing', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _livesKey: <String>[
          jsonEncode(<String, Object?>{'code': 500}),
        ],
      });
      await expectLater(
        chzzk.feed(PageRequest.first),
        throwsA(predicate<ChzzkFailure>((ChzzkFailure error) => !error.missing && error.code == 500)),
      );
    });
  });

  group('test_chzzkSource_room', () {
    test('test_theRoomIsTwoCallsAndAnEmptyDetailIsOffline', () async {
      final (transport, chzzk) = _source(<String, List<String>>{
        _channelKey: <String>[_envelope(_channelRow(openLive: false)['channel'])],
        _detailKey: <String>[_envelope(null)],
      });
      final room = await chzzk.room(_room);
      expect(room.state, LiveRoomState.ended);
      expect(room.anchorName, '채널');
      expect(room.followers, 5000);
      expect(room.restriction, isNull);
      expect(transport.requestsTo(_channelKey), 1);
      expect(transport.requestsTo(_detailKey), 1);
    });

    test('test_theChannelAnswerMustBeAboutTheChannelAsked', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _channelKey: <String>[
          _envelope(<String, Object?>{'channelId': _otherId, 'channelName': '남'}),
        ],
      });
      await expectLater(chzzk.room(_room), throwsA(isA<ChzzkFailure>()));
    });

    test('test_aStatusOutsideTheSitesVocabularyIsNotAGuess', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _channelKey: <String>[_envelope(_channelRow()['channel']!)],
        _detailKey: <String>[_detail(status: 'PAUSED')],
      });
      await expectLater(
        chzzk.room(_room),
        throwsA(isA<ChzzkFailure>().having((ChzzkFailure e) => e.message, 'message', contains('PAUSED'))),
      );
    });

    test('test_aLiveDetailBelongingToAnotherChannelIsRefused', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _channelKey: <String>[_envelope(_channelRow()['channel']!)],
        _detailKey: <String>[
          _envelope(<String, Object?>{
            'liveId': 1,
            'status': 'OPEN',
            'liveTitle': 'x',
            'adult': false,
            'krOnlyViewing': false,
            'timeMachineActive': false,
            'cvExposure': false,
            ..._channelRow(channelId: _otherId),
          }),
        ],
      });
      await expectLater(chzzk.room(_room), throwsA(isA<ChzzkFailure>()));
    });

    test('test_theGatesAreRecordedAsFactsAndTimeMachineBecomesCatchUp', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _channelKey: <String>[_envelope(_channelRow()['channel']!)],
        _detailKey: <String>[
          _detail(adult: true, timeMachine: true, playback: _bundle(<Object?>[_media('HLS', _masterUrl)])),
        ],
      });
      final room = await chzzk.room(_room);
      expect(room.extra['chzzk.adult'], isTrue);
      expect(room.catchUp?.isOffered, isTrue, reason: 'timeMachineActive is the site saying the past is watchable');
      expect(room.restriction, LiveRestriction.private);
      expect(room.requiresAuth, isTrue);
      expect(room.danmakuPayload['chatChannelId'], 'chat-1');
      expect((room.sitePayload['chzzk.media']! as List<Object?>).single, isA<Map<String, Object?>>());
    });

    test('test_anOfflineDetailCarriesNoChatHandshake', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _channelKey: <String>[_envelope(_channelRow()['channel']!)],
        _detailKey: <String>[
          _detail(status: 'CLOSE', playback: _bundle(<Object?>[_media('HLS', _masterUrl)])),
        ],
      });
      final room = await chzzk.room(_room);
      expect(room.state, LiveRoomState.ended);
      expect(room.danmakuPayload.containsKey('chatChannelId'), isFalse);
    });
  });

  group('test_chzzkSource_playback', () {
    test('test_thePlaybackBundleIsAJsonStringAndOnlyTheSitesMediaIdsSurvive', () {
      final bundle = _bundle(<Object?>[
        _media('HLS', _masterUrl),
        _media('LLHLS', _llUrl),
        <String, Object?>{'protocol': 'DASH', 'mediaId': 'DASH', 'path': _masterUrl},
        _media('WEBRTC', _masterUrl),
        _media('HLS', _masterUrl),
      ]);
      final media = chzzkPlaybackMedia(bundle);
      // Two transports this path has not read are skipped rather than guessed at, and the repeat is one line.
      expect(media.map((ChzzkMedia item) => item.id), <String>['HLS', 'LLHLS']);
      expect(media.last.lowLatency, isTrue);
    });

    test('test_anAddressOffTheDeliveryFamilyIsNeverFetched', () {
      expect(() => chzzkMediaUrl('https://evil.example/master.m3u8'), throwsA(isA<ChzzkFailure>()));
      expect(() => chzzkMediaUrl('http://livewav-ap2.akamaized.net/a.m3u8'), throwsA(isA<ChzzkFailure>()));
      expect(() => chzzkMediaUrl('https://a@livewav-ap2.akamaized.net/a.m3u8'), throwsA(isA<ChzzkFailure>()));
      expect(chzzkMediaUrl(_masterUrl).host, 'livewav-ap2.akamaized.net');
    });

    test('test_renditionsAreGroupedByHeightAndFrameRate', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _channelKey: <String>[_envelope(_channelRow()['channel']!)],
        _detailKey: <String>[
          _detail(playback: _bundle(<Object?>[_media('HLS', _masterUrl)])),
        ],
        _masterKey: <String>[_masterManifest],
      });
      final qualities = await chzzk.qualities(_room);
      expect(qualities.map((option) => option.label), <String>['1080p60 · HLS', '1080p · HLS', '720p · HLS']);
      expect(qualities.first.height, 1080);
      expect(qualities.first.bitrateKbps!, 6000);
      // 30fps and 60fps at one height are two renditions, and the frame rate must be visible in the choice.
      expect(qualities.first.rank!, greaterThan(qualities[1].rank!));
    });

    test('test_hlsAndLlhlsOfOneShapeMergeIntoLines', () async {
      final (transport, chzzk) = _source(<String, List<String>>{
        _channelKey: <String>[_envelope(_channelRow()['channel']!)],
        _detailKey: <String>[
          _detail(playback: _bundle(<Object?>[_media('HLS', _masterUrl), _media('LLHLS', _llUrl)])),
        ],
        _masterKey: <String>[_masterManifest],
        _llKey: <String>[
          '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=6500000,RESOLUTION=1920x1080,FRAME-RATE=60.000\nll_index.m3u8\n',
        ],
      });
      final qualities = await chzzk.qualities(_room);
      expect(qualities.first.id, '1080p60');
      expect(qualities.first.bitrateKbps!, 6500, reason: 'the group reports the bandwidth the site actually stated');
      // Two ways to reach the same picture: they are lines, not two qualities.
      final lines = await chzzk.lines(_room);
      expect(lines.map((line) => line.id), <String>['1', '2']);
      // qualities and lines each read the room once; the two manifests are fetched per call, not cached.
      expect(transport.requestsTo(_llKey), 2, reason: 'qualities and lines each read the manifests');
    });

    test('test_aRenditionWithoutResolutionOrBandwidthFailsTheManifest', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _channelKey: <String>[_envelope(_channelRow()['channel']!)],
        _detailKey: <String>[
          _detail(playback: _bundle(<Object?>[_media('HLS', _masterUrl)])),
        ],
        _masterKey: <String>['#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\nprog.m3u8\n'],
      });
      await expectLater(
        chzzk.qualities(_room),
        throwsA(isA<ChzzkFailure>().having((ChzzkFailure e) => e.message, 'message', contains('no resolution'))),
      );
    });

    test('test_aLiveRoomWithNoBundleIsUnplayableAndSaysSo', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _channelKey: <String>[_envelope(_channelRow()['channel']!)],
        _detailKey: <String>[_detail()],
      });
      final room = await chzzk.room(_room);
      expect(room.state, LiveRoomState.live);
      expect(room.restriction, LiveRestriction.unplayable);
      await expectLater(
        chzzk.resolve(_room),
        throwsA(isA<StateError>().having((StateError e) => e.message, 'message', contains('no rendition'))),
      );
    });

    test('test_aRegionRestrictedRoomNamesTheRegionAsTheReason', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _channelKey: <String>[_envelope(_channelRow()['channel']!)],
        _detailKey: <String>[_detail(krOnly: true)],
      });
      final room = await chzzk.room(_room);
      expect(room.extra['chzzk.krOnly'], isTrue);
      expect(room.restriction, LiveRestriction.unplayable);
      await expectLater(
        chzzk.resolve(_room),
        throwsA(isA<StateError>().having((StateError e) => e.message, 'message', contains('Korea'))),
      );
    });

    test('test_resolveKeepsTheChoiceAndRefreshReReadsTheRoom', () async {
      final (transport, chzzk) = _source(<String, List<String>>{
        _channelKey: <String>[_envelope(_channelRow()['channel']!)],
        _detailKey: <String>[
          _detail(playback: _bundle(<Object?>[_media('HLS', _masterUrl)])),
        ],
        _masterKey: <String>[_masterManifest],
      });
      final ticket = await chzzk.resolve(_room, quality: const SelectionRef('720p'));
      expect(ticket.protocol, MediaProtocol.hls);
      expect(ticket.uri.toString(), 'https://livewav-ap2.akamaized.net/hls/live/2039481/a/mid_index.m3u8');
      expect(ticket.metadata.extra['chzzk.quality'], '720p');
      final again = await chzzk.refresh(ticket, RefreshReason.expiring);
      expect(again.uri, ticket.uri);
      expect(transport.requestsTo(_channelKey), 2, reason: 'the room is re-read rather than the address reused');
      expect(transport.requestsTo(_channelKey), transport.requestsTo(_detailKey), reason: 'one room, not two');
    });

    test('test_anUnknownQualityFallsBackAndSaysSo', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _channelKey: <String>[_envelope(_channelRow()['channel']!)],
        _detailKey: <String>[
          _detail(playback: _bundle(<Object?>[_media('HLS', _masterUrl)])),
        ],
        _masterKey: <String>[_masterManifest],
      });
      final ticket = await chzzk.resolve(_room, quality: const SelectionRef('4K'));
      expect(ticket.metadata.extra['chzzk.requestedQuality'], '4K');
      expect(ticket.metadata.extra['chzzk.quality'], '1080p60');
    });

    test('test_anUnknownLineIsRefusedRatherThanPlayedAsLineOne', () async {
      final (_, chzzk) = _source(<String, List<String>>{
        _channelKey: <String>[_envelope(_channelRow()['channel']!)],
        _detailKey: <String>[
          _detail(playback: _bundle(<Object?>[_media('HLS', _masterUrl)])),
        ],
        _masterKey: <String>[_masterManifest],
      });
      await expectLater(chzzk.resolve(_room, line: const SelectionRef('4')), throwsA(isA<StateError>()));
    });
  });

  group('test_chzzkSource_search', () {
    test('test_channelsAreOffsetPagedAndReadAsPeople', () async {
      final (transport, chzzk) = _source(<String, List<String>>{
        _searchKey: <String>[
          _envelope(<String, Object?>{
            'data': <Object?>[_channelRow(), _channelRow(channelId: _otherId, openLive: false)],
          }),
        ],
      });
      final rooms = await chzzk.search(const SearchQuery(keyword: '채널'));
      expect(rooms.items, hasLength(2));
      expect(rooms.pageSize, chzzkSearchPageSize);
      final anchors = await chzzk.searchAnchors(const SearchQuery(keyword: '채널', page: PageRequest(page: 2)));
      expect(anchors.items.first.name, '채널');
      expect(anchors.items.first.fans, 5000);
      expect(anchors.items.first.isLiveNow, isTrue);
      expect(anchors.items.last.isLiveNow, isFalse);
      expect(Uri.splitQueryString(transport.requests.last.uri.query)['offset'], '$chzzkSearchPageSize');
    });

    test('test_aKeywordIsCutWithoutSplittingASurrogatePair', () {
      // A 101-code-unit term whose 100th unit is the high half of a pair: cutting between them sends a term the
      // site cannot decode.
      final term = 'a' * 99 + '\ud83d\ude00';
      final cut = chzzkKeyword(term);
      expect(cut.length, 99);
      expect(cut.runes.every((int rune) => rune >= 0), isTrue);
      expect(chzzkKeyword('   ').isEmpty, isTrue);
    });

    test('test_aChannelUrlYieldsItsIdAndOtherPathsDoNot', () {
      expect(chzzkChannelFromUri(Uri.parse('https://chzzk.naver.com/live/$_id')), _id);
      expect(chzzkChannelFromUri(Uri.parse('https://chzzk.naver.com/$_id')), _id);
      expect(chzzkChannelFromUri(Uri.parse('https://m.chzzk.naver.com/$_id')), isNull);
      expect(chzzkChannelFromUri(Uri.parse('https://chzzk.naver.com/$_id/extra/tail')), isNull);
      expect(() => chzzkChannelId('ZZZ'), throwsA(isA<ChzzkFailure>()));
    });
  });
}
