import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/fc2live/fc2_api.dart';
import 'package:pure_live/core/site/fc2live/fc2_control_session.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  test('current HLS response accepts only the channel-bound master playlist', () {
    final master = Fc2ControlSession.parseHlsResponse(_hlsResponse(), expectedChannelId: '10608314');
    expect(master.path, '/a/stream/10608314/0/master_playlist');
    expect(master.queryParameters['targets'], '10,20,30,40,90');

    final wrong = _hlsResponse();
    ((wrong['arguments'] as Map)['playlists'] as List).first['url'] =
        'https://evil.example/a/stream/10608314/0/master_playlist?targets=10&c=x&d=y';
    expect(
      () => Fc2ControlSession.parseHlsResponse(wrong, expectedChannelId: '10608314'),
      throwsA(isA<Fc2Exception>()),
    );
  });

  test('control session requests HLS once and owns socket cleanup', () async {
    final socket = _FakeSocket();
    var transportClosed = false;
    final sessionFuture = Fc2ControlSession.open(
      '10608314',
      api: _GrantApi(),
      findProxy: (_) => 'DIRECT',
      connect: (endpoint, headers, findProxy) {
        expect(endpoint.queryParameters['control_token'], 'fixture-control-token');
        expect(headers['Origin'], Fc2Api.origin);
        expect(headers['Cookie'], 'l_ortkn=fixture-orz');
        scheduleMicrotask(() => socket.addInbound(jsonEncode({'name': 'connect_complete', 'arguments': {}})));
        return Fc2SocketLease(
          channel: socket,
          closeTransport: () {
            transportClosed = true;
          },
        );
      },
    );
    socket.outbound.stream.listen((message) {
      final decoded = jsonDecode(message as String) as Map<String, dynamic>;
      if (decoded['name'] == 'get_hls_information') socket.addInbound(jsonEncode(_hlsResponse()));
    });
    final session = await sessionFuture;
    expect(session.master.path, '/a/stream/10608314/0/master_playlist');
    expect(socket.sent.where((message) => message.toString().contains('get_hls_information')), hasLength(1));
    await session.close();
    expect(transportClosed, isTrue);
    expect(socket.closed, isTrue);
  });
}

Map<String, dynamic> _hlsResponse() => {
  'name': '_response_',
  'id': 1,
  'arguments': {
    'status': 0,
    'playlists': [
      {
        'mode': 0,
        'status': 0,
        'url': 'https://us-west-1-media.live.fc2.com/a/stream/10608314/0/master_playlist?targets=10,20,30,40,90&c=fixture-c&d=fixture-d',
      },
      {'mode': 10, 'status': 0, 'url': 'https://us-west-1-media.live.fc2.com/ignored'},
    ],
  },
};

final class _GrantApi extends Fc2Api {
  _GrantApi() : super(request: (_, _, _, _) async => throw StateError('unused'));

  @override
  Future<Fc2ControlGrant> controlGrant(String rawChannelId, {CancelToken? cancel}) async => Fc2ControlGrant(
    channelId: rawChannelId,
    webSocket: Uri.parse('wss://worker.live.fc2.com/control/channels/$rawChannelId'),
    controlToken: 'fixture-control-token',
    orz: 'fixture-orz',
  );
}

final class _FakeSocket with StreamChannelMixin<dynamic> implements WebSocketChannel {
  final StreamController<dynamic> _inbound = StreamController<dynamic>();
  final StreamController<dynamic> outbound = StreamController<dynamic>.broadcast();
  final List<dynamic> sent = [];
  bool closed = false;

  _FakeSocket() {
    outbound.stream.listen(sent.add);
  }

  void addInbound(dynamic value) => _inbound.add(value);

  @override
  Future<void> get ready => Future.value();

  @override
  Stream<dynamic> get stream => _inbound.stream;

  @override
  WebSocketSink get sink => _FakeSink(outbound, () async {
    if (closed) return;
    closed = true;
    await _inbound.close();
    await outbound.close();
  });

  @override
  int? get closeCode => closed ? 1000 : null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;
}

final class _FakeSink implements WebSocketSink {
  _FakeSink(this._outbound, this._onClose);

  final StreamController<dynamic> _outbound;
  final Future<void> Function() _onClose;

  @override
  void add(dynamic data) => _outbound.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _outbound.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<dynamic> stream) => _outbound.addStream(stream);

  @override
  Future<void> close([int? closeCode, String? closeReason]) => _onClose();

  @override
  Future<void> get done => _outbound.done;
}
