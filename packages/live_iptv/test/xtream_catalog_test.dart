import 'dart:convert';
import 'dart:typed_data';

import 'package:live_iptv/src/model/xtream_source/xtream_source.dart';
import 'package:live_iptv/src/xtream/xtream_catalog_service/xtream_catalog_service.dart';
import 'package:live_net/live_net.dart';
import 'package:test/test.dart';

/// The Xtream Codes catalogue over a stubbed transport: the account read
/// the panel answers (and every spelling its refusal comes in), the
/// account's own word for whether it still plays, and the channel walk
/// that joins the category names, keeps the rows' own groups when the
/// names fail, and drops the rows nothing can ever open.
void main() {
  const source = XtreamSource(url: 'http://panel.tv:8080', username: 'user', password: 'p@ss');

  /// One canned text per player-API action ('' for the bare account ask).
  _StubHttp httpOver(Map<String, String> answers) => _StubHttp((action) {
    final text = answers[action];
    if (text == null) throw StateError('no answer for action "$action"');
    return text;
  });

  group('the account read', () {
    test('reads the account the panel answers, in the units it sends', () async {
      final http = httpOver({
        '': jsonEncode({
          'user_info': {
            'auth': 1,
            'status': 'Active',
            'exp_date': '1893456000', // panels send seconds as text
            'max_connections': '4',
            'active_cons': '1',
          },
        }),
      });
      final account = await XtreamCatalogService(http: http).fetchAccount(source);

      expect(account.status, 'Active');
      expect(account.expiresAt, DateTime.fromMillisecondsSinceEpoch(1893456000 * 1000, isUtc: true));
      expect(account.maxConnections, 4);
      expect(account.activeConnections, 1);

      // The ask carried the credentials and no action.
      final ask = http.asked.single;
      expect(ask.url.path, endsWith('player_api.php'));
      expect(ask.url.queryParameters['username'], 'user');
      expect(ask.url.queryParameters['password'], 'p@ss');
      expect(ask.url.queryParameters.containsKey('action'), isFalse);
    });

    test('the refusal comes in every type, and each one throws', () async {
      for (final auth in <Object?>['', 'false', 'False', '0', 0, false]) {
        final http = httpOver({
          '': jsonEncode({
            'user_info': {'auth': auth},
          }),
        });
        await expectLater(
          XtreamCatalogService(http: http).fetchAccount(source),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('rejected'))),
          reason: 'auth written as $auth must refuse',
        );
      }
    });

    test('an accepted account comes back whatever it spells yes with', () async {
      for (final auth in <Object?>[true, 1, 'true', 'TRUE', 'True']) {
        final http = httpOver({
          '': jsonEncode({
            'user_info': {'auth': auth, 'status': 'Active'},
          }),
        });
        final account = await XtreamCatalogService(http: http).fetchAccount(source);
        expect(account.status, 'Active', reason: 'auth written as $auth must be accepted');
      }
      // A panel that omits auth entirely is not a refusal.
      final silent = httpOver({
        '': jsonEncode({'user_info': <String, Object?>{}}),
      });
      final account = await XtreamCatalogService(http: silent).fetchAccount(source);
      expect(account.status, isNull);
      expect(account.expiresAt, isNull);
    });

    test('no account and no JSON both name themselves', () async {
      final noAccount = httpOver({
        '': jsonEncode({'code': 1}),
      });
      await expectLater(
        XtreamCatalogService(http: noAccount).fetchAccount(source),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('no account'))),
      );
      final noJson = httpOver({'': 'not json'});
      await expectLater(
        XtreamCatalogService(http: noJson).fetchAccount(source),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('no JSON'))),
      );
    });
  });

  group("the account's own word", () {
    final now = DateTime.utc(2026, 11, 21);
    final tomorrow = now.add(const Duration(days: 1));
    final yesterday = now.subtract(const Duration(days: 1));

    test('Active and unstated play; the expiry and the other words decide the rest', () {
      expect(const XtreamAccount(status: 'Active').isActive(now: now), isTrue);
      expect(const XtreamAccount(status: 'active ').isActive(now: now), isTrue); // trimmed
      expect(const XtreamAccount().isActive(now: now), isTrue); // unstated is not refused
      expect(XtreamAccount(status: 'Active', expiresAt: tomorrow).isActive(now: now), isTrue);
      expect(XtreamAccount(status: 'Active', expiresAt: yesterday).isActive(now: now), isFalse);
      expect(XtreamAccount(expiresAt: yesterday).isActive(now: now), isFalse); // unstated but spent
      expect(XtreamAccount(status: 'Expired', expiresAt: tomorrow).isActive(now: now), isFalse);
      expect(const XtreamAccount(status: 'Banned').isActive(now: now), isFalse);
      expect(const XtreamAccount(status: '').isActive(now: now), isTrue); // blank is unstated
    });
  });

  group('the catalogue walk', () {
    test('joins the category names, lets the rows keep their own, and drops idless rows', () async {
      final http = httpOver({
        'get_live_streams': jsonEncode([
          {
            'stream_id': 12,
            'name': 'SBT HD',
            'category_id': '4',
            'epg_channel_id': 'sbt.br',
            'stream_icon': 'http://i/sbt.png',
            'num': 7,
          },
          {'stream_id': 13, 'name': 'Globo', 'group_title': 'Aberta', 'category_id': '4'},
          {'name': 'a row with no stream id'},
        ]),
        'get_live_categories': jsonEncode([
          {'id': '4', 'category_name': 'Sports'},
          {'category_name': 'no id here'},
        ]),
      });
      final channels = await XtreamCatalogService(http: http).fetchChannels(source);

      expect(channels, hasLength(2)); // the idless row never lands
      final sbt = channels[0];
      expect(sbt.id, 'xtream://panel.tv:8080/12'); // the host prefixes, so two servers cannot collide
      expect(sbt.entry.name, 'SBT HD');
      expect(sbt.entry.group, 'Sports'); // the joined name
      expect(sbt.entry.tvgId, 'sbt.br'); // what a guide matches
      expect(sbt.entry.tvgLogo, 'http://i/sbt.png');
      expect(sbt.entry.channelNumber, 7);
      expect(sbt.entry.url, 'http://panel.tv:8080/live/user/p%40ss/12.m3u8'); // HLS, creds encoded

      final globo = channels[1];
      expect(globo.entry.group, 'Aberta'); // the row's own group wins over the join

      // Both asks rode the credentials; streams first, names second.
      expect(http.asked, hasLength(2));
      expect(http.asked[0].url.queryParameters['action'], 'get_live_streams');
      expect(http.asked[1].url.queryParameters['action'], 'get_live_categories');
      for (final ask in http.asked) {
        expect(ask.url.queryParameters['username'], 'user');
        expect(ask.url.queryParameters['password'], 'p@ss');
      }
    });

    test('a refusal or a non-list on the streams ask throws', () async {
      final refused = httpOver({
        'get_live_streams': jsonEncode({
          'user_info': {'auth': 0},
        }),
      });
      await expectLater(
        XtreamCatalogService(http: refused).fetchChannels(source),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('rejected'))),
      );

      final notAList = httpOver({
        'get_live_streams': jsonEncode({'ok': 1}),
      });
      await expectLater(
        XtreamCatalogService(http: notAList).fetchChannels(source),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('other than a stream list'))),
      );
    });

    test('a broken names ask costs the groups, never the channels', () async {
      final rows = jsonEncode([
        {'stream_id': 14, 'name': 'Band', 'group_title': 'Row', 'category_id': '4'},
        {'stream_id': 15, 'name': 'Record', 'category_id': '9'},
      ]);
      final namesFailed = _StubHttp((action) {
        if (action == 'get_live_categories') throw StateError('names failed');
        return rows;
      });
      final channels = await XtreamCatalogService(http: namesFailed).fetchChannels(source);
      expect(channels, hasLength(2));
      expect(channels[0].entry.group, 'Row'); // the row's own words stay
      expect(channels[1].entry.group, isNull); // the unnamed group costs its name only
    });

    test('a names answer that is not a list reads as none', () async {
      final http = httpOver({
        'get_live_streams': jsonEncode([
          {'stream_id': 16, 'name': 'Band', 'category_id': '4'},
        ]),
        'get_live_categories': jsonEncode({'ok': 1}),
      });
      final channels = await XtreamCatalogService(http: http).fetchChannels(source);
      expect(channels, hasLength(1));
      expect(channels.single.entry.group, isNull);
    });

    test('a genuinely empty catalogue comes back empty', () async {
      final http = httpOver({'get_live_streams': '[]', 'get_live_categories': '[]'});
      expect(await XtreamCatalogService(http: http).fetchChannels(source), isEmpty);
    });
  });
}

/// The transport the service is tried against: one canned text per
/// player-API action, and a record of what was asked.
final class _StubHttp implements LiveHttp {
  new(this.answer);

  final String Function(String action) answer;
  final List<LiveRequest> asked = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request);
    final text = answer(request.url.queryParameters['action'] ?? '');
    return LiveResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      bodyBytes: Uint8List.fromList(utf8.encode(text)),
    );
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('the catalogue buffers');

  @override
  void close() {}
}
