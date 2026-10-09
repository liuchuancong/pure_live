// Module: lib/src/js_drpy_spider_handle.dart
// Purpose: Runs drpy-shaped JS spiders (ES modules exporting __jsEvalReturn or
// a default object) through the fjs sandbox and answers SpiderHandle.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/plugin/js-plugin.md and docs/adr/0017. The module shape and the
// req surface follow the webtv quickjs host (quickjs/src/main/assets/js/lib):
// `req(url, options)` returns a requests-like answer with text/status_code,
// and the spider object comes from `__jsEvalReturn()` or the default export.
// The bundled cheerio/cat libraries are deliberately NOT vendored here - a
// spider that needs them fails naming the missing global, and bringing those
// libraries in is a reviewed vendoring decision, not a silent copy.

import 'dart:convert';

import 'package:pure_live_js_runtime/pure_live_js_runtime.dart';
import 'package:pure_live_plugin_api/pure_live_plugin_api.dart';

import 'spider_contract.dart';

/// Injected before the spider module: a requests-shaped `req`/`http` over the
/// sandbox bridge, so every request crosses PluginNetwork's permission check.
/// Result fields alias what spiders expect (text/content/body, status_code).
const String jsDrpyShim = r'''
var __plRequest = async function (method, url, options) {
  options = options || {};
  var reply = await fjs.bridge_call({
    api: 'http',
    payload: {
      method: method,
      url: String(url),
      headers: options.headers || {},
      timeoutMs: options.timeout || 15000,
    },
  });
  if (reply && reply.error) {
    throw new Error(String(reply.error));
  }
  var r = (reply && reply.result) || {};
  var text = r.bodyText || '';
  var answer = { text: text, content: text, body: text, status_code: r.statusCode || 0, headers: r.headers || {} };
  answer.json = function () { return JSON.parse(text); };
  return answer;
};
var req = function (url, options) { return __plRequest('GET', url, options); };
req.post = function (url, options) { return __plRequest('POST', url, options); };
var http = req;
globalThis.req = req;
globalThis.http = req;
''';

/// The module wrapper: imports the spider, resolves its export shape and
/// pins the object on globalThis where later script dispatch finds it.
const String jsDrpyWrapperModule = '''
import * as spider from '__drpy_spider__';
var target = null;
if (spider.__jsEvalReturn) {
  target = spider.__jsEvalReturn();
} else if (spider.default) {
  target = typeof spider.default === 'function' ? spider.default() : spider.default;
}
if (!target) {
  throw new Error('drpy module exposes neither __jsEvalReturn nor a default export');
}
globalThis.__JS_SPIDER__ = target;
''';

/// Methods the drpy contract expects on the spider object.
const Set<String> jsDrpyRequiredMethods = <String>{
  'init',
  'home',
  'categoryContent',
  'detailContent',
  'searchContent',
  'playerContent',
};

/// Heuristic on the source: drpy modules import/export or name the eval
/// return; the plain-contract shape defines bare global functions.
bool looksLikeDrpyModule(String source) {
  return source.contains('__jsEvalReturn') || RegExp(r'^\s*(import|export)\b', multiLine: true).hasMatch(source);
}

/// One drpy spider in one sandbox.
final class JsDrpySpiderHandle implements SpiderHandle {
  JsDrpySpiderHandle._({required this.key, required FjsJsSandbox sandbox}) : _sandbox = sandbox;

  final String key;
  final FjsJsSandbox _sandbox;
  bool _initialized = false;

  /// Loads the module, resolves its export shape and asserts the method set.
  static Future<JsDrpySpiderHandle> spawn({
    required String key,
    required String source,
    required HostBridge bridge,
    SandboxPolicy policy = const SandboxPolicy(),
  }) async {
    final sandbox = FjsJsSandbox(pluginId: key, policy: policy, bridge: bridge);
    await sandbox.start();
    Future<void> eval(String code) async {
      final outcome = await sandbox.evaluate(SandboxUnit(pluginId: key, key: 'drpy.load', source: code));
      if (!outcome.isClean) {
        await sandbox.dispose();
        throw StateError('drpy spider $key failed to load: ${outcome.message}');
      }
    }

    await eval(jsDrpyShim);
    final module = await sandbox.evaluateModuleSource('__drpy_spider__', source);
    if (!module.isClean) {
      await sandbox.dispose();
      throw StateError('drpy spider $key module failed: ${module.message}');
    }
    final wrapper = await sandbox.evaluateModuleSource('__drpy_wrapper__', jsDrpyWrapperModule);
    if (!wrapper.isClean) {
      await sandbox.dispose();
      throw StateError('drpy spider $key wrapper failed: ${wrapper.message}');
    }
    final surface = await sandbox.evaluate(
      SandboxUnit(
        pluginId: key,
        key: 'drpy.surface',
        source: 'JSON.stringify(Object.keys(globalThis.__JS_SPIDER__ || {}).filter(function (name) { return typeof globalThis.__JS_SPIDER__[name] === "function"; }))',
      ),
    );
    if (!surface.isClean || surface.value == null) {
      await sandbox.dispose();
      throw StateError('drpy spider $key surface check failed: ${surface.message}');
    }
    final defined = (jsonDecode(surface.value!) as List).map((name) => '$name').toSet();
    final missing = jsDrpyRequiredMethods.difference(defined);
    if (missing.isNotEmpty) {
      await sandbox.dispose();
      throw StateError('drpy spider $key is missing: ${missing.join(', ')}');
    }
    return JsDrpySpiderHandle._(key: key, sandbox: sandbox);
  }

  Future<Map<String, Object?>?> _call(String method, List<Object?> args) async {
    // init folds into the first call, mirroring the python host's behaviour:
    // spiders do their setup there and callers never sequence it explicitly.
    if (!_initialized) {
      final boot = await _sandbox.evaluate(
        const SandboxUnit(
          pluginId: 'drpy',
          key: 'drpy.init',
          source: 'JSON.stringify(await globalThis.__JS_SPIDER__.init(""))',
        ),
      );
      _initialized = true;
      if (!boot.isClean) {
        throw StateError('drpy $key init failed: ${boot.message}');
      }
    }
    final invocation = StringBuffer('JSON.stringify(await globalThis.__JS_SPIDER__.$method(');
    invocation.write(args.map(jsonEncode).join(', '));
    invocation.write('))');
    final outcome = await _sandbox.evaluate(
      SandboxUnit(pluginId: key, key: 'drpy.$method', source: invocation.toString()),
    );
    if (!outcome.isClean) {
      throw StateError('drpy $key.$method failed: ${outcome.message}');
    }
    if (outcome.value == null || outcome.value == 'undefined' || outcome.value!.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(outcome.value!);
    return decoded is Map<String, Object?> ? decoded : <String, Object?>{'result': decoded};
  }

  @override
  Future<Map<String, Object?>?> init(String extend) async {
    final answer = await _call('init', <Object?>[extend]);
    _initialized = true;
    return answer;
  }

  @override
  Future<Map<String, Object?>?> homeContent(Map<String, Object?> filter) {
    return _call('home', <Object?>[filter['filter'] ?? '']);
  }

  @override
  Future<Map<String, Object?>?> homeVideoContent() async {
    // The drpy home answer already carries the vod list; a separate featured
    // call does not exist in the shape.
    return null;
  }

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
