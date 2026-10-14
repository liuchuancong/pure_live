# live_websocket

Cross-platform WebSocket client foundation for Pure Live, built on
`web_socket_channel`. Pure Dart; runs on Android, iOS, Windows, macOS,
Linux and web.

## Scope

Transport only. This package owns the connection lifecycle, message
passing, heartbeats, reconnection, state notification, error reporting and
resource release. It never touches authentication, platform protocols,
codec semantics or dispatch rules — business modules (live sites, danmaku,
interaction, remote control) consume `LiveWebSocketClient` through its
unified interface and stay free to swap the underlying implementation via
an injected `WebSocketChannelFactory`.

## Usage

```dart
import 'dart:convert';

import 'package:live_websocket/live_websocket.dart';

Future<void> example() async {
  final client = LiveWebSocketClient(
    uri: Uri.parse('wss://example.com/ws'),
    config: const WebSocketConfig(
      connectTimeout: Duration(seconds: 15),
      pingInterval: Duration(seconds: 30),
      reconnectPolicy: ReconnectPolicy(
        enabled: true,
        maxAttempts: 10,
        initialDelay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 30),
        jitter: 0.2,
      ),
      heartbeat: HeartbeatConfig(
        interval: Duration(seconds: 30),
        payload: () => jsonEncode({'type': 'ping'}),
        timeout: Duration(seconds: 45),
      ),
    ),
  );

  client.states.listen((state) => print('state: $state'));
  client.messages.listen((frame) => print('frame: $frame'));
  client.errors.listen((error) => print('error: $error'));

  await client.connect();
  client.send(jsonEncode({'type': 'subscribe', 'channel': 'live'}));

  // Later, when the session is no longer needed:
  await client.dispose();
}
```

Subscribe to `messages` / `states` / `errors` before calling `connect`;
the streams are broadcast and frames emitted before anyone listens are
dropped.

## Design notes

- **State machine** — `disconnected → connecting → connected`, with
  `reconnecting` entered while a retry is scheduled or in flight.
  Exhausting the reconnect policy or an explicit `disconnect` returns to
  `disconnected`.
- **Reconnect policy** — exponential backoff from `initialDelay` up to
  `maxDelay`, optional jitter, `maxAttempts < 0` for unlimited retries.
  The counter resets on every successful handshake, and an explicit
  `disconnect` never reconnects.
- **Heartbeats** — `pingInterval` is the protocol-level ping. For servers
  that need an application-level payload, `HeartbeatConfig` sends a
  configurable payload every `interval` and, with `timeout` set, treats a
  silent connection as dead and forces a reconnect.
- **Generation guard** — every connection attempt carries a generation
  counter, so late events from a superseded connection can never leak into
  the new one.
- **Testable** — pass a `WebSocketChannelFactory` to the client to supply
  fake channels; the bundled tests exercise reconnects, retry limits,
  heartbeat timeouts and disposal this way.
