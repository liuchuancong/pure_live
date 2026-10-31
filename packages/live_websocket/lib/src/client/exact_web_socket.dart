/// The exact-handshake WebSocket client, resolved per platform.
///
/// YY's and SOOP's edges need a handshake `dart:io` will not spell; the
/// browser owns its own handshake, so the web build gets a stub that says so.
library;

export 'exact_web_socket_io.dart' if (dart.library.js_interop) 'exact_web_socket_web.dart';
