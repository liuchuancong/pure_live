import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:live_shell/src/instance/instance_channel.dart';
import 'package:live_shell/src/instance/launch_intent.dart';

/// The single-instance handoff over a loopback socket, carrying the request.
///
/// Why a socket instead of a named mutex: a mutex answers "am I the only one",
/// which is only half the problem. The interesting half is what the second
/// launch was *asking for*, and a lock has no way to carry it. A loopback
/// listener answers both on all three desktops with no native code, and it is
/// the same shape Electron uses underneath `requestSingleInstanceLock` plus the
/// arguments of its `second-instance` event.
///
/// Three choices worth defending:
///
/// * **The port is hashed from [appId], not stored in a lock file.** Two
///   processes starting in the same instant cannot both read "no file" and both
///   decide they are the primary; one of them simply fails to bind.
/// * **A failing handoff does not mean "quit".** If the port is taken but the
///   thing holding it does not answer our handshake, it is somebody else's
///   program, and refusing to start would be an outage caused by an unrelated
///   app. We bind an ephemeral port and run as a second instance instead —
///   degraded (no handoff), but honest.
/// * **A nonce gates the handshake.** Anything on the machine can connect to a
///   loopback port, and the message it could send is "open this file, open this
///   link". The primary writes a random token to [nonceFile], which lives under
///   the user's own profile; a message without it is refused. On Windows the
///   profile's ACL is what protects the file, and on POSIX the file is created
///   owner-read-write only.
///
/// macOS note: a sandboxed build needs `com.apple.security.network.server` and
/// `com.apple.security.network.client` entitlements, because the handoff is a
/// socket like any other.
final class SocketInstanceChannel implements InstanceChannel {
  /// A channel for one app identity.
  new({
    required this.appId,
    required this.nonceFile,
    this.basePort = 41750,
    this.portSpan = 900,
    this.protocolId = 'pure-live',
    this.timeout = const Duration(seconds: 2),
  });

  /// The stable identity the port is derived from.
  final String appId;

  /// Where the primary keeps its handshake token.
  final File nonceFile;

  /// The port range an identity is hashed into.
  final int basePort;

  /// How many ports the range spans.
  final int portSpan;

  /// The protocol marker, so a foreign listener is recognisable as foreign.
  final String protocolId;

  /// How long a handshake may take before the other side is assumed dead.
  final Duration timeout;

  final Random _random = Random.secure();

  ServerSocket? _server;
  InstanceRole _role = InstanceRole.none;
  String? _nonce;
  final List<LaunchIntent> _queued = [];
  late final StreamController<LaunchIntent> _intents = StreamController<LaunchIntent>.broadcast(onListen: _drainQueue);

  /// The port this identity hashes to.
  int get port => basePort + (_fold(appId) % portSpan);

  /// The port actually listening, which differs from [port] when the derived one
  /// was taken by an unrelated program and we fell back to an ephemeral one.
  ///
  /// Worth exposing: when a handoff stops working, "which port am I really on"
  /// is the first question, and reading it out of a log line the app has to
  /// remember to print is worse than reading it from the object.
  int? get listeningPort => _server?.port;

  @override
  InstanceRole get role => _role;

  @override
  Stream<LaunchIntent> get forwarded => _intents.stream;

