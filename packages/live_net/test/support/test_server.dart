import 'dart:async';
import 'dart:io';

/// A throwaway loopback HTTP server so transport tests never touch the
/// network.
final class TestServer {
  new _(this._server);

  final HttpServer _server;

  /// Base URL of the server, e.g. `http://127.0.0.1:53412`.
  late final Uri url = Uri.parse('http://127.0.0.1:${_server.port}');

  /// Binds a loopback server dispatching every request to [handler].
  static Future<TestServer> start(FutureOr<void> Function(HttpRequest request) handler) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.forEach((request) async {
        try {
          await handler(request);
        } on Object {
          // Handler failures must not kill the server; the awaiting test
          // observes the outcome through its own expectations.
        }
      }),
    );
    return TestServer._(server);
  }

  /// Stops the server and drops open connections.
  Future<void> close() => _server.close(force: true);
}
