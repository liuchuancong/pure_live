import 'dart:async';
import 'dart:io';

/// Owns the network side of TLS connections even before a request exists.
///
/// The pinned Dart TLS task loses TCP cancellation ownership after ClientHello.
/// HTTPS therefore uses a private, paired loopback TCP bridge: TLS still runs
/// end-to-end in SecureSocket/HttpClient with the original host and trust store.
/// Closing the bridge retires both the peer connection and the pending handshake.
/// Plain HTTP keeps the direct socket path. No HTTP parsing or TLS termination
/// is performed by the bridge; HttpClient still owns proxy CONNECT and pooling.
class CancellableHttpConnections {
  CancellableHttpConnections({this.securityContext});

  final SecurityContext? securityContext;
  final Set<_OwnedConnection> _connections = {};
  bool _closed = false;

  int get activeConnectionCount => _connections.length;

  Future<ConnectionTask<Socket>> connect(Uri uri, String? proxyHost, int? proxyPort) async {
    if (_closed) throw const SocketException('Recording connections are closed');
    final connection = _OwnedConnection(
      uri: uri,
      host: proxyHost ?? uri.host,
      port: proxyPort ?? uri.port,
      proxy: proxyHost != null,
      context: securityContext,
      onClosed: (connection) => _connections.remove(connection),
    );
    _connections.add(connection);
    return ConnectionTask.fromSocket(connection.open(), connection.cancel);
  }

  /// Synchronous cancellation fences new work and immediately closes sockets.
  /// [settled] additionally waits for late local allocations to be retired.
  void cancel() {
    _closed = true;
    for (final connection in _connections.toList()) {
      connection.cancel();
    }
  }

  Future<void> get settled async {
    await Future.wait(_connections.toList().map((connection) => connection.settled));
  }
}

class _OwnedConnection {
  _OwnedConnection({
    required this.uri,
    required this.host,
    required this.port,
    required this.proxy,
    required this.context,
    required this.onClosed,
  });

  final Uri uri;
  final String host;
  final int port;
  final bool proxy;
  final SecurityContext? context;
  final void Function(_OwnedConnection) onClosed;
  final List<Socket> _sockets = [];
  final List<ConnectionTask<Socket>> _tasks = [];
  final List<Future<void>> _cleanup = [];
  final Completer<Socket> _result = Completer<Socket>();
  final Completer<void> _settled = Completer<void>();
  ServerSocket? _listener;
  StreamSubscription<Socket>? _subscription;
  bool _closed = false;
  bool _opening = true;
  int _finishedPipes = 0;

  Future<void> get settled => _settled.future;

  Future<Socket> open() {
    unawaited(_open());
    return _result.future;
  }

  void _checkOpen() {
    if (_closed) throw const SocketException('Recording connection cancelled');
  }

  Future<Socket> _tcp(Object host, int port) async {
    final task = await Socket.startConnect(host, port);
    _tasks.add(task);
    if (_closed) task.cancel();
    final socket = await task.socket;
    _sockets.add(socket);
    if (_closed) socket.destroy();
    _checkOpen();
    socket.setOption(SocketOption.tcpNoDelay, true);
    return socket;
  }

  Future<void> _open() async {
    try {
      final remote = await _tcp(host, port);
      Socket result = remote;
      if (uri.scheme == 'https') {
        final listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0, shared: false);
        _listener = listener;
        _checkOpen();
        final paired = Completer<Socket>();
        unawaited(paired.future.then<void>((_) {}, onError: (Object _) {}));
        int? expectedPort;
        final candidates = <Socket>[];
        void select(Socket socket) {
          if (!_closed && !paired.isCompleted && socket.remotePort == expectedPort) {
            if (!_sockets.contains(socket)) _sockets.add(socket);
            paired.complete(socket);
          } else {
            socket.destroy();
          }
        }

        _subscription = listener.listen(
          (socket) {
            if (expectedPort == null && !_closed && candidates.length < 4) {
              _sockets.add(socket);
              candidates.add(socket);
            } else {
              select(socket);
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!paired.isCompleted) paired.completeError(error, stack);
          },
          onDone: () {
            if (!paired.isCompleted) paired.completeError(const SocketException('TLS bridge closed'));
          },
        );
        // Pair by the actual connected endpoint, not the first arbitrary local
        // connection. Never read a target address or plaintext from a peer.
        final local = await _tcp(InternetAddress.loopbackIPv4, listener.port);
        expectedPort = local.port;
        for (final socket in candidates) {
          select(socket);
        }
        final bridge = await paired.future;
        await listener.close();
        await _subscription?.cancel();
        _subscription = null;
        _listener = null;
        _checkOpen();
        bridge.setOption(SocketOption.tcpNoDelay, true);
        _pipe(remote, bridge);
        _pipe(bridge, remote);
        // A proxy receives plain CONNECT first. HttpClient upgrades that socket
        // itself, using its SecurityContext and the destination hostname.
        result = proxy ? local : await SecureSocket.secure(local, host: uri.host, context: context);
        if (!proxy) _sockets.add(result);
        _checkOpen();
      }
      if (!_result.isCompleted) _result.complete(result);
      // For plain HTTP, done is the sink lifetime. The owner still retains the
      // socket until that ends, or cancellation tears down this connection.
      if (uri.scheme != 'https') {
        unawaited(result.done.then<void>((_) => cancel(), onError: (Object _) => cancel()));
      }
    } on Object catch (error, stack) {
      if (!_result.isCompleted) _result.completeError(error, stack);
      cancel();
    } finally {
      _opening = false;
      if (_closed) unawaited(_finishCleanup());
    }
  }

  void _pipe(Socket source, Socket destination) {
    // addStream propagates the sink's backpressure; there is no unbounded
    // queue of copied TLS records. EOF/error retires this connection only.
    final forwarding = () async {
      try {
        await destination.addStream(source);
        await destination.flush();
        await destination.close();
        if (++_finishedPipes == 2) cancel();
      } on Object {
        cancel();
      }
    }();
    _cleanup.add(forwarding);
  }

  void cancel() {
    if (_closed) return;
    _closed = true;
    if (!_result.isCompleted) _result.completeError(const SocketException('Recording connection cancelled'));
    for (final task in _tasks) {
      task.cancel();
    }
    for (final socket in _sockets) {
      socket.destroy();
    }
    final listener = _listener;
    if (listener != null) _cleanup.add(listener.close().then<void>((_) {}));
    // Listener onDone also ends an unfinished local pairing wait.
    if (!_opening) unawaited(_finishCleanup());
  }

  Future<void> _finishCleanup() async {
    if (_settled.isCompleted) return;
    try {
      for (final socket in _sockets) {
        socket.destroy();
      }
      await _listener?.close();
      await _subscription?.cancel();
      await Future.wait(_cleanup);
    } finally {
      onClosed(this);
      if (!_settled.isCompleted) _settled.complete();
    }
  }
}