  @override
  Future<InstanceRole> acquire({required List<String> arguments}) async {
    if (_role != InstanceRole.none) {
      return _role;
    }
    try {
      _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException {
      // Something holds our port. Ask it, politely, whether it is us.
      if (await _handoff(arguments)) {
        return _role = InstanceRole.forwarded;
      }
      _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    }
    _role = InstanceRole.primary;
    await _writeNonce();
    _server?.listen(_serve, onError: (Object error, StackTrace stack) => unawaited(_serveError(error, stack)));
    // The launch that *became* the primary may itself carry a request: a
    // double-clicked .m3u starts a cold instance, and that file is the reason
    // the app was asked to exist.
    final intent = LaunchIntent.fromArguments(arguments);
    if (intent != null) {
      _deliver(intent);
    }
    return _role;
  }

  @override
  Future<void> publish(LaunchIntent intent) async {
    // A request from inside the primary is the only case that belongs here; a
    // process that handed off has already exited by the time anything could
    // call this, and one that never acquired has no view of who is primary.
    _deliver(intent);
  }

  /// Closes the listener and removes the nonce file.
  ///
  /// Not required to exit — the operating system reclaims the port — but a
  /// leftover nonce file makes the next launch handshake against a dead token
  /// before it gives up and starts, which costs the viewer two seconds.
  Future<void> dispose() async {
    await _server?.close();
    _server = null;
    await _intents.close();
    _queued.clear();
    // Only the process that wrote the token may remove it: a handed-off second
    // instance shares this file with the primary, and deleting it there would
    // leave the running app unable to authenticate the next launch.
    if (_role != InstanceRole.primary) {
      return;
    }
    try {
      if (nonceFile.existsSync()) {
        await nonceFile.delete();
      }
    } on FileSystemException {
      // Nothing left to clean up.
    }
  }

  Future<void> _serve(Socket socket) async {
    final intent = _verify(await _readLine(socket));
    // `close()` flushes; destroying the socket straight after `add` can drop the
    // reply, and a second instance that never hears back starts a duplicate.
    await (socket..add(utf8.encode('${jsonEncode({'ok': intent != null})}\n'))).close();
    if (intent != null) {
      _deliver(intent);
    }
  }

  Future<void> _serveError(Object error, StackTrace stack) async {
    // A listener that dies on one bad connection must keep serving the rest;
    // the error is reported through the stream's own error channel so a caller
    // that cares can hear about it without the handoff stopping working.
    if (!_intents.isClosed) {
      _intents.addError(error, stack);
    }
  }

  /// Checks one request line and returns what it asks for, null if it is not
  /// ours.
  LaunchIntent? _verify(String? request) {
    if (request == null) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(request.trim());
    } on FormatException {
      return null;
    }
    if (decoded is! Map) {
      return null;
    }
    if (decoded['protocol'] != protocolId || decoded['nonce'] != _nonce) {
      return null;
    }
    final encoded = decoded['intent'];
    if (encoded is! String) {
      return null;
    }
    return LaunchIntent.fromArguments([encoded]);
  }

  Future<bool> _handoff(List<String> arguments) async {
    final nonce = _nonce ?? await _readNonce();
    if (nonce == null) {
      return false;
    }
    final intent = LaunchIntent.fromArguments(arguments);
    final request = jsonEncode({'protocol': protocolId, 'nonce': nonce, 'intent': intent?.toArguments().firstOrNull});
    Socket? socket;
    try {
      socket = await Socket.connect(InternetAddress.loopbackIPv4, port).timeout(timeout);
      final reply = await (socket..add(utf8.encode('$request\n'))).first.timeout(timeout);
      return utf8.decode(reply, allowMalformed: true).contains('"ok":true');
    } on Object {
      // Timeout, refused, or a listener that speaks another protocol.
      return false;
    } finally {
      socket?.destroy();
    }
  }

  Future<void> _writeNonce() async {
    final token = List<String>.generate(6, (_) => _random.nextInt(0xffffff).toRadixString(16).padLeft(6, '0')).join();
    _nonce = token;
    try {
      await nonceFile.writeAsString(token);
      if (!Platform.isWindows) {
        await Process.run('chmod', ['600', nonceFile.path]);
      }
    } on FileSystemException {
      // No writable place for a token: the gate is gone, so any local process
      // could wake our window with a link. Degraded, not fatal — and refusing to
      // start would be worse than the exposure.
    }
  }

  Future<String?> _readNonce() async {
    try {
      final text = await nonceFile.readAsString().timeout(timeout);
      final trimmed = text.trim();
      return trimmed.isEmpty ? null : trimmed;
    } on FileSystemException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  void _deliver(LaunchIntent intent) {
    if (_intents.hasListener) {
      _intents.add(intent);
      return;
    }
    // Nobody is listening yet — the primary's window may not exist, and the
    // settings screen certainly doesn't. Holding the request is what makes a
    // click land one beat late instead of never.
    _queued.add(intent);
    while (_queued.length > 8) {
      _queued.removeAt(0);
    }
  }

  void _drainQueue() {
    if (_queued.isEmpty) {
      return;
    }
    final pending = List<LaunchIntent>.of(_queued);
    _queued.clear();
    pending.forEach(_intents.add);
  }

  static Future<String?> _readLine(Stream<List<int>> source) {
    final completer = Completer<String?>();
    final buffer = StringBuffer();
    late StreamSubscription<List<int>> subscription;
    subscription = source.listen(
      (chunk) {
        buffer.write(utf8.decode(chunk, allowMalformed: true));
        if (buffer.toString().contains('\n')) {
          unawaited(subscription.cancel());
          if (!completer.isCompleted) {
            completer.complete(buffer.toString().trim());
          }
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(buffer.toString().trim());
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
      cancelOnError: true,
    );
    return completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        unawaited(subscription.cancel());
        return null;
      },
    );
  }

  static int _fold(String value) {
    var hash = 7;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}
