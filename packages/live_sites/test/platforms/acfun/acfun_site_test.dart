import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/platforms/acfun/acfun_site.dart';
import 'package:live_sites/src/platforms/acfun/api/acfun_http.dart';
import 'package:test/test.dart';

/// The instant the sessions are read at.
final DateTime _now = DateTime.utc(2026, 10, 1, 12);

/// The author the tests play.
const String _author = '12345';

/// A JSON 200 answer carrying [body].
LiveResponse _json(Object body) => LiveResponse(
  statusCode: 200,
  headers: const <String, String>{},
  bodyBytes: Uint8List.fromList(utf8.encode(jsonEncode(body))),
);

/// `startPlay`'s live answer: one quality, the danmaku tickets and the
/// enter-room attach.
Object _startPlay() => {
  'result': 1,
  'data': {
    'liveId': 'live-1',
    'videoPlayRes': jsonEncode({
      'liveAdaptiveManifest': [
        {
          'adaptationSet': {
            'representation': [
              {'id': 1, 'qualityType': 'high', 'name': '高清', 'url': 'https://cdn.example.com/live.flv'},
            ],
          },
        },
      ],
    }),
    'availableTickets': ['t-1'],
    'enterRoomAttach': 'attach-1',
  },
};

/// The transport that answers the visitor login and `startPlay`: every login
/// mints a distinct token, so the session a call was asked with is read off
/// its query. Anything else is a test failure.
final class _Replay implements LiveHttp {
  /// The token every login answered with, in order.
  final List<String> loginTokens = [];

  /// The `acfun.api.visitor_st` query of every `startPlay`, in order.
  final List<String> startPlayTokens = [];

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final url = request.url;
    if (url.host == 'id.app.acfun.cn' && url.path == '/rest/app/visitor/login') {
      final token = 'token-${loginTokens.length}';
      loginTokens.add(token);
      return _json({'result': 0, 'userId': _author, 'acfun.api.visitor_st': token});
    }
    if (url.host == 'api.kuaishouzt.com' && url.path == '/rest/zt/live/web/startPlay') {
      startPlayTokens.add(url.queryParameters['acfun.api.visitor_st'] ?? '');
      return _json(_startPlay());
    }
    throw StateError('the test transport does not answer $url');
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}

AcfunSite _site(_Replay transport) => AcfunSite(http: AcfunHttp(transport), now: () => _now, random: Random(7));

void main() {
  group('the visitor session', () {
    test('a danmaku refresh is a fresh session; normal playback reuses one', () async {
      final transport = _Replay();
      final site = _site(transport);

      // Playback logs in once and asks twice with the same five-minute session.
      final first = await site.startPlay(_author);
      final second = await site.startPlay(_author);
      expect(transport.loginTokens, ['token-0'], reason: 'the session lives five minutes');
      expect(transport.startPlayTokens, ['token-0', 'token-0']);
      expect(identical(second.visitor, first.visitor), isTrue, reason: 'concurrent playback shares the session');

      // A refresh is a new session and a `startPlay` asked with it: the dead
      // tickets of the old session must not come back.
      final refreshed = await site.danmakuArgsFromSession(_author);
      expect(transport.loginTokens, ['token-0', 'token-1']);
      expect(transport.startPlayTokens.last, 'token-1');
      expect(refreshed.visitor.token, 'token-1');
      expect(refreshed.liveId, 'live-1');
      expect(refreshed.tickets, ['t-1']);

      // The refresh the args carry asks for a new session again.
      final again = await refreshed.refresh!();
      expect(transport.loginTokens, ['token-0', 'token-1', 'token-2']);
      expect(again.visitor.token, 'token-2');
    });
  });
}
