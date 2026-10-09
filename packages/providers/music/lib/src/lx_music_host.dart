// Module: lib/src/lx_music_host.dart
// Purpose: The lx-music source host: runs a user-api script in the sandbox and
// answers musicUrl / lyric / pic through its request handler.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: lx-music-desktop user-api (preload.js). A source script registers
// itself with lx.on('request', handler) and announces its sources with
// lx.send('inited', apiInfo); the host then calls the handler with
// {action, source, info} and reads the url / lyric / pic from the answer.
// Users import these scripts - that is the music model: the shell runs
// whatever the user brings, it does not ship sources.

import 'dart:async';
import 'dart:convert';

import 'package:pure_live_js_runtime/pure_live_js_runtime.dart';
import 'package:pure_live_plugin_api/pure_live_plugin_api.dart';

import 'lx_crypto.dart';
import 'lx_prelude.dart';

/// One source a script announced through lx.send('inited').
final class LxSourceInfo {
  const LxSourceInfo({required this.name, required this.actions, required this.qualitys});

  factory LxSourceInfo.fromJson(Map<String, Object?> json) => LxSourceInfo(
    name: '${json['name'] ?? ''}',
    actions: [for (final action in (json['actions'] as List? ?? const [])) '$action'],
    qualitys: [for (final quality in (json['qualitys'] as List? ?? const [])) '$quality'],
  );

  final String name;

  /// Which of musicUrl / lyric / pic the source answers.
  final List<String> actions;
  final List<String> qualitys;

  bool serves(String action) => actions.contains(action);
}

/// The whole script identity, as lx.send('inited') carried it.
final class LxScriptInfo {
  LxScriptInfo({
    required this.id,
    required this.name,
    required this.sources,
    this.version,
    this.author,
    this.homepage,
    this.description,
  });

  final String id;
  final String name;
  final String? version;
  final String? author;
  final String? homepage;
  final String? description;

  /// source key -> what it serves, for example wy -> {name: 网易云, actions:
  /// [musicUrl, lyric], qualitys: [128k, 320k, flac]}.
  final Map<String, LxSourceInfo> sources;

  factory LxScriptInfo.fromJson(String id, Map<String, Object?> json) {
    final rawSources = json['sources'] ?? const <String, Object?>{};
    return LxScriptInfo(
      id: id,
      name: '${json['name'] ?? id}',
      version: json['version']?.toString(),
      author: json['author']?.toString(),
      homepage: json['homepage']?.toString(),
      description: json['description']?.toString(),
      sources: <String, LxSourceInfo>{
        for (final entry in (rawSources is Map ? rawSources : const <String, Object?>{}).entries)
          '${entry.key}': LxSourceInfo.fromJson(
            entry.value is Map ? Map<String, Object?>.from(entry.value as Map) : const {},
          ),
      },
    );
  }
}

/// One lx user-api script in one sandbox.
final class LxMusicApiHost {
  LxMusicApiHost._({required this.scriptId, required FjsJsSandbox sandbox}) : _sandbox = sandbox {
    sandbox.extendedApiHandler = _handleExtendedApi;
  }

  final String scriptId;
  final FjsJsSandbox _sandbox;
  final Completer<LxScriptInfo> _inited = Completer<LxScriptInfo>();
  bool _disposed = false;

  /// The script identity once lx.send('inited') arrived.
  Future<LxScriptInfo> get inited => _inited.future;

