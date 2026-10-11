// Module: test/picarto/picarto_source_test.dart
// Purpose: The Picarto source against a canned transport: the self-checking grid, the single-stream detail, the
// reserved-name channel rule and the playlist grouping.
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

const String _exploreKey = 'ptvintern.picarto.tv/api/explore';
const String _searchKey = 'ptvintern.picarto.tv/api/search';
const String _categoryKey = 'ptvintern.picarto.tv/api/languages-categories';
const String _detailKey = 'ptvintern.picarto.tv/api/channel/detail/art';
const String _playlistKey = 'abc123.picarto.tv/stream/hls/art_stream/index.m3u8';

final DateTime _now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
const ContentRef _room = ContentRef(sourceId: 'picarto.live', contentId: 'art', kind: ContentKind.liveRoom);

NetworkClient _client(ScriptedTransport transport) => NetworkClient(
  adapter: transport,
  clock: () => _now,
  settings: const NetworkSettings(retry: RetryPolicy(attempts: 1)),
);

(ScriptedTransport, PicartoSource) _source(Map<String, List<String>> script) {
  final transport = ScriptedTransport(script);
  return (transport, PicartoSource(client: _client(transport), clock: () => _now));
}

Map<String, Object?> _row({
  String name = 'art',
  int id = 7,
  bool online = true,
  bool adult = false,
  int? viewers = 10,
  int categoryId = 3,
}) => <String, Object?>{
  'id': id,
  'name': name,
  'online': online,
  'adult': adult,
  'title': '画一会儿',
  'viewers': viewers,
  'total_views': 99,
  'avatar': 'https://dd.danihel.app/a.png',
  'image_thumbnail': 'https://dd.danihel.app/t.png',
  'categories': <Object?>[
    <String, Object?>{'id': categoryId, 'name': 'Art'},
  ],
};

String _explore(
  List<Object?> rows, {
  int page = 1,
  int pageSize = picartoServerPageSize,
  int lastPage = 3,
  int total = 90,
}) => jsonEncode(<String, Object?>{
  'data': rows,
  'current_page': page,
  'per_page': pageSize,
  'last_page': lastPage,
  'total': total,
});

String _detail({
  bool online = true,
  bool isPrivate = false,
  String origin = 'abc123',
  List<Object?>? streams,
  String name = 'art',
  int id = 7,
}) => jsonEncode(<String, Object?>{
  'channel': <String, Object?>{
    'id': id,
    'name': name,
    'online': online,
    'private': isPrivate,
    'title': '画一会儿',
    'avatar': 'https://dd.danihel.app/a.png',
    'image_thumbnail': 'https://dd.danihel.app/t.png',
    'viewers': 10,
    'total_views': 99,
    'bio': 'A &amp; B',
    'categories': <Object?>[
      <String, Object?>{'id': 3, 'name': 'Art'},
    ],
  },
  'getLoadBalancerUrl': <String, Object?>{'origin': origin},
  'getMultiStreams': <String, Object?>{
    'streams':
        streams ??
        <Object?>[
          <String, Object?>{
            'channelId': id,
            'stream_name': 'art_stream',
            'thumbnail_image': 'https://dd.danihel.app/live.png',
          },
        ],
  },
});

String _playlist(String body) => '#EXTM3U\n#EXT-X-VERSION:6\n$body';

