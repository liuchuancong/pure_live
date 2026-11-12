import 'dart:async' show StreamController, StreamSubscription;
import 'dart:typed_data' show Uint8List;

import 'package:live_iptv/src/import/live_net_fetch.dart';
import 'package:live_net/live_net.dart';
import 'package:test/test.dart';

/// The two ways a streamed download dies without an answer, and the fetcher
/// has to be the one that ends them: a server that answers the head and
/// then never sends a byte, and one that trickles forever. Both used to
/// hold an import open past any patience — the dial timeout only covers
/// the wait for the head, so the body read is judged here.
final class _StubHttp implements LiveHttp {
  new(this.response);

  final _StubStreamedResponse response;
  final List<LiveRequest> asked = [];

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async {
    asked.add(request);
    return response;
  }

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    asked.add(request);
    throw StateError('the byte fetcher opens, it does not send');
  }

  @override
  void close() {}
}

final class _StubStreamedResponse implements LiveStreamedResponse {
  /// Serves [source] through a controller, the way a real adapter does:
  /// `close` cancels the transfer, and the reader's `await for` ends.
  new(Stream<Uint8List> source) : _controller = StreamController<Uint8List>() {
    _source = source.listen(_controller.add, onError: _controller.addError, onDone: _controller.close);
  }

  @override
  final int statusCode = 200;

  @override
  final Map<String, String> headers = const {'content-type': 'application/octet-stream'};

  final StreamController<Uint8List> _controller;
  late final StreamSubscription<Uint8List> _source;

  bool closed = false;

  @override
  Stream<Uint8List> get stream => _controller.stream;

  @override
  Future<void> close() async {
    closed = true;
    await _source.cancel();
    await _controller.close();
  }
}

void main() {
  test('a body that never speaks after the head is ended by the idle judge', () async {
    // The controller never closes: the transport answers, then goes quiet.
    final quiet = StreamController<Uint8List>();
    final http = _StubHttp(_StubStreamedResponse(quiet.stream));
    final fetch = iptvBytesFetcherFor(
      http,
      timeout: const Duration(seconds: 5),
      chunkIdle: const Duration(milliseconds: 80),
    );

    await expectLater(fetch(Uri.parse('http://guide.example/epg.xml')), throwsA(isA<TimeoutFailure>()));
    expect(http.response.closed, isTrue, reason: 'the stalled transfer must be stopped, not abandoned');
  });

  test('a body that trickles forever is ended by the body budget', () async {
    // A chunk every 10 ms: alive enough to pass every idle judge, slow
    // enough that only the budget ends it.
    final http = _StubHttp(
      _StubStreamedResponse(
        Stream<Uint8List>.periodic(const Duration(milliseconds: 10), (index) => Uint8List.fromList([1])),
      ),
    );
    final fetch = iptvBytesFetcherFor(
      http,
      timeout: const Duration(seconds: 5),
      bodyBudget: const Duration(milliseconds: 150),
      chunkIdle: const Duration(milliseconds: 500),
    );

    await expectLater(fetch(Uri.parse('http://guide.example/epg.xml')), throwsA(isA<TimeoutFailure>()));
    expect(http.response.closed, isTrue);
  });

  test('a body that arrives stays untouched by the judges', () async {
    final http = _StubHttp(
      _StubStreamedResponse(
        Stream<Uint8List>.fromIterable([
          Uint8List.fromList([1]),
          Uint8List.fromList([2, 3]),
        ]),
      ),
    );
    final fetch = iptvBytesFetcherFor(
      http,
      timeout: const Duration(seconds: 5),
      bodyBudget: const Duration(milliseconds: 150),
      chunkIdle: const Duration(milliseconds: 80),
    );

    final body = await fetch(Uri.parse('http://guide.example/list.m3u'));
    expect(body, [1, 2, 3]);
    expect(http.response.closed, isTrue);
  });
}
