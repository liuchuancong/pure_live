// Module: lib/src/local_gateway.dart
// Purpose: The loopback HTTP gateway the Python worker talks to: job dispatch,
// results, the bounded cache, and a log sink.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/adr/0017-tvbox-python-runtime.md. webtv's chaquo host gives
// spiders a local proxy (Proxy.getUrl) for cache and local proxying; this is
// that piece, with the job transport on top. One port on 127.0.0.1, Dart owns
// every endpoint, and the worker is a plain stdlib HTTP client - which is why
// the framework needs no pip packages to run a spider.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One queued spider call, waiting for its worker.
final class SpiderJob {
  SpiderJob({required this.key, required this.method, required this.args})
    : id = _nextId++,
      _completer = Completer<Object?>();

  static int _nextId = 1;

  final int id;
  final String key;
  final String method;
  final List<Object?> args;
  final Completer<Object?> _completer;

  Map<String, Object?> toQueueJson() => <String, Object?>{'id': id, 'key': key, 'method': method, 'args': args};

  Map<String, Object?> toResult(Object? result, {String? error}) => <String, Object?>{
    'id': id,
    'result': result,
    if (error != null) 'error': error,
  };
}

/// The gateway. Start before the worker; the port it bound goes to the worker
/// through an environment variable.
final class LocalSpiderGateway {
  LocalSpiderGateway({this.cacheCapacity = 256, this.cacheTtl = const Duration(minutes: 10)});

  final int cacheCapacity;
  final Duration cacheTtl;

  HttpServer? _server;
  final List<SpiderJob> _queue = <SpiderJob>[];
  final Map<int, SpiderJob> _pending = <int, SpiderJob>{};
  final Map<String, (Object?, DateTime)> _cache = <String, (Object?, DateTime)>{};
  final List<String> _logs = <String>[];

  /// The loopback address the worker is given. Valid after [start].
  String get baseUrl {
    final server = _server;
    if (server == null) {
      throw StateError('gateway is not started');
    }
    return 'http://127.0.0.1:${server.port}';
  }

  /// Binds on an OS-picked free port. Fails loudly: a gateway that silently
  /// bound nothing would strand the worker in a poll loop forever.
  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_serve, onError: (Object error) {});
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    for (final job in _pending.values) {
      if (!job._completer.isCompleted) {
        job._completer.completeError(StateError('gateway stopped'));
      }
    }
    _pending.clear();
    _queue.clear();
  }

  /// Submits one spider call. The returned future completes when a worker
  /// posts the result, or errors on timeout - the caller's clock, not the
  /// worker's.
  Future<Object?> submit(
    String key,
    String method,
    List<Object?> args, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    final job = SpiderJob(key: key, method: method, args: args);
    _pending[job.id] = job;
    _queue.add(job);
    return job._completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(job.id);
        _queue.remove(job);
        throw TimeoutException('spider $key.$method exceeded ${timeout}');
      },
    );
  }

  /// Recent worker log lines, oldest last, bounded like every diagnostic ring.
  List<String> get logs => List<String>.unmodifiable(_logs);

  Future<void> _serve(HttpRequest request) async {
    try {
      final path = request.uri.path;
      final query = request.uri.queryParameters;
      if (path == '/poll' && request.method == 'POST') {
        await _json(request, _poll());
      } else if (path == '/result' && request.method == 'POST') {
        final body = await _body(request);
        _complete(body);
        await _json(request, <String, Object?>{'ok': true});
      } else if (path == '/log' && request.method == 'POST') {
        final body = await _body(request);
        _logs.add('${DateTime.now().toIso8601String()} ${body['message']}');
        while (_logs.length > 128) {
          _logs.removeAt(0);
        }
        await _json(request, <String, Object?>{'ok': true});
      } else if (path == '/cache') {
        await _json(request, _cacheEndpoint(query, await _bodyOrNull(request)));
      } else {
        await _json(request, <String, Object?>{'error': 'unknown path $path'}, status: 404);
      }
    } catch (error) {
      await _json(request, <String, Object?>{'error': '$error'}, status: 500);
    }
  }

  Map<String, Object?> _poll() {
    if (_queue.isEmpty) {
      return <String, Object?>{'id': null};
    }
    final job = _queue.removeAt(0);
    return job.toQueueJson();
  }

  void _complete(Map<String, Object?> body) {
    final id = (body['id'] as num?)?.toInt();
    if (id == null) {
      return;
    }
    final job = _pending.remove(id);
    if (job == null || job._completer.isCompleted) {
      return;
    }
    final error = body['error'] as String?;
    if (error != null) {
      job._completer.completeError(StateError('spider ${job.key}.${job.method} failed: $error'));
    } else {
      job._completer.complete(body['result']);
    }
  }

  Map<String, Object?> _cacheEndpoint(Map<String, String> query, Map<String, Object?>? body) {
    final action = query['do'] ?? 'get';
    final key = query['key'] ?? '';
    switch (action) {
      case 'get':
        final entry = _cache[key];
        if (entry == null || DateTime.now().isAfter(entry.$2)) {
          _cache.remove(key);
          return <String, Object?>{};
        }
        // The worker reads this as raw text and json-decodes it, matching
        // webtv's cache contract (a JSON body or an empty one).
        final value = entry.$1;
        return <String, Object?>{'__raw__': value is String ? value : jsonEncode(value)};
      case 'set':
        while (_cache.length >= cacheCapacity) {
          _cache.remove(_cache.keys.first);
        }
        _cache[key] = ('${body?['value'] ?? ''}', DateTime.now().add(cacheTtl));
        return <String, Object?>{'ok': true};
      case 'del':
        _cache.remove(key);
        return <String, Object?>{'ok': true};
      default:
        return <String, Object?>{'error': 'unknown cache action $action'};
    }
  }

  Future<Map<String, Object?>?> _bodyOrNull(HttpRequest request) async {
    if (request.method != 'POST') {
      return null;
    }
    final text = await utf8.decoder.bind(request).join();
    if (text.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(text);
      return decoded is Map ? Map<String, Object?>.from(decoded) : <String, Object?>{'value': text};
    } on FormatException {
      return <String, Object?>{'value': text};
    }
  }

  Future<Map<String, Object?>> _body(HttpRequest request) async =>
      await _bodyOrNull(request) ?? const <String, Object?>{};

  Future<void> _json(HttpRequest request, Map<String, Object?> payload, {int status = 200}) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(payload));
    await request.response.close();
  }
}
