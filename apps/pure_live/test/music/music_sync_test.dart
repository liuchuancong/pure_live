import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show HttpServer, HttpStatus, InternetAddress, WebSocket, WebSocketTransformer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart';
import 'package:live_storage/live_storage.dart';
import 'package:media_core_audio/media_core_audio.dart' as audio;
import 'package:pure_live/modules/music/controller/library/music_playlists.dart' show MusicPlaylist;
import 'package:pure_live/modules/music/controller/sync/music_sync.dart'
    show MusicSyncNote, MusicSyncStatus, kMusicSyncHostHistoryLimit, musicSyncNextHostHistory, musicSyncProvider;
import 'package:pure_live/modules/music/controller/sync/music_sync_client.dart';
import 'package:pure_live/modules/music/controller/sync/music_sync_codec.dart';
import 'package:pure_live/modules/music/controller/sync/music_sync_data.dart';
import 'package:pure_live/modules/music/controller/sync/music_sync_wire.dart';

void main() {
  setUpAll(() async {
    await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  group('codec', () {
    test('auth key derives 16 ASCII characters', () {
      final key = musicSyncAuthKey('abcd1234');
      expect(key.length, 16);
    });

    test('AES ECB round-trips', () {
      final key = musicSyncAuthKey('auth-code');
      final cipher = musicSyncAesEncrypt('lx-music connect', key);
      expect(musicSyncAesDecrypt(cipher, key), 'lx-music connect');
      expect(cipher, isNot(contains('lx-music')));
    });

    test('RSA pair round-trips an OAEP message', () {
      final pair = MusicSyncRsaKeyPair.generate();
      // The public half must be headerless base64 — the reference strips
      // PEM markers before sending it inside the auth message.
      expect(pair.publicSpkiBase64, isNot(contains('-')));
      expect(pair.privatePkcs8Base64, isNot(contains('-')));
      const secret = 'lx-music auth reply';
      expect(pair.decryptOaep(pair.encryptOaep(secret)), secret);
    });
  });

  group('wire', () {
    test('frames past 1 KiB go out gzipped behind cg_', () {
      final small = musicSyncEncodeFrame('hello');
      expect(small, 'hello');
      final big = musicSyncEncodeFrame('x' * 2048);
      expect(big.startsWith('cg_'), isTrue);
      expect(musicSyncDecodeFrame(big), 'x' * 2048);
    });

    test('request encode/parse round-trips with a callback slot', () {
      final text = musicSyncEncodeRequest(
        'list_sync_get_sync_mode_abc',
        ['arg', MusicSyncRpcCallback('func_0_abc')],
        [1],
      );
      final parsed = musicSyncParseMessage(text)! as MusicSyncRpcRequest;
      expect(parsed.name, 'list_sync_get_sync_mode_abc');
      expect(parsed.args[0], 'arg');
      expect(parsed.callbackAt(1), 'func_0_abc');
      expect(parsed.reply('merge_remote_local'), jsonEncode([1, parsed.name, null, 'merge_remote_local']));
    });

    test('response frames parse', () {
      final parsed =
          musicSyncParseMessage(
                jsonEncode([
                  1,
                  'n',
                  null,
                  <String, Object?>{'a': 1},
                ]),
              )!
              as MusicSyncRpcResponse;
      expect(parsed.error, isNull);
      expect(parsed.result, <String, Object?>{'a': 1});
      final failed =
          musicSyncParseMessage(
                jsonEncode([
                  1,
                  'n',
                  <String, Object?>{'message': 'boom'},
                ]),
              )!
              as MusicSyncRpcResponse;
      expect(failed.errorMessage, 'boom');
    });

    test('callback frames parse and answer', () {
      final parsed =
          musicSyncParseMessage(
                jsonEncode([
                  2,
                  'func_0_abc',
                  ['merge_remote_local'],
                ]),
              )!
              as MusicSyncRpcCallbackRequest;
      expect(parsed.name, 'func_0_abc');
      expect(parsed.args, ['merge_remote_local']);
      expect(parsed.reply(null), jsonEncode([3, 'func_0_abc', null, null]));
      expect(
        parsed.replyError('released'),
        jsonEncode([
          3,
          'func_0_abc',
          <String, Object?>{'message': 'released'},
        ]),
      );
    });

    test('bare ping is not a frame', () {
      expect(musicSyncParseMessage('"ping"'), isNull);
    });
  });

  group('data', () {
    const track = audio.MusicTrack(
      id: '123',
      sourceId: 'kw',
      title: 'Song',
      artist: 'Singer',
      album: 'Album',
      duration: Duration(minutes: 3, seconds: 55),
    );

    test('music info keeps the reference shape', () {
      final info = musicSyncMusicInfo(track);
      expect(info['id'], '123');
      expect(info['name'], 'Song');
      expect(info['singer'], 'Singer');
      expect(info['source'], 'kw');
      expect(info['interval'], '03:55');
      final meta = info['meta']! as Map;
      expect(meta['songId'], '123');
      expect(meta['albumName'], 'Album');
    });

    test('list data round-trips through apply', () {
      final playlist = MusicPlaylist(
        id: 'pl_1',
        name: 'List',
        tracks: const [track],
        createdAt: DateTime.now(),
        locationUpdateTime: DateTime.now(),
      );
      final data = musicSyncListDataFromState([track], [track], [playlist]);
      final decoded = musicSyncApplyListData(data);
      expect(decoded.recent.single.id, '123');
      expect(decoded.favourites.single.title, 'Song');
      expect(decoded.playlists.single.name, 'List');
      expect(decoded.playlists.single.position, 0);
      expect(decoded.playlists.single.tracks.single.id, '123');
    });

    test('quality ids survive a sync round-trip, including unknown tiers', () {
      final withQualities = track.copyWith(
        qualities: const [
          audio.MusicQuality.k128,
          audio.MusicQuality.k320,
          audio.MusicQuality.flac,
          audio.MusicQuality(id: 'studio', label: 'Studio'),
        ],
      );
      final data = musicSyncListDataFromState([withQualities], const [], const []);
      final decoded = musicSyncApplyListData(data);
      expect(decoded.recent.single.qualities.map((quality) => quality.id), ['128k', '320k', 'flac', 'studio']);
      expect(decoded.recent.single.qualities.last.label, 'studio');
    });

    test('partial list data patches to empty', () {
      final decoded = musicSyncApplyListData(<String, Object?>{'loveList': []});
      expect(decoded.recent, isEmpty);
      expect(decoded.favourites, isEmpty);
      expect(decoded.playlists, isEmpty);
    });

    test('malformed list fields are treated as empty instead of throwing', () {
      final decoded = musicSyncApplyListData(<String, Object?>{
        'defaultList': <String, Object?>{},
        'loveList': 'broken',
        'userList': 42,
      });
      expect(decoded.recent, isEmpty);
      expect(decoded.favourites, isEmpty);
      expect(decoded.playlists, isEmpty);
    });

    test('md5 is the reference toMD5 shape', () {
      expect(musicSyncMd5Of(<String, Object?>{}), hasLength(32));
    });

    test('dislike rules split and join', () {
      final rules = musicSyncDislikeRulesFromLines(['singer - song', 'other']);
      expect(musicSyncDislikeLines(rules), ['singer - song', 'other']);
      expect(musicSyncDislikeLines('a\n\n b \n'), ['a', 'b']);
    });
  });

  group('client lifecycle', () {
    const keyInfo = MusicSyncKeyInfo(clientId: 'id', key: '0123456789abcdef', serverName: 'test');
    late HttpServer server;
    late MusicSyncAddress address;
    late _UnusedHttp http;
    late MusicSyncClient client;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      address = MusicSyncAddress(httpScheme: 'http', wsScheme: 'ws', hostPath: '127.0.0.1:${server.port}');
      http = _UnusedHttp();
      client = MusicSyncClient(http: http, deviceName: 'test');
    });

    tearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    test('a rejected socket handshake is not reported as connected', () async {
      server.listen((request) async {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
      });

      await expectLater(client.connect(address, keyInfo), throwsException);
      expect(client.isConnected, isFalse);
    });

    test('disconnect fails an outstanding call without waiting for its timeout', () async {
      final accepted = Completer<WebSocket>();
      server.listen((request) async {
        accepted.complete(await WebSocketTransformer.upgrade(request));
      });
      await client.connect(address, keyInfo);
      final call = client.call('wait', const []);

      final result = expectLater(call, throwsA(isA<Exception>()));
      await client.disconnect();
      await result;
    });

    test('a lost socket fails its outstanding call while transport reconnects', () async {
      final accepted = Completer<WebSocket>();
      server.listen((request) async {
        accepted.complete(await WebSocketTransformer.upgrade(request));
      });
      await client.connect(address, keyInfo);
      final call = client.call('wait', const []);

      await (await accepted.future).close();
      await expectLater(
        call.timeout(const Duration(seconds: 2), onTimeout: () => throw StateError('call was not released')),
        throwsA(isA<Exception>()),
      );
    });

    test('a timed-out call stops accepting its late callback', () async {
      final accepted = Completer<WebSocket>();
      final outgoing = Completer<List<Object?>>();
      final barrier = Completer<void>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        accepted.complete(socket);
        socket.listen((data) {
          final frame = jsonDecode(data as String);
          if (frame is List && frame.isNotEmpty && frame.first == 0 && !outgoing.isCompleted) {
            outgoing.complete(frame.cast<Object?>());
          }
        });
      });
      await client.connect(address, keyInfo);
      client.registerHandler('barrier', (_) {
        barrier.complete();
        return null;
      });
      var invoked = false;
      final call = client.call('wait', [(_) => invoked = true], timeout: const Duration(milliseconds: 100));
      final request = await outgoing.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw StateError('outgoing request'),
      );
      final callbackName = (request[3]! as List).single as String;

      await expectLater(call, throwsA(isA<Exception>()));
      final socket = await accepted.future;
      socket
        ..add(jsonEncode([2, callbackName, const <Object?>[]]))
        ..add(musicSyncEncodeRequest('barrier', const [], const []));
      await barrier.future.timeout(const Duration(seconds: 2));
      expect(invoked, isFalse);
    });

    test('reconnection invalidates callbacks from the lost socket', () async {
      final first = Completer<WebSocket>();
      final second = Completer<WebSocket>();
      final outgoing = Completer<List<Object?>>();
      final barrier = Completer<void>();
      var connections = 0;
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        if (connections++ == 0) {
          first.complete(socket);
          socket.listen((data) {
            final frame = jsonDecode(data as String);
            if (frame is List && frame.isNotEmpty && frame.first == 0 && !outgoing.isCompleted) {
              outgoing.complete(frame.cast<Object?>());
            }
          });
        } else {
          second.complete(socket);
        }
      });
      await client.connect(address, keyInfo);
      client.registerHandler('barrier', (_) {
        barrier.complete();
        return null;
      });
      var invoked = false;
      final call = client.call('wait', [(_) => invoked = true]);
      final failed = expectLater(call, throwsA(isA<Exception>()));
      final request = await outgoing.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw StateError('outgoing request'),
      );
      final callbackName = (request[3]! as List).single as String;

      await (await first.future).close();
      await failed;
      final replacement = await second.future.timeout(const Duration(seconds: 3));
      replacement
        ..add(jsonEncode([2, callbackName, const <Object?>[]]))
        ..add(musicSyncEncodeRequest('barrier', const [], const []));
      await barrier.future.timeout(const Duration(seconds: 2));
      expect(invoked, isFalse);
    });

    test('reconnection invalidates callbacks retained after a response', () async {
      final first = Completer<WebSocket>();
      final second = Completer<WebSocket>();
      final outgoing = Completer<List<Object?>>();
      final barrier = Completer<void>();
      var connections = 0;
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        if (connections++ == 0) {
          first.complete(socket);
          socket.listen((data) {
            final frame = jsonDecode(data as String);
            if (frame is List && frame.isNotEmpty && frame.first == 0 && !outgoing.isCompleted) {
              outgoing.complete(frame.cast<Object?>());
              socket.add(jsonEncode([1, frame[1], null, null]));
            }
          });
        } else {
          second.complete(socket);
        }
      });
      await client.connect(address, keyInfo);
      client.registerHandler('barrier', (_) {
        barrier.complete();
        return null;
      });
      var invoked = false;
      await client.call('wait', [(_) => invoked = true]);
      final request = await outgoing.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw StateError('outgoing request'),
      );
      final callbackName = (request[3]! as List).single as String;

      await (await first.future).close();
      final replacement = await second.future.timeout(const Duration(seconds: 3));
      replacement
        ..add(jsonEncode([2, callbackName, const <Object?>[]]))
        ..add(musicSyncEncodeRequest('barrier', const [], const []));
      await barrier.future.timeout(const Duration(seconds: 2));
      expect(invoked, isFalse);
    });

    test('callback requests are answered with the handler result', () async {
      final accepted = Completer<WebSocket>();
      final outgoing = Completer<List<Object?>>();
      final callbackResponse = Completer<List<Object?>>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        accepted.complete(socket);
        socket.listen((data) {
          final frame = jsonDecode(data as String);
          if (frame is! List || frame.isEmpty) return;
          if (frame.first == 0) outgoing.complete(frame.cast<Object?>());
          if (frame.first == 3) callbackResponse.complete(frame.cast<Object?>());
        });
      });
      await client.connect(address, keyInfo);
      final call = client.call('wait', [(List<Object?> args) => 'ack:${args.single}']);
      final request = await outgoing.future.timeout(const Duration(seconds: 2));
      final callbackName = (request[3]! as List).single as String;
      final socket = await accepted.future;

      socket.add(
        jsonEncode([
          2,
          callbackName,
          const <Object?>['ok'],
        ]),
      );
      expect(await callbackResponse.future.timeout(const Duration(seconds: 2)), [3, callbackName, null, 'ack:ok']);
      socket.add(jsonEncode([1, request[1], null, null]));
      await call;
    });

    test('async callbacks are acknowledged only after their work completes', () async {
      final accepted = Completer<WebSocket>();
      final outgoing = Completer<List<Object?>>();
      final started = Completer<void>();
      final callbackResponse = Completer<List<Object?>>();
      final gate = Completer<String>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        accepted.complete(socket);
        socket.listen((data) {
          final frame = jsonDecode(data as String);
          if (frame is! List || frame.isEmpty) return;
          if (frame.first == 0) outgoing.complete(frame.cast<Object?>());
          if (frame.first == 3) callbackResponse.complete(frame.cast<Object?>());
        });
      });
      await client.connect(address, keyInfo);
      final call = client.call('wait', [
        (_) {
          started.complete();
          return gate.future;
        },
      ]);
      final request = await outgoing.future.timeout(const Duration(seconds: 2));
      final callbackName = (request[3]! as List).single as String;
      final socket = await accepted.future;

      socket.add(jsonEncode([2, callbackName, const <Object?>[]]));
      await started.future.timeout(const Duration(seconds: 2));
      expect(callbackResponse.isCompleted, isFalse);
      gate.complete('ready');
      expect(await callbackResponse.future.timeout(const Duration(seconds: 2)), [3, callbackName, null, 'ready']);
      socket.add(jsonEncode([1, request[1], null, null]));
      await call;
    });

    test('throwing and released callbacks receive error responses', () async {
      final accepted = Completer<WebSocket>();
      final outgoing = Completer<List<Object?>>();
      final responses = <List<Object?>>[];
      final both = Completer<void>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        accepted.complete(socket);
        socket.listen((data) {
          final frame = jsonDecode(data as String);
          if (frame is! List || frame.isEmpty) return;
          if (frame.first == 0) outgoing.complete(frame.cast<Object?>());
          if (frame.first == 3) {
            responses.add(frame.cast<Object?>());
            if (responses.length == 2 && !both.isCompleted) both.complete();
          }
        });
      });
      await client.connect(address, keyInfo);
      final call = client.call('wait', [(_) => throw StateError('callback failed')]);
      final request = await outgoing.future.timeout(const Duration(seconds: 2));
      final callbackName = (request[3]! as List).single as String;
      final socket = await accepted.future;

      socket
        ..add(jsonEncode([2, callbackName, const <Object?>[]]))
        ..add(jsonEncode([2, 'func_released', const <Object?>[]]));
      await both.future.timeout(const Duration(seconds: 2));
      expect(responses[0][2], isA<Map<Object?, Object?>>());
      expect((responses[0][2]! as Map<Object?, Object?>)['message'], contains('callback failed'));
      expect(responses[1][1], 'func_released');
      expect((responses[1][2]! as Map<Object?, Object?>)['message'], 'func_released is released');
      socket.add(jsonEncode([1, request[1], null, null]));
      await call;
    });

    test('a late async callback reply is not sent into a replacement socket', () async {
      final first = Completer<WebSocket>();
      final second = Completer<WebSocket>();
      final outgoing = Completer<List<Object?>>();
      final started = Completer<void>();
      final gate = Completer<String>();
      final barrier = Completer<List<Object?>>();
      final replacementCallbacks = <List<Object?>>[];
      var connections = 0;
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        if (connections++ == 0) {
          first.complete(socket);
          socket.listen((data) {
            final frame = jsonDecode(data as String);
            if (frame is List && frame.isNotEmpty && frame.first == 0 && !outgoing.isCompleted) {
              outgoing.complete(frame.cast<Object?>());
            }
          });
        } else {
          second.complete(socket);
          socket.listen((data) {
            final frame = jsonDecode(data as String);
            if (frame is! List || frame.isEmpty) return;
            final response = frame.cast<Object?>();
            if (response.first == 3) replacementCallbacks.add(response);
            if (response.first == 1 && response[1] == 'barrier' && !barrier.isCompleted) barrier.complete(response);
          });
        }
      });
      await client.connect(address, keyInfo);
      final call = client.call('wait', [
        (_) {
          started.complete();
          return gate.future;
        },
      ]);
      final failed = expectLater(call, throwsA(isA<Exception>()));
      final request = await outgoing.future.timeout(const Duration(seconds: 2));
      final callbackName = (request[3]! as List).single as String;
      final original = await first.future;
      original.add(jsonEncode([2, callbackName, const <Object?>[]]));
      await started.future.timeout(const Duration(seconds: 2));

      await original.close();
      await failed;
      final replacement = await second.future.timeout(const Duration(seconds: 3));
      gate.complete('late');
      replacement.add(musicSyncEncodeRequest('barrier', const [], const []));
      await barrier.future.timeout(const Duration(seconds: 2));
      expect(replacementCallbacks, isEmpty);
    });

    test('async handlers are acknowledged only after their work completes', () async {
      final delayed = Completer<List<Object?>>();
      final pushed = Completer<List<Object?>>();
      final barrier = Completer<List<Object?>>();
      final gate = Completer<String>();
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket
          ..add(musicSyncEncodeRequest('delayed', const [], const []))
          ..add(musicSyncEncodeRequest('pushed', const [], const []))
          ..add(musicSyncEncodeRequest('barrier', const [], const []))
          ..listen((data) {
            final frame = jsonDecode(data as String);
            if (frame is! List || frame.isEmpty || frame.first != 1) return;
            final response = frame.cast<Object?>();
            if (response[1] == 'delayed' && !delayed.isCompleted) delayed.complete(response);
            if (response[1] == 'pushed' && !pushed.isCompleted) pushed.complete(response);
            if (response[1] == 'barrier' && !barrier.isCompleted) barrier.complete(response);
          });
      });
      client
        ..registerHandler('delayed', (_) => gate.future)
        ..registerPushHandler('pushed', (_) => gate.future)
        ..registerHandler('barrier', (_) => null);
      await client.connect(address, keyInfo);

      await barrier.future.timeout(const Duration(seconds: 2));
      expect(delayed.isCompleted, isFalse);
      expect(pushed.isCompleted, isFalse);
      gate.complete('ready');
      expect(await delayed.future.timeout(const Duration(seconds: 2)), [1, 'delayed', null, 'ready']);
      expect(await pushed.future.timeout(const Duration(seconds: 2)), [1, 'pushed', null, null]);
    });

    test('a late async reply is not sent into a replacement socket', () async {
      final first = Completer<WebSocket>();
      final second = Completer<WebSocket>();
      final started = Completer<void>();
      final gate = Completer<String>();
      final barrier = Completer<List<Object?>>();
      final replacementFrames = <List<Object?>>[];
      var connections = 0;
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        if (connections++ == 0) {
          first.complete(socket);
          socket.add(musicSyncEncodeRequest('delayed', const [], const []));
        } else {
          socket.listen((data) {
            final frame = jsonDecode(data as String);
            if (frame is! List || frame.isEmpty || frame.first != 1) return;
            final response = frame.cast<Object?>();
            replacementFrames.add(response);
            if (response[1] == 'barrier' && !barrier.isCompleted) barrier.complete(response);
          });
          second.complete(socket);
        }
      });
      client
        ..registerHandler('delayed', (_) {
          started.complete();
          return gate.future;
        })
        ..registerHandler('barrier', (_) => null);
      await client.connect(address, keyInfo);
      await started.future.timeout(const Duration(seconds: 2));

      await (await first.future).close();
      final replacement = await second.future.timeout(const Duration(seconds: 3));
      gate.complete('late');
      replacement.add(musicSyncEncodeRequest('barrier', const [], const []));
      await barrier.future.timeout(const Duration(seconds: 2));
      expect(replacementFrames.where((frame) => frame[1] == 'delayed'), isEmpty);
    });

    test('a malformed frame fails the session without escaping the socket listener', () async {
      final accepted = Completer<WebSocket>();
      server.listen((request) async {
        accepted.complete(await WebSocketTransformer.upgrade(request));
      });
      final failed = Completer<MusicSyncStatus>();
      final subscription = client.status.listen((status) {
        if (status == MusicSyncStatus.failed && !failed.isCompleted) failed.complete(status);
      });
      await client.connect(address, keyInfo);

      (await accepted.future).add('{not json');
      await failed.future.timeout(const Duration(seconds: 2));
      expect(client.isConnected, isFalse);
      await subscription.cancel();
    });
  });

  group('client surface', () {
    test('the newest connect supersedes an earlier attempt before it opens a client', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(musicSyncProvider.notifier);
      await controller.setHost('127.0.0.1:1');
      final earlier = controller.connect();
      await controller.setHost('');
      final latest = controller.connect();
      await Future.wait([earlier, latest]);

      final state = container.read(musicSyncProvider);
      expect(state.status, MusicSyncStatus.failed);
      expect(state.note, MusicSyncNote.invalidAddress);
    });

    test('the host history keeps the reference add semantics', () {
      final grown = musicSyncNextHostHistory(const ['a', 'b'], 'c');
      expect(grown, ['c', 'a', 'b']);
      // A duplicate stays where it is; the list is untouched.
      expect(musicSyncNextHostHistory(grown, 'a'), same(grown));
      // The cap is the reference's twenty.
      var history = <String>[];
      for (var i = 0; i < kMusicSyncHostHistoryLimit + 5; i++) {
        history = musicSyncNextHostHistory(history, 'host-$i');
      }
      expect(history.length, kMusicSyncHostHistoryLimit);
      expect(history.first, 'host-${kMusicSyncHostHistoryLimit + 4}');
      expect(history.last, 'host-5');
      // An empty address records nothing.
      expect(musicSyncNextHostHistory(const ['a'], ''), same(const ['a']));
    });

    test('address parsing accepts both schemes and bare hosts', () {
      final address = MusicSyncAddress.parse('http://h:1');
      expect(address?.wsScheme, 'ws');
      expect(MusicSyncAddress.parse('https://h')?.wsScheme, 'wss');
      expect(MusicSyncAddress.parse('h:2')?.httpScheme, 'http');
      expect(MusicSyncAddress.parse('ws://h'), isNull);
      expect(MusicSyncAddress.parse('  '), isNull);
    });

    test('key info round-trips', () {
      const info = MusicSyncKeyInfo(clientId: 'id', key: 'key', serverName: 'srv');
      expect(MusicSyncKeyInfo.fromJson(jsonDecode(jsonEncode(info.toJson()))).serverName, 'srv');
      expect(() => MusicSyncKeyInfo.fromJson(<String, Object?>{}), throwsFormatException);
    });
  });
}

final class _UnusedHttp implements LiveHttp {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
