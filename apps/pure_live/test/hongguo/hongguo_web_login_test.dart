import 'dart:async' show StreamSubscription;
import 'dart:convert' show base64Encode, jsonEncode, utf8;
import 'dart:io' show Cookie, HttpClient, HttpClientRequest, HttpClientResponse, HttpHeaders;
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/hongguo/official/hongguo_web_login.dart';

/// The website login's whole walk, argued over a scripted transport: the QR
/// code decodes with its own expiry, the CSRF cookie rides the chain and
/// dies with its timestamp, the poll follows only the site's own redirect
/// chain (host, scheme, depth, dead ends) to the session cookie, the code
/// path mixes its fields the web passport's way and warms the CSRF when it
/// has none, and every refusal is said in the module's own words.
void main() {
  String ok(Map<String, Object?> data, {List<Cookie> cookies = const []}) =>
      jsonEncode({'message': 'success', 'data': data});

  _FakeResponse qrReply({String token = 'tok-1'}) => _FakeResponse(
    200,
    cookies: [Cookie('passport_csrf_token', 'csrf-1'), Cookie('tt_webid', '99')],
    body: ok({
      'token': token,
      'qrcode': 'data:image/png;base64,${base64Encode([1, 2, 3, 4])}',
      'expire_time': 180,
    }),
  );

  String xor5(String value) => utf8.encode(value).map((byte) => (byte ^ 0x05).toRadixString(16)).join();

  group('the qr code', () {
    test('the code decodes with its own lifetime', () async {
      final client = _ScriptClient([
        _FakeResponse(
          200,
          body: ok({
            'token': 'tok-1',
            'qrcode': 'data:image/png;base64,${base64Encode([1, 2, 3, 4])}',
            'expire_time': 180,
          }),
        ),
      ]);
      final login = HongguoWebLogin(clientFactory: () => client);

      final code = await login.qr();
      expect(code.image, [1, 2, 3, 4]); // the png the phone app will read
      expect(code.expiresIn, 180); // the seconds the answer named
      expect(client.seen.single.url.path, '/passport/web/get_qrcode/');
      expect(client.seen.single.url.queryParameters['aid'], '513755');
    });

    test('an absolute expiry reads as the seconds left, capped at ten minutes', () async {
      const left = 45;
      final client = _ScriptClient([
        _FakeResponse(
          200,
          body: ok({
            'token': 'tok-1',
            'qrcode': 'data:image/png;base64,${base64Encode([1])}',
            'expire_time': DateTime.now().millisecondsSinceEpoch ~/ 1000 + left,
          }),
        ),
      ]);
      final login = HongguoWebLogin(clientFactory: () => client);

      final code = await login.qr();
      expect(code.expiresIn, inInclusiveRange(left - 2, left)); // the clock's own slice
    });

    test('the refusals refuse', () async {
      Future<HongguoLoginFailure> failureOf(_FakeResponse response) async {
        final login = HongguoWebLogin(clientFactory: () => _ScriptClient([response]));
        try {
          await login.qr();
          return const HongguoLoginFailure('no failure');
        } on HongguoLoginFailure catch (error) {
          return error;
        }
      }

      expect(
        (await failureOf(
          _FakeResponse(
            200,
            body: jsonEncode({
              'message': 'error',
              'data': {'error_code': 9, 'description': '太快了'},
            }),
          ),
        )).message,
        '太快了（错误码 9）',
      );
      expect(
        (await failureOf(
          _FakeResponse(200, body: ok({'token': 'tok-1', 'qrcode': 'no mark here', 'expire_time': 180})),
        )).message,
        '二维码数据异常',
      );
      expect((await failureOf(_FakeResponse(200, body: 'not json'))).message, '官网登录返回格式异常');
      expect((await failureOf(_FakeResponse(200, body: '[]'))).message, '官网登录返回格式异常');
      expect((await failureOf(_FakeResponse(503))).message, '官网登录返回格式异常'); // a status the walk never sees
    });
  });

  group('the poll', () {
    test('a poll before a code is refused, waiting answers false, expiry says so', () async {
      final login = HongguoWebLogin(clientFactory: () => _ScriptClient([]));
      expect(login.poll, throwsA(_login('请先获取二维码')));

      final client = _ScriptClient([
        qrReply(),
        _FakeResponse(200, body: ok({'status': '1'}), cookies: [Cookie('tt_webid', '99')]),
      ]);
      final waiting = HongguoWebLogin(clientFactory: () => client);
      await waiting.qr();
      expect(await waiting.poll(), isFalse); // the visitor has not scanned
      expect(client.seen.last.url.queryParameters['token'], 'tok-1');
      expect(client.seen.last.headers.value('x-tt-passport-csrf-token'), 'csrf-1'); // the qr's csrf came back
      expect(client.seen.last.headers.value('Cookie'), contains('passport_csrf_token=csrf-1'));
      expect(client.seen.last.headers.value('Cookie'), contains('tt_webid=99'));

      final expired = HongguoWebLogin(
        clientFactory: () => _ScriptClient([
          qrReply(),
          _FakeResponse(200, body: ok({'status': '5'})),
        ]),
      );
      await expired.qr();
      expect(expired.poll, throwsA(_login('二维码已过期，请重新获取')));
    });

    test("a confirmation follows the site's own chain to the session cookie", () async {
      final client = _ScriptClient([
        qrReply(),
        _FakeResponse(200, body: ok({'status': '3', 'redirect_url': '/passport/confirm?x=1'})),
        _FakeResponse(302, headers: {'location': '/passport/land'}, cookies: [Cookie('sid_hint', 'h1')]),
        _FakeResponse(200, cookies: [Cookie('sessionid', 'abc'), Cookie('sessionid_ss', 'def')], body: 'ok'),
        _FakeResponse(200, body: ok({})), // the credentials' own info ask
      ]);
      final login = HongguoWebLogin(clientFactory: () => client);
      await login.qr();
      expect(await login.poll(), isTrue); // the session cookie landed

      expect(client.seen[2].url.path, '/passport/confirm'); // the chain started at the site
      expect(client.seen[3].url.path, '/passport/land'); // the redirect rode along
      expect(client.seen[3].headers.value('Cookie'), contains('sid_hint=h1')); // the hop's cookie came back
      expect(login.hasSession, isTrue);
      final cookie = await login.credentials();
      expect(cookie, contains('sessionid=abc'));
      expect(cookie, contains('sessionid_ss=def'));
      expect(cookie, contains('passport_csrf_token=csrf-1')); // the csrf survived the whole chain
    });

    test('the chain defends its host, its scheme, its depth and its dead ends', () async {
      _ScriptClient chain(List<_FakeResponse> responses) => _ScriptClient([qrReply(), ...responses]);
      Future<String> walked(_ScriptClient client) async {
        final login = HongguoWebLogin(clientFactory: () => client);
        await login.qr();
        try {
          return (await login.poll()) ? 'logged in' : 'waiting';
        } on HongguoLoginFailure catch (error) {
          return error.message;
        }
      }

      _FakeResponse ask(Object? data) =>
          _FakeResponse(200, body: jsonEncode({'message': 'success', 'data': data ?? <String, Object?>{}}));
      _FakeResponse hop(String location) => _FakeResponse(302, headers: {'location': location});

      expect(
        await walked(
          chain([
            ask({'status': '3', 'redirect_url': '/c'}),
            hop('https://evil.example/x'),
          ]),
        ),
        '登录确认跳转到不支持的站点', // another host is not followed
      );
      expect(
        await walked(
          chain([
            ask({'status': '3', 'redirect_url': '/c'}),
            hop('http://hongguoduanju.com/x'),
          ]),
        ),
        '登录确认跳转到不支持的站点', // a plain-http hop is not followed
      );
      expect(
        await walked(
          chain([
            ask({'status': '3', 'redirect_url': '/c'}),
            _FakeResponse(302),
          ]),
        ),
        '登录确认地址无效', // a redirect without a destination
      );
      expect(
        await walked(
          chain([
            ask({'status': '3', 'redirect_url': '/c'}),
            hop('/2'),
            hop('/3'),
            hop('/4'),
            hop('/5'),
            hop('/6'),
          ]),
        ),
        '登录确认跳转次数过多', // five hops and no landing
      );
      expect(
        await walked(
          chain([
            ask({'status': '3', 'redirect_url': '/c'}),
            _FakeResponse(500),
          ]),
        ),
        '登录确认失败（HTTP 500）',
      );
    });

    test('a confirmation without a redirect url keeps the walk honest', () async {
      final client = _ScriptClient([
        qrReply(),
        _FakeResponse(200, body: ok({'status': 'confirmed'})), // no redirect url at all
      ]);
      final login = HongguoWebLogin(clientFactory: () => client);
      await login.qr();
      expect(await login.poll(), isFalse); // no session cookie, no session
    });
  });

  group('the code path', () {
    test('a send without a csrf warms one first, and the fields mix hex', () async {
      final client = _ScriptClient([
        qrReply(),
        _FakeResponse(200, body: ok({'mobile': '138****8000', 'retry_time': 60})),
      ]);
      final login = HongguoWebLogin(clientFactory: () => client);

      final sent = await login.sendCode('13800138000');
      expect(client.seen, hasLength(2)); // the qr warmed the csrf first
      expect(client.seen[0].url.path, '/passport/web/get_qrcode/');
      final ask = client.seen[1];
      expect(ask.url.path, '/passport/web/send_code/');
      expect(ask.method, 'POST');
      expect(ask.body, 'mobile=${xor5('+86 13800138000')}&type=${xor5('24')}&mix_mode=1&fixed_mix_mode=1');
      expect(sent.maskedMobile, '138****8000');
      expect(sent.retrySeconds, 60);
    });

    test('a verify before a send is refused, and the sms lands the session', () async {
      final login = HongguoWebLogin(clientFactory: () => _ScriptClient([]));
      expect(login.verifyCode('1234'), throwsA(_login('请先发送验证码')));

      final client = _ScriptClient([
        qrReply(),
        _FakeResponse(200, body: ok({'mobile': '138****8000'})),
        _FakeResponse(200, cookies: [Cookie('sessionid', 'abc')], body: ok({})),
        _FakeResponse(200, body: ok({})), // the credentials' own info ask
      ]);
      final flowing = HongguoWebLogin(clientFactory: () => client);
      await flowing.sendCode('13800138000');
      expect(await flowing.verifyCode('2468'), isTrue);
      expect(client.seen.last.url.path, '/passport/web/sms_login/');
      expect(client.seen.last.body, contains('code=${xor5('2468')}'));
      expect(await flowing.credentials(), contains('sessionid=abc')); // the jar rides whole, order as it landed
    });

    test("a refused send names the platform's words", () async {
      final client = _ScriptClient([
        qrReply(),
        _FakeResponse(
          200,
          body: jsonEncode({
            'message': 'error',
            'data': {'error_code': 1105, 'description': ''},
          }),
        ),
      ]);
      final login = HongguoWebLogin(clientFactory: () => client);
      expect(login.sendCode('13800138000'), throwsA(_login('官网登录失败（错误码 1105）')));
    });
  });

  group('the cookie jar', () {
    test('an expired cookie never rides, an emptied one is dropped', () async {
      final dead = Cookie('old_one', '1')..expires = DateTime.now().subtract(const Duration(minutes: 1));
      final client = _ScriptClient([
        _FakeResponse(
          200,
          body: ok({
            'token': 'tok-1',
            'qrcode': 'data:image/png;base64,${base64Encode([1])}',
            'expire_time': 180,
          }),
          cookies: [dead, Cookie('passport_csrf_token', 'csrf-1')],
        ),
        _FakeResponse(
          200,
          body: ok({'status': '1'}),
          cookies: [Cookie('passport_csrf_token', '')],
        ), // the csrf emptied out
        _FakeResponse(200, body: ok({'status': '1'})),
      ]);
      final login = HongguoWebLogin(clientFactory: () => client);
      await login.qr();
      expect(client.seen[0].headers.containsKey('Cookie'), isFalse); // nothing to ride yet

      await login.poll();
      expect(client.seen[1].headers.value('Cookie'), contains('passport_csrf_token=csrf-1'));

      await login.poll();
      final jar = client.seen[2].headers.value('Cookie') ?? '';
      expect(jar.contains('passport_csrf_token'), isFalse); // the emptied cookie left the jar
      expect(jar.contains('old_one'), isFalse); // the expired one never joined
      expect(client.seen[2].headers.containsKey('x-tt-passport-csrf-token'), isFalse); // no csrf, no header
    });

    test('credentials without a session refuse', () async {
      final login = HongguoWebLogin(clientFactory: () => _ScriptClient([]));
      expect(login.credentials(), throwsA(_login('官网尚未下发登录态，请先在手机确认登录')));
    });
  });
}

