import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:live_shell/live_shell.dart';
import 'package:test/test.dart';

/// A port band unlikely to collide with anything else on a development machine.
///
/// Not guaranteed to be free — Windows reserves whole ranges for Hyper-V and
/// WSL, and a reserved port makes `bind` fail in a way nothing in the code under
/// test caused. The tests that need to own a port therefore ask before assuming,
/// and skip rather than fail when the machine will not hand one over.
const int _base = 51873;

final List<Directory> _tempDirs = [];

File _nonceFile(String tag) {
  final directory = Directory.systemTemp.createTempSync('shell-instance-$tag');
  _tempDirs.add(directory);
  return File('${directory.path}/instance.key');
}

/// Whether a port can be bound and released right now.
Future<bool> _canBind(int port) async {
  try {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await probe.close();
    return true;
  } on Object {
    return false;
  }
}

/// The port a channel is actually listening on.
///
/// [SocketInstanceChannel.port] is the one its identity hashes to; when that is
/// taken by someone else the channel falls back to an ephemeral port on purpose
/// (a stranger's port must not stop the app starting). A test that dials
/// [SocketInstanceChannel.port] is therefore dialling a number that may have
/// nothing behind it — this is the port with a listener on it.
int _listening(SocketInstanceChannel channel) => channel.listeningPort!;

void main() {
  setUpAll(() async {
    if (!await _canBind(_base)) {
      throw StateError('the reserved port band at $_base is unusable on this machine; move _base');
    }
  });

  tearDownAll(() async {
    for (final directory in _tempDirs) {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    }
    _tempDirs.clear();
  });

  group('SocketInstanceChannel', () {
    test('a cold start carrying a file keeps the request until someone listens', () async {
      final nonce = _nonceFile('cold');
      final primary = SocketInstanceChannel(appId: 'cold-start', nonceFile: nonce, basePort: _base, portSpan: 1);
      const file = OpenFile(r'C:\lists\cctv.m3u');

      expect(await primary.acquire(arguments: file.toArguments()), InstanceRole.primary);

      // Nothing was subscribed at acquire time; the request must not be lost.
      final received = <LaunchIntent>[];
      primary.forwarded.listen(received.add);
      await Future<void>.delayed(Duration.zero);

      expect(received, [file]);
      await primary.dispose();
    });

    test('the second launch hands its request over and is told it landed', () async {
      final nonce = _nonceFile('handoff');
      final primary = SocketInstanceChannel(appId: 'same-id', nonceFile: nonce, basePort: _base + 1, portSpan: 1);
      expect(await primary.acquire(arguments: const []), InstanceRole.primary);
      final received = <LaunchIntent>[];
      primary.forwarded.listen(received.add);

      final secondary = SocketInstanceChannel(appId: 'same-id', nonceFile: nonce, basePort: _base + 1, portSpan: 1);
      final role = await secondary.acquire(
        arguments: OpenRoomLink(Uri.parse('https://live.example/room/9')).toArguments(),
      );

      expect(role, InstanceRole.forwarded);
      await _until(() => received.isNotEmpty);

      expect(received.single, isA<OpenRoomLink>());
      expect(await secondary.nonceFile.readAsString(), isNotEmpty, reason: 'the primary token survives');
      await primary.dispose();
    });

    test('a listener that does not speak our protocol does not block the start', () async {
      const port = _base + 2;
      if (!await _canBind(port)) {
        markTestSkipped('no control over port $port on this machine');
        return;
      }
      final nonce = _nonceFile('foreign');
      final channel = SocketInstanceChannel(appId: 'foreign-port', nonceFile: nonce, basePort: port, portSpan: 1);
      // Occupy the port this identity hashes to, with something that is not us.
      final squatter = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      squatter.listen((socket) => socket.add('I am another program\n'.codeUnits));

      final role = await channel.acquire(arguments: const ShowMainWindow().toArguments());

      expect(role, InstanceRole.primary, reason: 'refusing to start because a stranger holds a port is an outage');
      expect(channel.listeningPort, isNot(port), reason: 'it fell back off the taken port');
      await channel.dispose();
      await squatter.close();
    });

    test('a wrong token is refused, so a foreign process cannot wake us', () async {
      final nonce = _nonceFile('stale');
      final primary = SocketInstanceChannel(appId: 'stale-case', nonceFile: nonce, basePort: _base + 3, portSpan: 1);
      expect(await primary.acquire(arguments: const []), InstanceRole.primary);
      final received = <LaunchIntent>[];
      primary.forwarded.listen(received.add);

      // A process that guessed the port but not the token.
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, _listening(primary));
      socket.add('{"protocol":"pure-live","nonce":"guessed","intent":"x"}\n'.codeUnits);
      await socket.flush();
      final reply = await socket.first;
      socket.destroy();

      expect(String.fromCharCodes(reply), contains('"ok":false'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(received, isEmpty);
      await primary.dispose();
    });

    test('the right token delivers the request and answers ok', () async {
      final nonce = _nonceFile('roundtrip');
      final primary = SocketInstanceChannel(appId: 'pair', nonceFile: nonce, basePort: _base + 5, portSpan: 1);
      expect(await primary.acquire(arguments: const []), InstanceRole.primary);
      final received = <LaunchIntent>[];
      primary.forwarded.listen(received.add);

      // Read the token the way a second process would: from the shared file.
      final socket = await Socket.connect(InternetAddress.loopbackIPv4, _listening(primary));
      // Encoded rather than spelled out: the intent payload is itself JSON with
      // quotes inside, and a hand-built string around it is malformed JSON that
      // the server answers as "not ours".
      socket.add(
        utf8.encode(
          '${jsonEncode({'protocol': 'pure-live', 'nonce': await nonce.readAsString(), 'intent': const ShowRecorder().toArguments().first})}\n',
        ),
      );
      await socket.flush();
      final reply = utf8.decode(await socket.first, allowMalformed: true);
      socket.destroy();

      expect(reply, contains('"ok":true'));
      await _until(() => received.isNotEmpty);
      expect(received.single, const ShowRecorder());
      await primary.dispose();
    });

    test('publish inside the primary reaches its own listeners', () async {
      final nonce = _nonceFile('publish');
      final primary = SocketInstanceChannel(appId: 'publish-case', nonceFile: nonce, basePort: _base + 4, portSpan: 1);
      await primary.acquire(arguments: const []);
      final received = <LaunchIntent>[];
      primary.forwarded.listen(received.add);

      await primary.publish(const ShowRecorder());

      await _until(() => received.isNotEmpty);
      expect(received.single, const ShowRecorder());
      await primary.dispose();
    });

    test('a disposed channel leaves nothing listening', () async {
      final nonce = _nonceFile('dispose');
      final primary = SocketInstanceChannel(appId: 'gone', nonceFile: nonce, basePort: _base + 6, portSpan: 1);
      await primary.acquire(arguments: const []);
      final port = _listening(primary);

      await primary.dispose();

      expect(nonce.existsSync(), isFalse, reason: 'a stale token makes the next launch wait for nothing');
      expect(await _canBind(port), isTrue, reason: 'the port is handed back');
    });
  });
}

Future<void> _until(bool Function() condition, {Duration timeout = const Duration(seconds: 2)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  if (!condition()) {
    throw TimeoutException('the condition never became true');
  }
}
