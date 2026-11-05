import 'dart:convert';

import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/steambroadcast/api/steambroadcast_endpoints.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_failure.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_json.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_room_parser.dart';
import 'package:test/test.dart';

/// A 64-bit Steam id the platform accepts.
const String _id = '76561198000000000';

/// Another broadcaster.
const String _other = '76561198000000001';

/// The CDN host of a broadcast's manifests.
const String _host = 'p7d9.steamcontent.com';

/// Steam's own default avatar, which is no avatar.
const String _defaultHash = 'fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb';

/// An `hls_url` that passes every rule [masterOf] checks.
Uri _masterUrl({String host = _host, String steamId = _id, String origin = 'xyz.steamserver.net', String extra = ''}) =>
    Uri.parse('https://$host/broadcast/$steamId/12345/hls_manifest/0/$host/master.m3u8?broadcast_origin=$origin$extra');

final Uri _master = _masterUrl();

/// A child (variant or rendition) of a master on [host].
String _child(String host, String name, {String origin = 'xyz.steamserver.net'}) =>
    'https://$host/broadcast/$_id/12345/hls_manifest/0/$host/$name?broadcast_origin=$origin';

/// One `#EXT-X-STREAM-INF` and its address.
String _variant({
  required String resolution,
  required int bandwidth,
  String file = 'v.m3u8',
  String host = _host,
  String codecs = 'avc1.640028,mp4a.40.2',
  String? frameRate,
  String? audio = 'audio',
}) =>
    '#EXT-X-STREAM-INF:BANDWIDTH=$bandwidth,RESOLUTION=$resolution'
    '${frameRate == null ? '' : ',FRAME-RATE=$frameRate'}'
    '${audio == null ? '' : ',AUDIO="$audio"'}'
    ',CODECS="$codecs"\n${_child(host, file)}';

/// A master body of [entries].
String _body(List<String> entries) => ['#EXTM3U', ...entries].join('\n');

/// A `getbroadcastmpd` answer.
String _mpd([Map<String, Object?>? override]) => jsonEncode({
  'success': 'ready',
  'title': '直播标题',
  'num_viewers': 812,
  'broadcastid': '98765',
  'hls_url': '${_masterUrl()}',
  ...?override,
});

/// A `Broadcast_Card` of the trending fragment.
String _card(
  String steamId, {
  String? author,
  String type = '某游戏: Broadcast',
  String game = '某游戏',
  String? viewers,
  String? preview,
  String? icon,
}) =>
    '''
<div class="Broadcast_Card">
  <a href="https://steamcommunity.com/broadcast/watch/$steamId"></a>
  <div class="apphub_CardContentType">$type</div>
  <div class="apphub_CardContentTitle">$game</div>
  ${author == null ? '' : '<div class="apphub_CardContentAuthorName"><a href="#">$author</a></div>'}
  ${viewers == null ? '' : '<div class="apphub_CardContentViewers">$viewers</div>'}
  <img class="apphub_CardContentPreviewImage" src="${preview ?? 'https://steambroadcast.akamaized.net/broadcast/$steamId/preview.jpg'}">
  <div class="appHubIconHolder"><img src="${icon ?? 'https://avatars.cloudflare.steamstatic.com/${'a' * 40}_medium.jpg'}"></div>
</div>''';

/// The trending fragment of [cards] with its paging form.
String _directory(List<String> cards, {String? nextPage, String? nextOffset}) =>
    '${cards.join()}<form><input name="p" value="${nextPage ?? ''}"><input name="broadcastsoffset" value="${nextOffset ?? ''}"></form>';

Object? _kindOf(void Function() answer) {
  try {
    answer();
    return null;
  } on SteambroadcastFailure catch (failure) {
    return failure.kind;
  }
}

SteambroadcastFailure _failure(void Function() answer) {
  try {
    answer();
  } on SteambroadcastFailure catch (failure) {
    return failure;
  }
  throw StateError('the answer was accepted');
}

SteambroadcastBroadcast _broadcast({
  SteambroadcastState state = SteambroadcastState.live,
  String broadcaster = '',
  String title = '',
  String game = '',
  String cover = '',
  String avatar = '',
  int? viewers,
  LiveRestriction? restriction,
  String? broadcastId,
  Uri? master,
  bool masterChecked = false,
  LiveStreamCodec? codec,
  List<SteambroadcastVariant> variants = const [],
  SteambroadcastFailure? mediaError,
}) => SteambroadcastBroadcast(
  steamId: _id,
  state: state,
  broadcaster: broadcaster,
  title: title,
  game: game,
  cover: cover,
  avatar: avatar,
  viewers: viewers,
  restriction: restriction,
  broadcastId: broadcastId,
  master: master,
  masterChecked: masterChecked,
  codec: codec,
  variants: variants,
  mediaError: mediaError,
);