  /// Evaluates the lx environment and the script itself. The script is plain
  /// top-level code: it registers with lx.on / lx.send during evaluation.
  static Future<LxMusicApiHost> spawn({
    required String scriptId,
    required String name,
    required String source,
    required HostBridge bridge,
    SandboxPolicy policy = const SandboxPolicy(),
  }) async {
    final sandbox = FjsJsSandbox(pluginId: scriptId, policy: policy, bridge: bridge);
    final host = LxMusicApiHost._(scriptId: scriptId, sandbox: sandbox);
    await sandbox.start();
    // currentScriptInfo is the script's own identity, defined before it runs.
    final scriptInfo = <String, String>{'name': name};
    final outcome = await sandbox.evaluate(
      SandboxUnit(
        pluginId: scriptId,
        key: 'lx.prelude',
        source: 'globalThis.__LxScriptInfo = ${jsonEncode(scriptInfo)};\n$lxApiPrelude',
      ),
    );
    if (!outcome.isClean) {
      await sandbox.dispose();
      throw StateError('lx host for $scriptId failed to load: ${outcome.message}');
    }
    final script = await sandbox.evaluate(SandboxUnit(pluginId: scriptId, key: 'lx.script', source: source));
    if (!script.isClean) {
      await sandbox.dispose();
      throw StateError('lx script $scriptId failed to evaluate: ${script.message}');
    }
    return host;
  }

  /// Handles what the plugin bridge does not: lx lifecycle events and the
  /// crypto/zlib endpoints the shim forwards here.
  Future<Object?>? _handleExtendedApi(String api, Map<String, Object?> payload) {
    switch (api) {
      case 'lx.inited':
        final info = LxScriptInfo.fromJson(scriptId, payload);
        if (!_inited.isCompleted) {
          _inited.complete(info);
        }
        return Future.value(<String, Object?>{'ok': true});
      case 'lx.updateAlert':
        // Recorded, never shown here: update prompts belong to the management
        // page, not to a source script's popup.
        return Future.value(<String, Object?>{'ok': true});
      default:
        return handleLxCryptoApi(api, payload);
    }
  }

  /// Waits for lx.send('inited') with a hard deadline, then returns the
  /// announced sources.
  Future<LxScriptInfo> awaitInited({Duration timeout = const Duration(seconds: 15)}) {
    return inited.timeout(
      timeout,
      onTimeout: () => throw TimeoutException('lx script $scriptId never called lx.send("inited")'),
    );
  }

  Future<Map<String, Object?>?> _request(String action, String source, Map<String, Object?> info) async {
    if (_disposed) {
      throw StateError('lx script $scriptId is disposed');
    }
    final payload = jsonEncode(<String, Object?>{
      'data': <String, Object?>{'action': action, 'source': source, 'info': info},
    });
    final outcome = await _sandbox.evaluate(
      SandboxUnit(
        pluginId: scriptId,
        key: 'lx.$action',
        source: 'globalThis.__lx_dispatch_request(${jsonEncode(payload)})',
      ),
    );
    if (!outcome.isClean || outcome.value == null) {
      throw StateError('lx $scriptId $action/$source failed: ${outcome.message ?? 'no answer'}');
    }
    final decoded = jsonDecode(outcome.value!);
    if (decoded is Map && decoded['__error__'] != null) {
      throw StateError('lx $scriptId $action/$source: ${decoded['__error__']}');
    }
    return decoded is Map<String, Object?> ? decoded : null;
  }

  /// The play url for one song. [quality] is the lx vocabulary (128k, 320k,
  /// flac, flac24bit).
  Future<String> musicUrl(String source, String musicId, String quality) async {
    final answer = await _request('musicUrl', source, <String, Object?>{'musicId': musicId, 'type': quality});
    final url = answer?['result'] ?? answer?['url'];
    if (url is! String || url.isEmpty) {
      throw StateError('lx $scriptId musicUrl/$source returned no url');
    }
    return url;
  }

  /// The lyric text for one song, when the source serves it.
  Future<String?> lyric(String source, String musicId) async {
    final answer = await _request('lyric', source, <String, Object?>{'musicId': musicId});
    final lyric = answer?['result'] ?? answer?['lyric'];
    return lyric is String && lyric.isNotEmpty ? lyric : null;
  }

  /// The cover image url for one song, when the source serves it.
  Future<String?> pic(String source, String musicId) async {
    final answer = await _request('pic', source, <String, Object?>{'musicId': musicId});
    final pic = answer?['result'] ?? answer?['pic'];
    return pic is String && pic.isNotEmpty ? pic : null;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _sandbox.dispose();
  }
}
