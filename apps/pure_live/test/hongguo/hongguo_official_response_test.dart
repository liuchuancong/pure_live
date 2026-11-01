// What the station's answers are allowed to become on the way to the screen.
//
// The player's error card prints `hongguoFailureText(error)`, and that helper
// has one branch per failure the module owns — everything else is interpolated
// with `'$error'`. So a `FormatException` escaping a decode is a card reading
// `Unexpected end of input (at character 1)` with a caret under nothing, over a
// video the viewer only asked to watch. The CDN really does answer that way now
// and then: a 200 whose body is empty, and an HTML wall where the JSON object
// was expected. These pin that both refusals come back as the module's own
// failure, with words a person can act on.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart' show hongguoFailureText;
import 'package:pure_live/modules/hongguo/official/hongguo_official.dart' show HongguoOfficialClient, HongguoOfficialFailure;

/// A transport that answers 200 with [body] to everything.
final class _StubHttp implements LiveHttp {
  _StubHttp(this.body);

  final String body;

  @override
  Future<LiveResponse> send(LiveRequest request) async => LiveResponse(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    bodyBytes: Uint8List.fromList(utf8.encode(body)),
  );

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnsupportedError('the client buffers');

  @override
  void close() {}
}

HongguoOfficialClient _client(String body) => HongguoOfficialClient(http: _StubHttp(body));

/// Every JSON endpoint here reads the same way, so one call carries the rule;
/// the search is the one that needs no device registration to reach the decode.
Future<void> _read(HongguoOfficialClient client) => client.websiteSearch('测试');

void main() {
  test('a 200 with no body is the station refusing, not a decode error', () async {
    await expectLater(_read(_client('')), throwsA(isA<HongguoOfficialFailure>()));
  });

  test('whitespace is as empty as nothing', () async {
    await expectLater(_read(_client('  \n')), throwsA(isA<HongguoOfficialFailure>()));
  });

  test('an HTML wall in place of the JSON is said, not thrown', () async {
    const body = '<!DOCTYPE html><html><head><title>验证</title></head><body></body></html>';

    await expectLater(_read(_client(body)), throwsA(isA<HongguoOfficialFailure>()));
  });

  test('a JSON array where an object was promised is refused too', () async {
    await expectLater(_read(_client('[1,2,3]')), throwsA(isA<HongguoOfficialFailure>()));
  });

  test('the card the viewer sees carries words, not a parser position', () async {
    // The regression in one line: this is what used to reach the screen.
    late Object thrown;
    try {
      jsonDecode('');
    } on FormatException catch (error) {
      thrown = error;
    }

    expect(hongguoFailureText(thrown), contains('at character'));

    late Object caught;
    try {
      await _read(_client(''));
    } on Object catch (error) {
      caught = error;
    }

    expect(caught, isA<HongguoOfficialFailure>());
    expect(hongguoFailureText(caught), isNot(contains('at character')));
    expect(hongguoFailureText(caught), isNotEmpty);
  });
}