Matcher _login(String message) => isA<HongguoLoginFailure>().having((error) => error.message, 'message', message);

/// One scripted hop: the request's method, url, headers and the body it
/// carried (an empty body for a GET).
final class _SeenRequest {
  _SeenRequest(this.method, this.url, this.headers, this.body);

  final String method;
  final Uri url;
  final _FakeHeaders headers;
  final String body;
}

final class _ScriptClient implements HttpClient {
  _ScriptClient(List<_FakeResponse> responses) : script = [...responses];

  final List<_FakeResponse> script;
  final seen = <_SeenRequest>[];

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (script.isEmpty) throw StateError('the script ran dry');
    final response = script.removeAt(0);
    return _FakeRequest(method, url, response, seen);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

final class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.method, this.uri, this._response, List<_SeenRequest> seen) : _seen = seen;

  @override
  final String method;

  @override
  final Uri uri;

  final HttpClientResponse _response;
  final List<_SeenRequest> _seen;
  @override
  final _FakeHeaders headers = _FakeHeaders();
  final _body = BytesBuilder();

  @override
  int contentLength = 0;

  @override
  void add(List<int> data) => _body.add(data);

  @override
  Future<HttpClientResponse> close() async {
    _seen.add(_SeenRequest(method, uri, headers, utf8.decode(_body.takeBytes(), allowMalformed: true)));
    return _response;
  }

  @override
  set followRedirects(bool value) {}

  @override
  set persistentConnection(bool value) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

final class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.statusCode, {this.cookies = const [], String body = '', Map<String, String> headers = const {}})
    : _body = utf8.encode(body) {
    _headers = _FakeHeaders();
    headers.forEach(_headers.set);
  }

  @override
  final int statusCode;

  @override
  final List<Cookie> cookies;
  final List<int> _body;
  late final _FakeHeaders _headers;

  @override
  _FakeHeaders get headers => _headers;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> data)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.fromIterable([_body])
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

/// The request/response headers the login's tests carry: just enough of
/// the real headers — case-insensitive names, the content length — for the
/// walk's own sets and reads.
final class _FakeHeaders implements HttpHeaders {
  final _values = <String, List<String>>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _values[name.toLowerCase()] = [if (value is String) value else '$value'];

  @override
  String? value(String name) {
    final values = _values[name.toLowerCase()];
    return values == null || values.isEmpty ? null : values.first;
  }

  bool containsKey(String name) => _values.containsKey(name.toLowerCase());

  @override
  set contentLength(int value) => set(HttpHeaders.contentLengthHeader, value);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}
