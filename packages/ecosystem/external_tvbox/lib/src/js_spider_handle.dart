// Module: lib/src/js_spider_handle.dart
// Purpose: Runs a JS spider through the fjs sandbox and answers SpiderHandle.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/plugin/js-plugin.md and docs/adr/0017. The JS spider contract is
// the same method set as the Python one - a script defines
// init/homeContent/categoryContent/detailContent/searchContent/playerContent/
// liveContent as global functions and answers JSON-able objects. The loader
// wraps those globals into the sandbox's registration machinery, so the spider
// itself is plain top-level functions. Third-party shim layers (drpy-style
// globals like req) are a compatibility module for the plugin-details phase;
// a spider written against the plain contract works today with zero shim.

import 'dart:convert';

import 'package:pure_live_js_runtime/pure_live_js_runtime.dart';
import 'package:pure_live_plugin_api/pure_live_plugin_api.dart';

import 'spider_contract.dart';

/// Wraps the spider's global functions into a registration the sandbox can
/// dispatch to. Args travel as one object; each wrapper unpacks them into the
/// positional call the contract defines.
const String jsSpiderWrapper = '''
PureLive.registerPlugin({
  spider: {
    init: function (args) { return init(args && args.extend ? args.extend : ''); },
    homeContent: function (args) { return homeContent(args && args.filter ? args.filter : {}); },
    homeVideoContent: function () { return homeVideoContent(); },
    categoryContent: function (args) {
      var a = args.args;
      return categoryContent(String(a[0]), String(a[1]), a[2] === true, a[3] || {});
    },
    detailContent: function (args) { return detailContent(args.args[0]); },
    searchContent: function (args) {
      var a = args.args;
      return searchContent(String(a[0]), a[1] === true, String(a[2]));
    },
    playerContent: function (args) {
      var a = args.args;
      return playerContent(String(a[0]), String(a[1]), a[2] === true);
    },
    liveContent: function (args) { return liveContent(args.args[0]); },
  },
});
''';

/// Methods the contract expects, asserted when the script loads so a
/// half-written spider is refused up front instead of at first browse.
const Set<String> jsSpiderRequiredMethods = <String>{
  'init',
  'homeContent',
  'categoryContent',
  'detailContent',
  'searchContent',
  'playerContent',
};

/// One JS spider in one sandbox.
final class JsSpiderHandle implements SpiderHandle {
  JsSpiderHandle._({required this.key, required FjsJsSandbox sandbox}) : _sandbox = sandbox;

  /// Evaluates the script in a fresh sandbox, asserts its surface and wraps it.
  static Future<JsSpiderHandle> spawn({
    required String key,
    required String source,
    required HostBridge bridge,
    SandboxPolicy policy = const SandboxPolicy(),
  }) async {
    final sandbox = FjsJsSandbox(pluginId: key, policy: policy, bridge: bridge);
    await sandbox.start();
    Future<void> eval(String code) async {
      final outcome = await sandbox.evaluate(SandboxUnit(pluginId: key, key: 'spider.source', source: code));
      if (!outcome.isClean) {
        await sandbox.dispose();
        throw StateError('js spider $key failed to load: ${outcome.message}');
      }
    }

    await eval(source);
    await eval(jsSpiderWrapper);
    final surface = await sandbox.evaluate(
      SandboxUnit(
        pluginId: key,
        key: 'spider.surface',
        source: 'JSON.stringify(Object.keys(globalThis).filter(function (name) { return typeof globalThis[name] === "function"; }))',
      ),
    );
    if (!surface.isClean || surface.value == null) {
      await sandbox.dispose();
      throw StateError('js spider $key surface check failed: ${surface.message}');
    }
    final defined = (jsonDecode(surface.value!) as List).map((name) => '$name').toSet();
    final missing = jsSpiderRequiredMethods.difference(defined);
    if (missing.isNotEmpty) {
      await sandbox.dispose();
      throw StateError('js spider $key is missing: ${missing.join(', ')}');
    }
    return JsSpiderHandle._(key: key, sandbox: sandbox);
  }

  /// The site key; the sandbox's plugin id and log prefix.
  final String key;
  final FjsJsSandbox _sandbox;
  bool _initialized = false;

  Future<Map<String, Object?>?> _call(String method, List<Object?> args, {Object? named}) async {
    if (!_initialized) {
      final boot = await _sandbox.dispatch('spider', 'init', <String, Object?>{'extend': ''});
      if (!boot.isClean) {
        throw StateError('js spider $key init failed: ${boot.message}');
      }
      _initialized = true;
    }
    final payload = <String, Object?>{if (named != null) ...named as Map<String, Object?>, 'args': args};
    final outcome = await _sandbox.dispatch('spider', method, payload);
    if (!outcome.isClean || outcome.value == null) {
      throw StateError('js spider $key.$method failed: ${outcome.message ?? 'no answer'}');
    }
    final decoded = jsonDecode(outcome.value!);
    return decoded is Map<String, Object?> ? decoded : <String, Object?>{'result': decoded};
  }

  @override
  Future<Map<String, Object?>?> init(String extend) async {
    final outcome = await _sandbox.dispatch('spider', 'init', <String, Object?>{'extend': extend});
    if (!outcome.isClean) {
      throw StateError('js spider $key init failed: ${outcome.message}');
    }
    _initialized = true;
    return null;
  }

  @override
  Future<Map<String, Object?>?> homeContent(Map<String, Object?> filter) =>
      _call('homeContent', const <Object?>[], named: <String, Object?>{'filter': filter});

  @override
  Future<Map<String, Object?>?> homeVideoContent() => _call('homeVideoContent', const <Object?>[]);

  @override
  Future<Map<String, Object?>?> categoryContent(String tid, String pg, bool filter, Map<String, Object?> extend) =>
      _call('categoryContent', <Object?>[tid, pg, filter, extend]);

  @override
  Future<Map<String, Object?>?> detailContent(List<String> ids) => _call('detailContent', <Object?>[ids]);

  @override
  Future<Map<String, Object?>?> searchContent(String key, bool quick, String pg) =>
      _call('searchContent', <Object?>[key, quick, pg]);

  @override
  Future<Map<String, Object?>?> playerContent(String flag, String id, bool vipFlags) =>
      _call('playerContent', <Object?>[flag, id, vipFlags]);

  @override
  Future<Map<String, Object?>?> liveContent(String url) => _call('liveContent', <Object?>[url]);

  @override
  Future<void> destroy() async {
    await _sandbox.dispose();
  }
}
