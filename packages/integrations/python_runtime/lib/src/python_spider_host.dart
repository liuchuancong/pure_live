// Module: lib/src/python_spider_host.dart
// Purpose: The embedded-CPython spider host: starts the worker, installs
// spider code, and answers the SpiderHandle contract by dispatching through
// the local gateway.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/adr/0017-tvbox-python-runtime.md. One host per app process. The
// worker is plain stdlib python (see spider_worker.py.dart); this side never
// parses spider results - it moves JSON. Unverified in this change: the
// embedded interpreter has to be exercised on a real device, where
// serious_python's per-platform python library ships.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pure_live_external_tvbox/pure_live_external_tvbox.dart';
import 'package:serious_python/serious_python.dart';

import 'local_gateway.dart';
import 'spider_worker.py.dart';

/// Installs and drives spiders in the embedded interpreter.
final class PythonSpiderHost implements SpiderHandle {
  PythonSpiderHost._({required this.key, required this.extend, required this._gateway});

  /// The gateway every host of this process shares: one port, one worker.
  static LocalSpiderGateway? _sharedGateway;
  static Future<LocalSpiderGateway>? _starting;

  /// Brings the runtime up once per process: gateway, python files, worker.
  static Future<LocalSpiderGateway> ensureStarted(Directory dataDirectory) async {
    final existing = _sharedGateway;
    if (existing != null) {
      return existing;
    }
    final starting = _starting;
    if (starting != null) {
      return starting;
    }
    final future = _start(dataDirectory);
    _starting = future;
    try {
      final gateway = await future;
      _sharedGateway = gateway;
      return gateway;
    } catch (error) {
      _starting = null;
      rethrow;
    }
  }

  static Future<LocalSpiderGateway> _start(Directory dataDirectory) async {
    final gateway = LocalSpiderGateway();
    await gateway.start();
    final spiderDir = Directory(p.join(dataDirectory.path, 'spiders'));
    if (!await spiderDir.exists()) {
      await spiderDir.create(recursive: true);
    }
    final workerFile = File(p.join(dataDirectory.path, 'pure_live_worker.py'));
    await workerFile.writeAsString(pythonWorkerProgram, flush: true);
    // The worker blocks by design (its main is a job loop); serious_python
    // runs the program off the UI thread when sync is absent.
    await SeriousPython.runProgram(
      workerFile.path,
      environmentVariables: <String, String>{
        'PURE_LIVE_GATEWAY': gateway.baseUrl,
        'PURE_LIVE_SPIDER_DIR': spiderDir.path,
        'PYTHONIOENCODING': 'utf-8',
      },
    );
    return gateway;
  }

  /// Writes one spider module into the worker's spider directory. Content is
  /// the site's python spider, installed from its plugin record.
  static Future<void> installSpider(Directory dataDirectory, String key, String code) async {
    final dir = Directory(p.join(dataDirectory.path, 'spiders'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await File(p.join(dir.path, '$key.py')).writeAsString(code, flush: true);
  }

  /// The site key; also the spider module file name in the worker's directory.
  final String key;
  final String extend;
  final LocalSpiderGateway _gateway;

  /// Creates one host for one site, starting the shared runtime if needed.
  static Future<PythonSpiderHost> spawn({
    required String key,
    required String extend,
    required Directory dataDirectory,
  }) async {
    final gateway = await ensureStarted(dataDirectory);
    return PythonSpiderHost._(key: key, extend: extend, gateway: gateway);
  }

  Future<Object?> _call(String method, List<Object?> args, {Duration timeout = const Duration(seconds: 30)}) {
    return _gateway.submit(key, method, args, timeout: timeout);
  }

  Future<Map<String, Object?>?> _callMap(String method, List<Object?> args) async {
    final answer = await _call(method, args);
    return answer is Map ? Map<String, Object?>.from(answer) : null;
  }

  @override
  Future<Map<String, Object?>?> init(String extend) => _callMap('init', <Object?>[extend]);

  @override
  Future<Map<String, Object?>?> homeContent(Map<String, Object?> filter) => _callMap('homeContent', <Object?>[filter]);

  @override
  Future<Map<String, Object?>?> homeVideoContent() => _callMap('homeVideoContent', const <Object?>[]);

  @override
  Future<Map<String, Object?>?> categoryContent(String tid, String pg, bool filter, Map<String, Object?> extend) =>
      _callMap('categoryContent', <Object?>[tid, pg, filter, extend]);

  @override
  Future<Map<String, Object?>?> detailContent(List<String> ids) => _callMap('detailContent', <Object?>[ids]);

  @override
  Future<Map<String, Object?>?> searchContent(String key, bool quick, String pg) =>
      _callMap('searchContent', <Object?>[key, quick, pg]);

  @override
  Future<Map<String, Object?>?> playerContent(String flag, String id, bool vipFlags) =>
      _callMap('playerContent', <Object?>[flag, id, vipFlags]);

  @override
  Future<Map<String, Object?>?> liveContent(String url) => _callMap('liveContent', <Object?>[url]);

  @override
  Future<void> destroy() async {
    // Spiders live in the shared worker process and are cached per key; a
    // per-site destroy would kill state other handles may still want. Real
    // teardown is Python.terminate, an app-level decision.
  }
}

/// Encodes a spider answer the way diagnostics expect: as text, bounded.
String spiderAnswerPreview(Object? answer) {
  final text = answer is String ? answer : jsonEncode(answer);
  return text.length > 400 ? '${text.substring(0, 400)}…' : text;
}