void main() {
  group('test_picartoSource_explore', () {
    test('test_theAnswerMustDescribeTheRequestItAnswers', () async {
      final (_, mismatch) = _source(<String, List<String>>{
        _exploreKey: <String>[
          _explore(<Object?>[_row()], page: 2),
        ],
      });
      await expectLater(
        mismatch.feed(PageRequest.first),
        throwsA(
          isA<PicartoFailure>().having((PicartoFailure e) => e.message, 'message', contains('does not describe')),
        ),
      );

      final (_, pastEnd) = _source(<String, List<String>>{
        _exploreKey: <String>[
          _explore(<Object?>[_row()], page: 4, lastPage: 3),
        ],
      });
      // A page past the last one that still carries rows is not "more results".
      await expectLater(pastEnd.feed(const PageRequest(page: 4)), throwsA(isA<PicartoFailure>()));
    });

    test('test_adultAndOfflineRowsAreDroppedNotMarkedOffline', () async {
      final (_, picarto) = _source(<String, List<String>>{
        _exploreKey: <String>[
          _explore(<Object?>[
            _row(),
            _row(name: 'naughty', id: 8, adult: true),
            _row(name: 'asleep', id: 9, online: false),
            _row(name: 'art', id: 10),
          ]),
        ],
      });
      final page = await picarto.feed(PageRequest.first);
      expect(page.items.map((item) => item.ref.contentId), <String>['art']);
      expect(page.total, 90);
      expect(page.pageSize, picartoServerPageSize);
      expect(page.hasMore, isTrue);
    });

    test('test_aFilteredRowOutsideItsCategoryIsRefused', () async {
      final (_, picarto) = _source(<String, List<String>>{
        _exploreKey: <String>[
          _explore(<Object?>[_row(categoryId: 4)]),
        ],
      });
      await expectLater(
        picarto.browse(const ContentQuery(category: '3')),
        throwsA(
          isA<PicartoFailure>().having((PicartoFailure e) => e.message, 'message', contains('not in the category')),
        ),
      );
    });

    test('test_theCategoriesComeFromTheLanguageTable', () async {
      final (_, picarto) = _source(<String, List<String>>{
        _categoryKey: <String>[
          jsonEncode(<String, Object?>{
            'categories': <Object?>[
              <String, Object?>{'id': 3, 'label': 'Art'},
              <String, Object?>{'id': 5, 'label': 'Music'},
            ],
          }),
        ],
      });
      final categories = await picarto.categories();
      expect(categories.map((category) => category.id), <String>['live', '3', '5']);
      expect(categories.first.name, '全部直播');

      final (_, broken) = _source(<String, List<String>>{
        _categoryKey: <String>[
          jsonEncode(<String, Object?>{
            'categories': <Object?>[
              <String, Object?>{'id': 3, 'label': 'Art'},
              <String, Object?>{'id': 3, 'label': 'Art again'},
            ],
          }),
        ],
      });
      await expectLater(broken.categories(), throwsA(isA<PicartoFailure>()));
    });

    test('test_anUnseenCategoryIsRefusedRatherThanAnsweredWithEverything', () async {
      final (transport, picarto) = _source(<String, List<String>>{
        _exploreKey: <String>[
          _explore(<Object?>[_row()]),
        ],
      });
      await expectLater(picarto.browse(const ContentQuery(category: 'games')), throwsA(isA<PicartoFailure>()));
      expect(transport.requestsTo(_exploreKey), 0);
    });

    test('test_aChannelNameIsCheckedAgainstTheSiteOwnWords', () {
      expect(picartoChannelName('art_1'), 'art_1');
      expect(() => picartoChannelName('login'), throwsA(isA<PicartoFailure>()));
      expect(() => picartoChannelName('has space'), throwsA(isA<PicartoFailure>()));
      expect(picartoChannelFromUri(Uri.parse('https://picarto.tv/art')), 'art');
      expect(picartoChannelFromUri(Uri.parse('https://www.picarto.tv/search')), isNull);
      expect(picartoChannelFromUri(Uri.parse('https://picarto.tv/art/work')), isNull);
      expect(picartoChannelFromUri(Uri.parse('https://picarto.tv/art?x=1')), 'art');
      expect(picartoChannelUrl('art'), 'https://picarto.tv/art');
    });
  });

  group('test_picartoSource_detail', () {
    test('test_theDetailMustBeAboutTheChannelAsked', () async {
      final (_, picarto) = _source(<String, List<String>>{
        _detailKey: <String>[_detail(name: 'someoneelse')],
      });
      await expectLater(picarto.room(_room), throwsA(isA<PicartoFailure>()));
    });

    test('test_aPrivateChannelIsPrivateAndCarriesNoStream', () async {
      final (transport, picarto) = _source(<String, List<String>>{
        _detailKey: <String>[_detail(isPrivate: true)],
      });
      final room = await picarto.room(_room);
      expect(room.restriction, LiveRestriction.private);
      expect(room.requiresAuth, isTrue);
      await expectLater(
        picarto.resolve(_room),
        throwsA(isA<StateError>().having((StateError e) => e.message, 'message', contains('private'))),
      );
      expect(transport.requestsTo(_playlistKey), 0);
    });

    test('test_theStreamListMustHoldExactlyOneRowForThisChannel', () async {
      final (_, two) = _source(<String, List<String>>{
        _detailKey: <String>[
          _detail(
            streams: <Object?>[
              <String, Object?>{'channelId': 7, 'stream_name': 'a'},
              <String, Object?>{'channelId': 7, 'stream_name': 'b'},
            ],
          ),
        ],
      });
      await expectLater(
        two.room(_room),
        throwsA(isA<PicartoFailure>().having((PicartoFailure e) => e.message, 'message', contains('exactly one'))),
      );

      final (_, none) = _source(<String, List<String>>{
        _detailKey: <String>[
          _detail(
            streams: <Object?>[
              <String, Object?>{'channelId': 99, 'stream_name': 'other'},
            ],
          ),
        ],
      });
      await expectLater(none.room(_room), throwsA(isA<PicartoFailure>()));
    });

    test('test_theLoadBalancerOriginIsShapeCheckedBeforeItBecomesAHost', () async {
      final (_, picarto) = _source(<String, List<String>>{
        _detailKey: <String>[_detail(origin: 'evil.example/')],
      });
      await expectLater(picarto.room(_room), throwsA(isA<PicartoFailure>()));
    });

    test('test_theLiveStatusNeverReadsAPlaylist', () async {
      final (transport, picarto) = _source(<String, List<String>>{
        _detailKey: <String>[_detail()],
      });
      final status = await picarto.liveStatus(_room);
      expect(status.state, LiveRoomState.live);
      expect(status.viewers, 10);
      expect(transport.requestsTo(_playlistKey), 0);
    });

    test('test_theBioIsUnescapedAndTheRoomIdIsTheName', () async {
      final (_, picarto) = _source(<String, List<String>>{
        _detailKey: <String>[_detail()],
      });
      final room = await picarto.room(_room);
      expect(room.ref.contentId, 'art');
      expect(room.introduction, 'A & B');
      // The live thumbnail from the stream row replaces the channel's own static cover.
      expect(room.cover, 'https://dd.danihel.app/live.png');
      expect(room.area, 'Art');
    });
  });

  group('test_picartoSource_playlist', () {
    test('test_variantsGroupByPictureNotByCdnOrRate', () async {
      final (_, picarto) = _source(<String, List<String>>{
        _detailKey: <String>[_detail()],
        _playlistKey: <String>[
          _playlist(
            '#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,FRAME-RATE=60.000,CODECS="avc1.640028"\n'
            'https://cdn-a.picarto.tv/hls/1080p60.m3u8?sig=1\n'
            '#EXT-X-STREAM-INF:BANDWIDTH=6500000,RESOLUTION=1920x1080,FRAME-RATE=60.000,CODECS="avc1.640028"\n'
            'https://cdn-b.picarto.tv/hls/1080p60.m3u8?sig=2\n',
          ),
        ],
      });
      final qualities = await picarto.qualities(_room);
      // Same picture, two cdn addresses: one quality, two lines.
      expect(qualities, hasLength(1));
      expect(qualities.single.label, '1080p 60fps');
      expect((await picarto.lines(_room)).map((line) => line.id), <String>['1', '2']);
    });

    test('test_externalAudioKeepsTheAutomaticMasterAsAnExplicitChoice', () async {
      final (_, picarto) = _source(<String, List<String>>{
        _detailKey: <String>[_detail()],
        _playlistKey: <String>[
          _playlist(
            '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",NAME="Audio",URI="audio.m3u8"\n'
            '#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,FRAME-RATE=60.000,AUDIO="aac"\n'
            'video.m3u8\n',
          ),
        ],
      });
      final qualities = await picarto.qualities(_room);
      expect(qualities.single.label, 'HLS Auto');
      expect(qualities.single.rank, isNull, reason: 'the automatic choice has no stated rank to sort by');
      final ticket = await picarto.resolve(_room);
      expect(ticket.metadata.extra['picarto.auto'], isTrue);
      expect(ticket.uri.path, endsWith('index.m3u8'), reason: 'picking the master keeps the external audio');
    });

    test('test_aVariantWithNoResolutionIsLabelledByItsRate', () async {
      final qualities = picartoQualities(
        _playlist('#EXT-X-STREAM-INF:BANDWIDTH=2500000,FRAME-RATE=30.000\naudio_only.m3u8\n'),
        Uri.parse('https://abc123.picarto.tv/stream/hls/art_stream/index.m3u8'),
      );
      expect(qualities.single.label, 'HLS 2.5 Mbps');
    });

    test('test_aPlaylistThatIsNotOneIsRefused', () {
      expect(
        () => picartoQualities('<html>404</html>', Uri.parse('https://a.picarto.tv/x.m3u8')),
        throwsA(isA<PicartoFailure>()),
      );
      expect(
        () => picartoQualities(
          _playlist('#EXT-X-STREAM-INF:RESOLUTION=1920x1080,FRAME-RATE=60.000\nx.m3u8\n'),
          Uri.parse('https://a.picarto.tv/x/index.m3u8'),
        ),
        throwsA(isA<PicartoFailure>()),
        reason: 'no BANDWIDTH means no way to rank or group the rendition',
      );
      expect(
        () => picartoQualities(_playlist('#EXTM3U\n'), Uri.parse('https://a.picarto.tv/x/index.m3u8')),
        throwsA(isA<PicartoFailure>()),
      );
    });

    test('test_resolvePicksTheQualityAndKeepsBothChoicesOnRefresh', () async {
      final (transport, picarto) = _source(<String, List<String>>{
        _detailKey: <String>[_detail(), _detail(), _detail()],
        _playlistKey: <String>[
          _playlist(
            '#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,FRAME-RATE=60.000\nhd.m3u8?sig=1\n'
            '#EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=640x360,FRAME-RATE=30.000\nsd.m3u8?sig=2\n',
          ),
          _playlist(
            '#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,FRAME-RATE=60.000\nhd.m3u8?sig=1\n'
            '#EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=640x360,FRAME-RATE=30.000\nsd.m3u8?sig=2\n',
          ),
          _playlist(
            '#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,FRAME-RATE=60.000\nhd.m3u8?sig=1\n'
            '#EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=640x360,FRAME-RATE=30.000\nsd.m3u8?sig=2\n',
          ),
        ],
      });
      final qualities = await picarto.qualities(_room);
      final low = qualities.last;
      final ticket = await picarto.resolve(_room, quality: SelectionRef(low.id));
      expect(ticket.uri.path, endsWith('sd.m3u8'));
      expect(ticket.protocol, MediaProtocol.hls);
      expect(ticket.metadata.extra['picarto.label'], '360p 30fps');
      final again = await picarto.refresh(ticket, RefreshReason.expiring);
      expect(again.uri, ticket.uri);
      expect(transport.requestsTo(_playlistKey), 3, reason: 'the menu, the play read and the refresh each read it');
      await expectLater(picarto.resolve(_room, line: const SelectionRef('3')), throwsA(isA<StateError>()));
    });
  });

  group('test_picartoSource_search', () {
    test('test_profilesKeepTheirOfflineStateAndAreReadAsPeopleToo', () async {
      final (transport, picarto) = _source(<String, List<String>>{
        _searchKey: <String>[
          jsonEncode(<String, Object?>{
            'searchProfiles': <String, Object?>{
              'data': <Object?>[_row(), _row(name: 'asleep', id: 9, online: false), _row(name: 'art', id: 11)],
              'count': 1200,
            },
          }),
        ],
      });
      final rooms = await picarto.search(const SearchQuery(keyword: 'art', page: PageRequest(page: 1, pageSize: 20)));
      // The repeat of `art` is one row; the offline profile is listed as offline, not hidden.
      expect(rooms.items.map((item) => item.ref.contentId), <String>['art', 'asleep']);
      final anchors = await picarto.searchAnchors(const SearchQuery(keyword: 'art'));
      expect(anchors.items.first.isLiveNow, isTrue);
      expect(anchors.items.last.isLiveNow, isFalse);
      expect(anchors.items.first.fans, isNull);
      expect(transport.requests.last.uri.queryParameters['tag_search'], 'false');
    });

    test('test_continuationIsDecidedOnReturnedRowsNotTheClaimedCount', () async {
      final (_, picarto) = _source(<String, List<String>>{
        _searchKey: <String>[
          jsonEncode(<String, Object?>{
            'searchProfiles': <String, Object?>{
              'data': <Object?>[_row()],
              'count': 900,
            },
          }),
        ],
      });
      final page = await picarto.search(const SearchQuery(keyword: 'art', page: PageRequest(page: 1, pageSize: 20)));
      // One row came back out of twenty asked for, whatever the endpoint says its total is.
      expect(page.hasMore, isFalse);
    });

    test('test_anOverlongTermIsRefusedRatherThanSent', () async {
      final (transport, picarto) = _source(<String, List<String>>{
        _searchKey: <String>['{}'],
      });
      await expectLater(picarto.search(SearchQuery(keyword: 'x' * 101)), throwsA(isA<PicartoFailure>()));
      expect(transport.requestsTo(_searchKey), 0);
    });
  });
}