void main() {
  group('the one area and the answer gates', () {
    test('the site offers a single trending area and knows its id', () {
      final areas = SteambroadcastRoomParser.areas();
      expect(areas.single.areaId, SteambroadcastEndpoints.areaId);
      expect(areas.single.areaName, '热门社区直播');
      expect(areas.single.parentAreaId, 'steambroadcast');
      expect(areas.single.parentAreaName, 'Steam Broadcasts');
      expect(SteambroadcastRoomParser.isArea('trending'), isTrue);
      expect(SteambroadcastRoomParser.isArea(''), isFalse);
    });

    test('every status keeps its own kind, and an over-long answer is api-changed', () {
      expect(_kindOf(() => SteambroadcastJson.checkBody('x', 'watch page', 400)), SteambroadcastFailureKind.apiChanged);
      expect(_kindOf(() => SteambroadcastJson.checkBody('x', 'watch page', 422)), SteambroadcastFailureKind.apiChanged);
      expect(
        _kindOf(() => SteambroadcastJson.checkBody('x', 'watch page', 401)),
        SteambroadcastFailureKind.riskControl,
      );
      expect(
        _kindOf(() => SteambroadcastJson.checkBody('x', 'watch page', 403)),
        SteambroadcastFailureKind.riskControl,
      );
      expect(_kindOf(() => SteambroadcastJson.checkBody('x', 'watch page', 404)), SteambroadcastFailureKind.notFound);
      expect(
        _kindOf(() => SteambroadcastJson.checkBody('x', 'watch page', 429)),
        SteambroadcastFailureKind.rateLimited,
      );
      expect(_kindOf(() => SteambroadcastJson.checkBody('x', 'watch page', 302)), SteambroadcastFailureKind.network);
      expect(_kindOf(() => SteambroadcastJson.checkBody('x', 'watch page', 500)), SteambroadcastFailureKind.network);
      expect(_kindOf(() => SteambroadcastJson.checkBody('x', 'watch page', 200)), isNull);
      expect(
        _kindOf(() => SteambroadcastJson.checkBody('漢' * 1400000, 'watch page', 200)),
        SteambroadcastFailureKind.apiChanged,
        reason: 'the byte length is what counts, not the number of characters',
      );
    });

    test('the text gates of the readers', () {
      expect(SteambroadcastJson.clean('  a \n b  '), 'a b');
      expect(SteambroadcastJson.lenientText('&amp;号'), '&号');
      expect(SteambroadcastJson.lenientText(7), isEmpty, reason: 'a number is not card text');
      expect(SteambroadcastJson.optionalText(null, 'title'), isEmpty);
      expect(_kindOf(() => SteambroadcastJson.optionalText(7, 'title')), SteambroadcastFailureKind.apiChanged);
      expect(_failure(() => SteambroadcastJson.requiredText('  ', 'title')).message, contains('is empty'));
      expect(SteambroadcastJson.flag(true) && SteambroadcastJson.flag(1) && !SteambroadcastJson.flag(0), isTrue);
      expect(SteambroadcastJson.flag('1'), isFalse, reason: 'a flag is a boolean or a number, not text');
      expect(SteambroadcastJson.viewers('12'), 12);
      expect(SteambroadcastJson.viewers(12.9), 12, reason: 'a finite number is truncated');
      expect(SteambroadcastJson.viewers(-1), isNull, reason: 'a negative count says nothing');
      expect(SteambroadcastJson.viewers(double.nan), isNull);
      expect(SteambroadcastJson.snippet(' a\nb '), 'a b');
      expect(_failure(() => SteambroadcastJson.object('[]', 'miniprofile', 200)).message, contains('not an object'));
    });
  });

  group('the viewer count of a card', () {
    test('the digits before the word are the count', () {
      expect(SteambroadcastRoomParser.viewerCount('6,763 viewers'), 6763);
      expect(SteambroadcastRoomParser.viewerCount(' 1 Viewer '), 1, reason: 'the singular is the same figure');
      expect(SteambroadcastRoomParser.viewerCount('1 234 viewers online'), 1234);
      expect(SteambroadcastRoomParser.viewerCount('1.234 viewers'), 1234);
      expect(SteambroadcastRoomParser.viewerCount('0 viewers'), 0);
      expect(SteambroadcastRoomParser.viewerCount('viewers'), isNull, reason: 'no figure is no count');
      expect(SteambroadcastRoomParser.viewerCount('1234'), isNull, reason: 'the word has to be there');
      expect(SteambroadcastRoomParser.viewerCount('x 12 viewers'), isNull);
      expect(
        SteambroadcastRoomParser.viewerCount('1' * 13 + ' viewers'),
        isNull,
        reason: 'thirteen digits is not a count',
      );
    });

    test('a search over a page matches id, name, title or game', () {
      final one = _broadcast(broadcaster: '主播甲', title: '玩 LOL', game: 'League');
      final two = _broadcast(broadcaster: '乙');
      expect(SteambroadcastRoomParser.filter([one, two], _id).length, 2, reason: 'both carry this id');
      expect(SteambroadcastRoomParser.filter([one], 'lo').single.title, '玩 LOL');
      expect(SteambroadcastRoomParser.filter([one], 'lea').single.game, 'League');
      expect(SteambroadcastRoomParser.filter([one], '甲').single.broadcaster, '主播甲');
      expect(SteambroadcastRoomParser.filter([one], '没有'), isEmpty);
      expect(SteambroadcastRoomParser.filter([one, two], '').length, 2, reason: 'an empty query refuses nothing');
    });
  });

  group('the trending directory', () {
    test('a card gives its identity, its title, its streamer and its pictures', () {
      final body = _directory(
        [
          _card(_id, author: '主播甲', viewers: '6,763 viewers'),
          _card(_other, author: _other, type: '', viewers: '12 viewers'),
        ],
        nextPage: '1',
        nextOffset: '0',
      );
      final page = SteambroadcastRoomParser.directory(body, page: 0);
      expect(page.hasMore, isTrue);
      expect(page.broadcasts, hasLength(2));
      final first = page.broadcasts.first;
      expect(first.steamId, _id);
      expect(first.broadcaster, '主播甲');
      expect(first.title, '某游戏', reason: 'the content type is the title with its ": Broadcast" removed');
      expect(first.game, '某游戏');
      expect(first.viewers, 6763);
      expect(first.state, SteambroadcastState.live, reason: 'the directory only lists what is on air');
      expect(first.cover, 'https://steambroadcast.akamaized.net/broadcast/$_id/preview.jpg');
      expect(first.avatar, 'https://avatars.cloudflare.steamstatic.com/${'a' * 40}_full.jpg', reason: '184 px, not 32');
      expect(page.broadcasts[1].title, '某游戏', reason: 'a card with no content type is titled by its game');
      expect(page.broadcasts[1].broadcaster, isEmpty, reason: 'a name that is only the id names nobody');
    });

    test('the same broadcaster is listed once and a card without an id is not one', () {
      final page = SteambroadcastRoomParser.directory(
        _directory(
          [
            _card(_id, author: '甲'),
            _card(_id, author: '同一个主播'),
            '<div class="Broadcast_Card"><div class="apphub_CardContentTitle">没有链接</div></div>',
            _card('not-a-steam-id'),
          ],
          nextPage: '1',
          nextOffset: '0',
        ),
        page: 0,
      );
      expect(page.broadcasts.map((broadcast) => broadcast.broadcaster), ['甲']);
    });

    test('the next page is the one the hidden form names', () {
      bool hasMore({required int page, String? next, String? offset, bool cards = true}) =>
          SteambroadcastRoomParser.directory(
            _directory(cards ? [_card(_id)] : const <String>[], nextPage: next, nextOffset: offset),
            page: page,
          ).hasMore;
      expect(hasMore(page: 2, next: '3', offset: '20'), isTrue);
      expect(
        hasMore(page: 2, next: '4', offset: '20'),
        isFalse,
        reason: 'a skipped page is not the next one',
      );
      expect(
        hasMore(page: 2, next: '3', offset: '10'),
        isFalse,
        reason: 'the offset must be the page times its size',
      );
      expect(hasMore(page: 2, next: '3', offset: 'x'), isFalse);
      expect(hasMore(page: 0), isFalse, reason: 'an empty form names no next page');
      expect(
        hasMore(page: 0, next: '1', offset: '0', cards: false),
        isFalse,
        reason: 'an empty page has no next one however the form reads',
      );
    });

    test('a broken card loses only itself', () {
      final overLong =
          '<div class="Broadcast_Card"> <a href="https://steamcommunity.com/broadcast/watch/$_id"> '
          '<div class="apphub_CardContentViewers">${'9' * 70000} viewers</div></a></div>';
      final page = SteambroadcastRoomParser.directory(_directory([overLong, _card(_id, author: '甲')]), page: 0);
      expect(page.broadcasts, hasLength(1), reason: 'the card that overflows the text gate is dropped');
      expect(page.broadcasts.single.broadcaster, '甲');
    });

    test('a bad status is a bad answer', () {
      expect(
        _kindOf(() => SteambroadcastRoomParser.directory('<html/>', page: 0, status: 503)),
        SteambroadcastFailureKind.network,
      );
    });
  });

  group('the watch page and the mini profile', () {
    String page(String config, [String head = '']) =>
        '<html><head>$head</head><body><div id="application_config" data-broadcastsinfo=\'$config\'></div></body></html>';
    const config = '{"steamid":"$_id"}';

    test('the page must name the account it was asked for', () {
      expect(
        SteambroadcastRoomParser.broadcaster(
          page(config, '<meta property="og:title" content="Steam Community :: 主播甲 :: Broadcast">'),
          steamId: _id,
        ),
        '主播甲',
      );
      expect(
        _kindOf(() => SteambroadcastRoomParser.broadcaster('<html><body></body></html>', steamId: _id)),
        SteambroadcastFailureKind.notFound,
        reason: 'a page without the broadcast config names no room',
      );
      expect(
        _kindOf(() => SteambroadcastRoomParser.broadcaster(page('not json'), steamId: _id)),
        SteambroadcastFailureKind.apiChanged,
      );
      expect(
        _kindOf(() => SteambroadcastRoomParser.broadcaster(page('[1,2]'), steamId: _id)),
        SteambroadcastFailureKind.apiChanged,
      );
      expect(
        _failure(() => SteambroadcastRoomParser.broadcaster(page('{"steamid":"$_other"}'), steamId: _id)).message,
        contains('names $_other'),
      );
    });

    test('the name is og:title, else the title, else nobody', () {
      expect(
        SteambroadcastRoomParser.broadcaster(
          page(config, '<title>Steam Community :: 乙 :: Broadcast</title>'),
          steamId: _id,
        ),
        '乙',
        reason: 'with no og:title the page title names the streamer',
      );
      expect(
        SteambroadcastRoomParser.broadcaster(page(config, '<title>随便一个标题</title>'), steamId: _id),
        isEmpty,
        reason: 'a title outside the broadcast pattern names nobody',
      );
      expect(
        SteambroadcastRoomParser.broadcaster(
          page(config, '<meta property="og:title" content="Steam Community :: $_id :: Broadcast">'),
          steamId: _id,
        ),
        isEmpty,
        reason: 'Steam writes the id for an account that does not exist',
      );
      expect(
        SteambroadcastRoomParser.broadcaster(
          page(config, '<meta property="og:title" content="Steam Community :: A&amp;B :: Broadcast">'),
          steamId: _id,
        ),
        'A&B',
        reason: 'the page writes the name as character references',
      );
      expect(
        SteambroadcastRoomParser.broadcaster(page(config, '<meta property="og:title" content="没有模式">'), steamId: _id),
        isEmpty,
      );
    });

    test('the mini profile gives the name and the avatar at 184 px', () {
      String profile([Map<String, Object?>? override]) => jsonEncode({
        'persona_name': '主播甲',
        'avatar_url': 'https://avatars.cloudflare.steamstatic.com/${'b' * 40}_medium.jpg',
        ...?override,
      });
      final read = SteambroadcastRoomParser.profile(profile(), steamId: _id);
      expect(read.name, '主播甲');
      expect(read.avatar, 'https://avatars.cloudflare.steamstatic.com/${'b' * 40}_full.jpg');
      expect(SteambroadcastRoomParser.profile(profile({'persona_name': _id}), steamId: _id).name, isEmpty);
      expect(
        SteambroadcastRoomParser.profile(
          profile({
            'persona_name': '主播 &amp; 甲',
            'avatar_url': 'https://avatars.cloudflare.steamstatic.com/${_defaultHash}_full.jpg',
          }),
          steamId: _id,
        ).name,
        '主播 & 甲',
        reason: 'the name arrives as character references',
      );
      expect(
        SteambroadcastRoomParser.profile(
          profile({'avatar_url': 'https://cdn.example.com/${'c' * 40}.jpg'}),
          steamId: _id,
        ).avatar,
        'https://cdn.example.com/${'c' * 40}.jpg',
        reason: 'a picture on another https host is taken as it is',
      );
      expect(
        SteambroadcastRoomParser.profile(
          profile({'avatar_url': 'https://avatars.cloudflare.steamstatic.com/$_defaultHash.jpg'}),
          steamId: _id,
        ).avatar,
        isEmpty,
        reason: "Steam's own default avatar is no avatar",
      );
      expect(
        _kindOf(() => SteambroadcastRoomParser.profile(profile({'persona_name': 7}), steamId: _id)),
        SteambroadcastFailureKind.apiChanged,
      );
      expect(_kindOf(() => SteambroadcastRoomParser.profile('[]', steamId: _id)), SteambroadcastFailureKind.apiChanged);
      expect(
        _kindOf(() => SteambroadcastRoomParser.profile('<html/>', steamId: _id, status: 403)),
        SteambroadcastFailureKind.riskControl,
      );
    });
  });

  group('getbroadcastinfo, the state of a refresh', () {
    SteambroadcastBroadcast info([Map<String, Object?>? override]) =>
        SteambroadcastRoomParser.info(jsonEncode({'success': 1, 'is_online': true, ...?override}), steamId: _id);

    test('success and is_online together decide whether it is on air', () {
      expect(info().state, SteambroadcastState.live);
      expect(info({'is_replay': true}).state, SteambroadcastState.replay);
      expect(info({'is_online': false}).state, SteambroadcastState.offline);
      expect(info({'is_online': 0}).state, SteambroadcastState.offline);
      expect(info({'success': 42}).state, SteambroadcastState.offline);
      expect(info({'success': '1'}).state, SteambroadcastState.live, reason: 'a status written as text is still one');
      expect(_failure(() => info({'success': 2})).message, contains('success 2'));
      expect(_kindOf(() => info({'success': null})), SteambroadcastFailureKind.apiChanged);
      final offline = SteambroadcastRoomParser.info(
        jsonEncode({'success': 42, 'title': '旧的标题', 'viewer_count': 20}),
        steamId: _id,
        profile: (name: '主播甲', avatar: 'https://cdn.example.com/${'b' * 40}_full.jpg'),
      );
      expect(offline.state, SteambroadcastState.offline);
      expect(offline.broadcaster, '主播甲', reason: 'the streamer is still the streamer');
      expect(offline.title, isEmpty);
      expect(offline.viewers, isNull, reason: 'an ended broadcast is not counted');
    });

    test('the fields that only fill the card are read leniently', () {
      SteambroadcastBroadcast of([Map<String, Object?>? override]) => SteambroadcastRoomParser.info(
        jsonEncode({
          'success': 1,
          'is_online': true,
          'title': '直播标题',
          'app_title': '某&amp;游戏',
          'thumbnail_url': 'https://steambroadcast.akamaized.net/broadcast/$_id/thumb.jpg',
          'viewer_count': 42,
          ...?override,
        }),
        steamId: _id,
      );
      final room = of();
      expect(room.title, '直播标题');
      expect(room.game, '某&游戏', reason: 'the game arrives as HTML characters');
      expect(room.cover, 'https://steambroadcast.akamaized.net/broadcast/$_id/thumb.jpg');
      expect(room.viewers, 42);
      expect(of({'title': ''}).title, '某&游戏', reason: 'with no title the game names it');
      expect(of({'title': 7}).title, '某&游戏', reason: 'a number is not a title, and not an error either');
      expect(of({'viewer_count': -3}).viewers, isNull);
      expect(
        of({'thumbnail_url': 'http://steambroadcast.akamaized.net/broadcast/$_id/t.jpg'}).cover,
        isEmpty,
        reason: "a thumbnail only counts on https and on Steam's own host",
      );
      expect(of({'thumbnail_url': 'https://steambroadcast.akamaized.net/other/t.jpg'}).cover, isEmpty);
    });
  });

  group('getbroadcastmpd, the state of room entry', () {
    SteambroadcastBroadcast mpd([Map<String, Object?>? override]) =>
        SteambroadcastRoomParser.broadcast(_mpd(override), steamId: _id);

    test('each success word is its own state', () {
      final ready = mpd();
      expect(ready.state, SteambroadcastState.live);
      expect(ready.restriction, LiveRestriction.none);
      expect(ready.master, _master);
      expect(ready.mediaError, isNull);
      expect(ready.title, '直播标题');
      expect(ready.viewers, 812);
      expect(ready.broadcastId, '98765');
      expect(mpd({'is_replay': true}).state, SteambroadcastState.replay);
      final subscription = mpd({'success': 'missing_subscription'});
      expect(subscription.state, SteambroadcastState.live);
      expect(subscription.restriction, LiveRestriction.subscribersOnly);
      expect(subscription.master, isNull, reason: 'only a ready answer hands out a master');
      expect(mpd({'success': 'UNAVAILABLE'}).state, SteambroadcastState.offline, reason: 'the word is read any case');
      expect(mpd({'success': 'not_live'}).state, SteambroadcastState.offline);
      expect(mpd({'success': 'no_broadcast'}).state, SteambroadcastState.offline);
      expect(mpd({'success': 'offline'}).state, SteambroadcastState.offline);
      expect(mpd({'success': 'waiting'}).state, SteambroadcastState.unknown, reason: 'waiting is not offline');
      expect(mpd({'success': 'anything'}).state, SteambroadcastState.unknown);
      expect(mpd({'success': 'user_restricted'}).state, SteambroadcastState.accountRestricted);
      expect(_kindOf(() => mpd({'success': null})), SteambroadcastFailureKind.apiChanged);
      expect(_kindOf(() => mpd({'success': 7})), SteambroadcastFailureKind.apiChanged);
      expect(_kindOf(() => mpd({'title': 7})), SteambroadcastFailureKind.apiChanged);
    });

    test('the broadcast id is digits without a leading zero', () {
      String? idOf(Object? value) =>
          SteambroadcastRoomParser.broadcast(_mpd({'broadcastid': value}), steamId: _id).broadcastId;
      expect(idOf(null), isNull);
      expect(idOf('0'), isNull);
      expect(idOf('0123'), isNull);
      expect(idOf('abc'), isNull);
      expect(idOf(4242), '4242');
      expect(idOf(-1), isNull);
      expect(idOf('1' * 21), isNull, reason: 'twenty digits is the most a Steam id carries');
    });

    test("the master address is checked, and a bad one is the media's problem only", () {
      SteambroadcastBroadcast of(String url) =>
          SteambroadcastRoomParser.broadcast(_mpd({'hls_url': url}), steamId: _id);
      String address({
        String scheme = 'https',
        String host = _host,
        String steamId = _id,
        String path = '12345',
        String directory = _host,
        String file = 'master.m3u8',
        String? origin = 'xyz.steamserver.net',
        String suffix = '',
        int? port,
      }) {
        final authority = '$host${port == null ? '' : ':$port'}';
        final query = origin == null ? '' : '?broadcast_origin=$origin';
        return '$scheme://$authority/broadcast/$steamId/$path/hls_manifest/0/$directory/$file$query$suffix';
      }

      expect(of(address()).master, _master);
      expect(
        of(address(host: 'steamcontent.com', directory: 'steamcontent.com', origin: 'steamserver.net')).master?.host,
        'steamcontent.com',
      );
      expect(of(address(port: 443)).master?.port, 443);
      for (final url in [
        address(scheme: 'http'),
        address(steamId: _other),
        address(host: 'evil.example.com'),
        address(directory: 'evil.example.com'),
        address(path: '0'),
        address(file: 'playlist.m3u8'),
        address(origin: null),
        address(origin: 'l7d9.example.net'),
        address(origin: 'steamserver.net.evil.example'),
        address(suffix: '#f'),
        address(suffix: '&x=1 2'),
        'https://u:p@$_host/broadcast/$_id/12345/hls_manifest/0/$_host/master.m3u8?broadcast_origin=xyz.steamserver.net',
        'https://$_host:8443/broadcast/$_id/12345/hls_manifest/0/$_host/master.m3u8?broadcast_origin=xyz.steamserver.net',
        address(host: 'x' * 200 + '.steamcontent.com'),
      ]) {
        final broadcast = of(url);
        expect(broadcast.master, isNull, reason: url);
        expect(broadcast.mediaError?.kind, SteambroadcastFailureKind.apiChanged, reason: url);
        expect(broadcast.state, SteambroadcastState.live, reason: 'a broken address never changes the state');
      }
      final number = SteambroadcastRoomParser.broadcast(_mpd({'hls_url': 7}), steamId: _id);
      expect(
        number.mediaError?.kind,
        SteambroadcastFailureKind.apiChanged,
        reason: "a hls_url that is not text is the media's problem, not the room's",
      );
      expect(number.state, SteambroadcastState.live);
    });

    test('the CDN parameters are appended after their own rules', () {
      SteambroadcastBroadcast cdn(Object? parameters) =>
          SteambroadcastRoomParser.broadcast(_mpd({'cdn_auth_url_parameters': parameters}), steamId: _id);
      expect(cdn(null).master, _master);
      expect(cdn('   ').master, _master);
      expect(cdn('&token=abc').master, _masterUrl(extra: '&token=abc'));
      expect(cdn('?token=abc').master, _masterUrl(extra: '&token=abc'), reason: 'a leading ? becomes an &');
      expect(cdn('a=1&b=2&c=3').master?.query, 'broadcast_origin=xyz.steamserver.net&a=1&b=2&c=3');
      for (final parameters in [
        7,
        'broadcast_origin=evil.net',
        'a=1&b=2&c=3&d=4&e=5&f=6&g=7&h=8&i=9&j=10&k=11&l=12&m=13&n=14&o=15&p=16&q=17',
        'a=',
        '=1',
        'a=1&b=${'y' * 2049}',
        '${'x' * 4097}=1',
        'a=1 b=2',
        'a=1#frag',
        '&',
      ]) {
        final broadcast = cdn(parameters);
        expect(broadcast.mediaError?.kind, SteambroadcastFailureKind.apiChanged, reason: '$parameters');
        expect(broadcast.master, isNull, reason: '$parameters');
      }
    });
  });

  group('the profile XML of a custom address', () {
    test('the steamID64 is the id, an error says the profile does not exist', () {
      expect(SteambroadcastRoomParser.steamIdOfProfileXml('<response><steamID64>  $_id  </steamID64></response>'), _id);
      expect(SteambroadcastRoomParser.steamIdOfProfileXml('<response><error>Not Found</error></response>'), isNull);
      expect(
        _kindOf(() => SteambroadcastRoomParser.steamIdOfProfileXml('<response><steamID64>123</steamID64></response>')),
        SteambroadcastFailureKind.apiChanged,
        reason: 'a number that is not a 64-bit Steam id is not a profile',
      );
      expect(
        _kindOf(() => SteambroadcastRoomParser.steamIdOfProfileXml('<response/>')),
        SteambroadcastFailureKind.apiChanged,
      );
      expect(
        _kindOf(() => SteambroadcastRoomParser.steamIdOfProfileXml('x', status: 404)),
        SteambroadcastFailureKind.notFound,
      );
    });
  });

  group('the pictures', () {
    test('a Steam avatar is asked at 184 px and the default is none', () {
      final hash = 'e' * 40;
      expect(
        avatar('https://avatars.cloudflare.steamstatic.com/${hash}_medium.jpg'),
        'https://avatars.cloudflare.steamstatic.com/${hash}_full.jpg',
      );
      expect(
        avatar('https://avatars.cloudflare.steamstatic.com/$hash.jpg'),
        'https://avatars.cloudflare.steamstatic.com/${hash}_full.jpg',
      );
      expect(avatar('https://avatars.cloudflare.steamstatic.com/$_defaultHash.jpg'), isEmpty);
      expect(avatar('https://cdn.example.com/pic.png?a=1#b'), isEmpty, reason: 'a fragment is not one');
      expect(avatar('http://cdn.example.com/pic.png'), isEmpty);
      expect(avatar('https://u:p@cdn.example.com/pic.png'), isEmpty);
      expect(avatar('//cdn.example.com/pic.png'), isEmpty);
      expect(avatar(''), isEmpty);
      expect(avatar('https://cdn.example.com/${'f' * 40}.jpg'), 'https://cdn.example.com/${'f' * 40}.jpg');
    });

    test("a thumbnail is Steam's own host under the broadcaster's path", () {
      expect(
        thumbnail('https://steambroadcast.akamaized.net/broadcast/$_id/x/1.jpg', _id),
        'https://steambroadcast.akamaized.net/broadcast/$_id/x/1.jpg',
      );
      expect(thumbnail('https://steambroadcast.akamaized.net/broadcast/$_other/1.jpg', _id), isEmpty);
      expect(thumbnail('https://cdn.akamaized.net/broadcast/$_id/1.jpg', _id), isEmpty);
      expect(thumbnail('https://steambroadcast.akamaized.net/broadcast/$_id/1.jpg#x', _id), isEmpty);
      expect(thumbnail(null, _id), isEmpty);
    });
  });

  group('the HLS master check', () {
    test('a master is a list of Steam children and names one codec family', () {
      expect(
        SteambroadcastRoomParser.checkMaster(
          _body([
            _variant(resolution: '1280x720', bandwidth: 1),
            _variant(resolution: '1920x1080', bandwidth: 2, file: 'b.m3u8'),
          ]),
          master: _master,
          steamId: _id,
        ),
        LiveStreamCodec.avc,
      );
      expect(
        SteambroadcastRoomParser.checkMaster(
          _body([_variant(resolution: '1280x720', bandwidth: 1, codecs: 'hvc1.1.6.L93.90')]),
          master: _master,
          steamId: _id,
        ),
        LiveStreamCodec.hevc,
      );
      expect(
        SteambroadcastRoomParser.checkMaster(
          _body([_variant(resolution: '1280x720', bandwidth: 1, codecs: 'mp4a.40.2')]),
          master: _master,
          steamId: _id,
        ),
        isNull,
        reason: 'an audio codec names no video',
      );
      expect(
        SteambroadcastRoomParser.checkMaster(
          _body([
            _variant(resolution: '1280x720', bandwidth: 1),
            _variant(resolution: '1920x1080', bandwidth: 2, file: 'b.m3u8', codecs: 'hvc1.1.6.L93.90'),
          ]),
          master: _master,
          steamId: _id,
        ),
        isNull,
        reason: 'variants that name two families name neither',
      );
      expect(
        SteambroadcastRoomParser.checkMaster(
          _body([_variant(resolution: '1280x720', bandwidth: 1, audio: null)]),
          master: _master,
          steamId: _id,
        ),
        LiveStreamCodec.avc,
        reason: 'a master without a rendition is still a master',
      );
    });

    test('anything the player cannot trust is api-changed', () {
      expect(
        _kindOf(() => SteambroadcastRoomParser.checkMaster('not a playlist', master: _master, steamId: _id)),
        SteambroadcastFailureKind.apiChanged,
      );
      expect(
        _failure(() => SteambroadcastRoomParser.checkMaster('#EXTM3U', master: _master, steamId: _id)).message,
        contains('0 variants'),
      );
      expect(
        _failure(
          () => SteambroadcastRoomParser.checkMaster(
            _body([
              for (var index = 0; index < 17; index++)
                _variant(resolution: '1280x720', bandwidth: index + 1, file: 'v$index.m3u8'),
            ]),
            master: _master,
            steamId: _id,
          ),
        ).message,
        contains('17 variants'),
      );
      expect(
        _failure(
          () => SteambroadcastRoomParser.checkMaster(
            _body([_variant(resolution: '1280x720', bandwidth: 1, host: 'evil.example.com')]),
            master: _master,
            steamId: _id,
          ),
        ).message,
        contains('variant'),
        reason: 'a child on another host than the master is not one',
      );
      expect(
        _failure(
          () => SteambroadcastRoomParser.checkMaster(
            _body([
              _variant(resolution: '1280x720', bandwidth: 1),
              '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="a"',
            ]),
            master: _master,
            steamId: _id,
          ),
        ).message,
        contains('rendition'),
        reason: 'a rendition without an address is not one',
      );
      expect(
        _failure(
          () => SteambroadcastRoomParser.checkMaster(
            '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=1280x720',
            master: _master,
            steamId: _id,
          ),
        ).message,
        contains('variant missing'),
      );
      expect(
        SteambroadcastRoomParser.checkMaster(
          _body([
            '#EXT-X-STREAM-INF:BANDWIDTH=1,RESOLUTION=1280x720,CODECS="avc1.42001E"',
            '#EXT-X-INDEPENDENT-SEGMENTS',
            _child(_host, 'one.m3u8'),
          ]),
          master: _master,
          steamId: _id,
        ),
        LiveStreamCodec.avc,
        reason: 'the address is the next line that is not a comment',
      );
      expect(
        _kindOf(() => SteambroadcastRoomParser.checkMaster('#EXTM3U', master: _master, steamId: _id, status: 403)),
        SteambroadcastFailureKind.riskControl,
      );
    });
  });

  group('the variants of a checked master', () {
    test('best first, one per name, and only when there is a choice', () {
      final text = _body([
        '#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="a",URI="${_child(_host, 'audio.m3u8')}"',
        _variant(resolution: '1280x720', bandwidth: 1000000, file: 'a.m3u8'),
        _variant(resolution: '1920x1080', bandwidth: 3000000, frameRate: '59.940', file: 'b.m3u8'),
        _variant(resolution: '1920x1080', bandwidth: 2000000, frameRate: '59.940', file: 'c.m3u8'),
        _variant(resolution: '1280x720', bandwidth: 4000000, audio: 'missing', file: 'd.m3u8'),
        _variant(resolution: '640x360', bandwidth: 500000, audio: null, file: 'e.m3u8'),
      ]);
      final variants = SteambroadcastRoomParser.variants(text, master: _master);
      expect(variants.map((entry) => entry.id), ['1080p60', '720p', '360p']);
      expect(variants.first.bandwidth, 3000000, reason: 'the same name keeps its highest bandwidth');
      expect(variants.first.frameRate, 59.94);
      expect(variants.first.width, 1920);
      expect(variants.first.codec, LiveStreamCodec.avc);
      expect(variants[1].bandwidth, 1000000);
      expect(variants[2].id, '360p', reason: 'a variant with no audio group is still a variant');
      expect(
        SteambroadcastRoomParser.variants(
          _body([
            _variant(resolution: '1280x720', bandwidth: 1, file: 'a.m3u8'),
            _variant(resolution: '1280x720', bandwidth: 2, file: 'b.m3u8'),
          ]),
          master: _master,
        ),
        isEmpty,
        reason: 'one quality is no choice',
      );
      expect(
        SteambroadcastRoomParser.variants(
          '#EXTM3U\n#EXT-X-TARGETDURATION:4\n#EXTINF:4\nx.ts\n#EXT-X-ENDLIST',
          master: _master,
        ),
        isEmpty,
        reason: 'a media playlist is not a master',
      );
      expect(
        SteambroadcastRoomParser.variants(
          _body([
            _variant(resolution: '1280x720', bandwidth: 1, file: 'a.m3u8', codecs: 'hvc1.1.6.L93.90', audio: null),
            _variant(resolution: '640x360', bandwidth: 2, file: 'b.m3u8', audio: null),
          ]),
          master: _master,
        ).map((entry) => entry.codec),
        [LiveStreamCodec.hevc, LiveStreamCodec.avc],
      );
    });

    test('the names of a variant, and their shape', () {
      expect(SteambroadcastRoomParser.variantId(1080, 59.94), '1080p60');
      expect(SteambroadcastRoomParser.variantId(1080, 30), '1080p', reason: 'thirty frames is not part of the name');
      expect(SteambroadcastRoomParser.variantId(720, 0), '720p');
      expect(SteambroadcastRoomParser.variantId(480, 29.97), '480p');
      expect(SteambroadcastRoomParser.variantId(480, 59.5), '480p60', reason: 'the rate is rounded, not truncated');
      for (final id in ['720p', '1080p60', '99999p1234']) {
        expect(SteambroadcastRoomParser.isVariantId(id), isTrue, reason: id);
      }
      for (final id in ['auto', '0p', '720p0', '1000000p', '720', 'p60', '720P']) {
        expect(SteambroadcastRoomParser.isVariantId(id), isFalse, reason: id);
      }
      expect(videoCodecs('#EXT-X-STREAM-INF:CODECS="avc1.42,hvc1.1"'), 'avc1.42,hvc1.1');
      expect(videoCodecs('#EXT-X-STREAM-INF:BANDWIDTH=1'), isNull);
      expect(steamOrigin('xyz.steamserver.net') && steamOrigin('STEAMSERVER.NET'), isTrue);
      expect(steamOrigin('https://xyz.steamserver.net/'), isFalse, reason: 'the origin is a bare host');
      expect(steamOrigin(null), isFalse);
      expect(validChild(_child(_host, 'a.m3u8'), _id, _host), isTrue);
      expect(validChild(_child('other.example.com', 'a.m3u8'), _id, _host), isFalse);
    });
  });

  group('the room, its data and its lines', () {
    final variants = [
      const SteambroadcastVariant(
        id: '1080p60',
        width: 1920,
        height: 1080,
        bandwidth: 6000000,
        frameRate: 59.94,
        codec: LiveStreamCodec.avc,
      ),
      const SteambroadcastVariant(id: '720p', width: 1280, height: 720, bandwidth: 2000000, codec: LiveStreamCodec.avc),
    ];

    test('the state decides what the card shows', () {
      LiveStatus? status(SteambroadcastState state) =>
          SteambroadcastRoomParser.room(_broadcast(state: state)).broadcast.liveStatus;
      expect(status(SteambroadcastState.live), LiveStatus.live);
      expect(status(SteambroadcastState.replay), LiveStatus.replay);
      expect(status(SteambroadcastState.offline), LiveStatus.offline);
      expect(status(SteambroadcastState.accountRestricted), LiveStatus.banned);
      expect(status(SteambroadcastState.unknown), LiveStatus.unknown, reason: 'waiting is never called offline');
      expect(
        SteambroadcastRoomParser.room(_broadcast(state: SteambroadcastState.accountRestricted)).anchor?.liveStatus,
        LiveStatus.banned,
        reason: 'the streamer carries the same state as the broadcast',
      );
      final withData = SteambroadcastRoomParser.room(
        _broadcast(),
        data: SteambroadcastRoomData(steamId: _id, state: SteambroadcastState.live, master: _master),
      );
      expect(
        withData.runtime.streamHandle,
        isA<SteambroadcastRoomData>(),
        reason: 'the stream handle rides in the room',
      );
      expect(SteambroadcastRoomParser.room(_broadcast()).runtime.streamHandle, isNull);
      final room = SteambroadcastRoomParser.room(
        _broadcast(
          broadcaster: '主播甲',
          title: '标题',
          game: '某游戏',
          cover: 'https://x/1.jpg',
          avatar: 'https://y/2.jpg',
          viewers: 812,
        ),
      );
      expect(room.roomId, _id);
      expect(room.anchor?.anchorId, _id);
      expect(room.anchor?.profileUrl, 'https://steamcommunity.com/broadcast/watch/$_id');
      expect(room.anchor?.name, '主播甲');
      expect(room.content.title, '标题');
      expect(room.content.platformTags, ['某游戏']);
      expect(room.content.notice, SteambroadcastEndpoints.chatNotice);
      expect(room.audience.onlineViewers, 812);
      expect(room.audience.primaryMetric, LiveAudienceMetricType.onlineViewers);
      expect(room.links.webUrl, 'https://steamcommunity.com/broadcast/watch/$_id');
      expect(
        SteambroadcastRoomParser.room(_broadcast()).audience.primaryMetric,
        LiveAudienceMetricType.unknown,
        reason: 'a room with no count says so',
      );
      expect(SteambroadcastRoomParser.room(_broadcast()).content.platformTags, isEmpty);
      expect(
        SteambroadcastRoomParser.room(_broadcast(state: SteambroadcastState.accountRestricted)).content.notice,
        SteambroadcastEndpoints.restrictedNotice,
      );
      expect(
        SteambroadcastRoomParser.room(_broadcast(restriction: LiveRestriction.subscribersOnly)).broadcast.restriction,
        LiveRestriction.subscribersOnly,
      );
    });

    test('the answers fill what the earlier one lacks, and only while live', () {
      final known = _broadcast(
        broadcaster: '主播甲',
        title: '旧标题',
        game: '某游戏',
        cover: 'https://x/1.jpg',
        avatar: 'https://y/2.jpg',
        viewers: 5,
      );
      expect(_broadcast().enrich(known).broadcaster, '主播甲');
      expect(_broadcast().enrich(known).title, '旧标题');
      expect(_broadcast().enrich(known).viewers, 5, reason: "a live room borrows the card's count");
      expect(_broadcast(title: '自己的标题', viewers: 9).enrich(known).title, '自己的标题');
      expect(_broadcast(title: '自己的标题', viewers: 9).enrich(known).viewers, 9);
      final ended = _broadcast(state: SteambroadcastState.offline).enrich(known);
      expect(ended.viewers, isNull, reason: 'an ended broadcast keeps none of the last count');
      expect(ended.broadcaster, '主播甲');
      final info = _broadcast(title: '信息标题', game: '信息游戏', cover: 'https://x/2.jpg', viewers: 7);
      expect(_broadcast().withInfo(info).viewers, 7);
      expect(_broadcast(viewers: 1).withInfo(info).viewers, 1, reason: 'its own count is never overwritten');
      expect(_broadcast(title: '甲').withInfo(info).title, '信息标题', reason: 'the info answer names the live title');
      expect(_broadcast().withInfo(info).game, '信息游戏');
      expect(info.withMaster(codec: LiveStreamCodec.avc, variants: variants).masterChecked, isTrue);
      expect(
        info
            .withMaster(mediaError: const SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, '坏了'))
            .masterChecked,
        isFalse,
      );
      expect(
        info
            .withMaster(mediaError: const SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, '坏了'))
            .mediaError
            ?.message,
        '坏了',
      );
    });

    test('the room data hands on the master only once it was checked', () {
      final unchecked = SteambroadcastRoomParser.roomData(
        _broadcast(master: _master, variants: variants, codec: LiveStreamCodec.avc),
      );
      expect(unchecked.master, isNull, reason: 'a refresh does not load the master');
      expect(unchecked.variants, isEmpty);
      expect(unchecked.streamError?.message, contains('enter the room'));
      final checked = SteambroadcastRoomParser.roomData(
        _broadcast(master: _master, masterChecked: true, variants: variants, codec: LiveStreamCodec.avc),
      );
      expect(checked.master, _master);
      expect(checked.variants, hasLength(2));
      expect(checked.qualities.map((quality) => quality.qualityId), ['auto', '1080p60', '720p']);
      expect(checked.qualities.first.label, SteambroadcastEndpoints.qualityLabel);
      expect(checked.qualities.first.codec, isNull, reason: 'the adaptive master names no single codec');
      expect(checked.qualities[1].codec, LiveStreamCodec.avc);
      expect(checked.streamError, isNull);
    });

    test('what cannot be watched says why', () {
      SteambroadcastRoomData data({
        SteambroadcastState state = SteambroadcastState.live,
        LiveRestriction? restriction,
        Uri? master,
        SteambroadcastFailure? mediaError,
      }) => SteambroadcastRoomData(
        steamId: _id,
        state: state,
        restriction: restriction,
        master: master,
        mediaError: mediaError,
      );
      expect(data(master: _master).streamError, isNull);
      expect(data().streamError?.kind, SteambroadcastFailureKind.streamUnavailable);
      expect(data().streamError?.message, contains('enter the room'));
      expect(data(state: SteambroadcastState.offline, master: _master).streamError?.message, contains('is offline'));
      expect(
        data(state: SteambroadcastState.accountRestricted, master: _master).streamError?.message,
        contains('restricted from broadcasting'),
      );
      expect(data(state: SteambroadcastState.unknown, master: _master).streamError?.message, contains('state unknown'));
      expect(
        data(restriction: LiveRestriction.subscribersOnly, master: _master).streamError?.message,
        contains('subscribers only'),
        reason: "a broadcast for the broadcaster's subscribers cannot be watched by us",
      );
      const broken = SteambroadcastFailure(SteambroadcastFailureKind.apiChanged, 'master 坏了');
      expect(
        data(mediaError: broken, master: _master).streamError,
        same(broken),
        reason: 'the media problem is told as it was found',
      );
      expect(
        data(state: SteambroadcastState.offline, restriction: LiveRestriction.subscribersOnly).streamError?.message,
        contains('is offline'),
        reason: 'the state is asked before the restriction',
      );
    });

    test('a line is the master, with the variant named and measured', () {
      final checked = SteambroadcastRoomData(
        steamId: _id,
        state: SteambroadcastState.live,
        restriction: LiveRestriction.none,
        master: _master,
        codec: LiveStreamCodec.avc,
        variants: variants,
      );
      final auto = SteambroadcastRoomParser.line(checked, SteambroadcastEndpoints.qualityId);
      expect(auto.url, '$_master');
      expect(auto.format, LiveStreamFormat.hls);
      expect(auto.headers, isEmpty, reason: 'the CDN answers without them');
      expect(auto.lease, isNull, reason: 'the address names no expiry');
      expect(auto.lineLabel, isNull);
      expect(auto.codec, LiveStreamCodec.avc);
      final best = SteambroadcastRoomParser.line(checked, '1080p60');
      expect(best.lineLabel, '1080p60');
      expect(best.url, auto.url, reason: 'a variant plays the same master, the player picks the rendition');
      expect(best.geometry.width, 1920);
      expect(best.geometry.height, 1080);
      expect(best.geometry.frameRate, 60);
      expect(best.geometry.bitrateKbps, 6000);
      expect(SteambroadcastRoomParser.line(checked, '720p').geometry.frameRate, isNull);
      expect(
        _failure(() => SteambroadcastRoomParser.line(checked, '480p')).message,
        contains('quality 480p is not offered'),
      );
      expect(
        _kindOf(
          () => SteambroadcastRoomParser.line(
            SteambroadcastRoomData(steamId: _id, state: SteambroadcastState.offline),
            'auto',
          ),
        ),
        SteambroadcastFailureKind.streamUnavailable,
      );
    });
  });
}
