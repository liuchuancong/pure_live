import 'dart:async' show Completer;

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;

/// The transport the huya tests code against: routes by a path fragment,
/// holds the calls a gate names until it is released, and remembers every
/// ask. A fragment ending in `$` matches the path's tail, so `g/all$`
/// tells the groups page apart from the `g/all_hot_0` listings it would
/// otherwise swallow.
final class StubHttp implements LiveHttp {
  final calls = <Uri>[];
  final Map<String, Future<LiveResponse> Function(Uri url)> _routes = {};
  final Map<String, Completer<void>> _gates = {};

  /// Answers every call whose path carries [fragment] with [answer].
  void route(String fragment, Future<LiveResponse> Function(Uri url) answer) => _routes[fragment] = answer;

  /// Holds every call whose path carries [fragment] until it is completed.
  Completer<void> hold(String fragment) => _gates.putIfAbsent(fragment, Completer<void>.new);

  static bool _hits(String fragment, String path) =>
      fragment.endsWith(r'$') ? path.endsWith(fragment.substring(0, fragment.length - 1)) : path.contains(fragment);

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    calls.add(request.url);
    for (final gate in _gates.entries) {
      if (_hits(gate.key, request.url.path)) await gate.value.future;
    }
    for (final route in _routes.entries) {
      if (_hits(route.key, request.url.path)) return await route.value(request.url);
    }
    throw StateError('the stub holds no answer for ${request.url.path}');
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}
