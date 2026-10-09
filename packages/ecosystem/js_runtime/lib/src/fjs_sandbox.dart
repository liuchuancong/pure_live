// Module: lib/src/fjs_sandbox.dart
// Purpose: One fjs engine per plugin, speaking the plugin_api sandbox contract over a JSON bridge.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/plugin/js-plugin.md sections 2 and 4. The engine is created with console and timers only: no
// built-in fetch (requests must cross the host's PluginNetwork), no filesystem. Timeout is enforced host-side
// by racing the evaluation; the engine itself is not interrupted, so a timed-out script keeps occupying its
// own engine until dispose - that is the degraded state the lifecycle budget then acts on.

import 'dart:async';
import 'dart:convert';

import 'package:fjs/fjs.dart' as fjs;
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_plugin_api/pure_live_plugin_api.dart';

import 'js_prelude.dart';

/// One plugin's interpreter. The host (the composition root, through
/// [JsPluginRuntime]) creates it: a plugin never chooses its own isolation
/// level, and it never sees this type.
final class FjsJsSandbox implements ScriptSandbox {
  FjsJsSandbox({
    required this.pluginId,
    required this.policy,
    required HostBridge bridge,
    void Function(String pluginId, String level, String message)? onLog,
  }) : _bridge = bridge,
       _onLog = onLog;

  /// Shared engine-library start-up. Idempotent; fjs requires it once per process.
  static Future<void> ensureLibraryInitialized() async {
    if (!_libraryReady) {
      await fjs.LibFjs.init();
      _libraryReady = true;
    }
  }

  static bool _libraryReady = false;

  /// Not part of the sandbox contract; the field exists so log lines can name
  /// the plugin they came from.
  final ExtensionId pluginId;
  @override
  final SandboxPolicy policy;

  final HostBridge _bridge;
  final void Function(String pluginId, String level, String message)? _onLog;

  fjs.JsEngine? _engine;
  bool _disposed = false;

  /// Hook for hosts that extend the bridge with their own api names. Consulted
  /// when [api] matches none of the built-in ports; returning null surfaces
  /// the unknown-api error. This is how the lx-music host adds its crypto and
  /// zlib endpoints without coupling this package to them.
  Future<Object?>? Function(String api, Map<String, Object?> payload)? extendedApiHandler;

  /// Brings the engine up and installs the host prelude. Split from the
  /// constructor because engine creation is asynchronous and fallible.
  Future<void> start() async {
    if (_engine != null) {
      return;
    }
    await ensureLibraryInitialized();
    final engine = await fjs.JsEngine.create(
      // console for the plugin's own debugging, timers for async protocols.
      // fetch is deliberately absent: a request that skips PluginNetwork also
      // skips the permission ceiling, which is the one thing the sandbox exists
      // to prevent.
      builtins: fjs.JsBuiltinOptions(console: true, timers: true),
    );
    await engine.init(bridge: _handleBridgeCall);
    await engine.eval(source: fjs.JsCode.code(jsHostPrelude));
    _engine = engine;
  }

  /// The one host entry a script can reach: `fjs.bridge_call({api, payload})`.
  /// Every api name maps to a port on the bridge; anything else is refused
  /// here, so a script cannot grow a side channel by inventing api names.
  Future<fjs.JsResult> _handleBridgeCall(fjs.JsValue value) async {
    try {
      final data = value.value;
      final request = data is Map ? data : const <Object?, Object?>{};
      final api = '${request['api']}';
      final payload = request['payload'];
      final result = await _dispatchApi(api, payload);
      return fjs.JsResult.ok(fjs.JsValue.from(<String, Object?>{'result': result}));
    } catch (error) {
      // Script-facing errors stay short: a stack trace from the host would
      // leak host internals into plugin-visible text.
      return fjs.JsResult.ok(fjs.JsValue.from(<String, Object?>{'error': '$error'}));
    }
  }

  Future<Object?> _dispatchApi(String api, Object? payload) async {
    final options = payload is Map ? payload : const <Object?, Object?>{};
    switch (api) {
      case 'http':
        return _http(options);
      case 'kv.get':
        return _bridge.kv.read('${options['key']}');
      case 'kv.set':
        await _bridge.kv.write('${options['key']}', options['value']);
        return null;
      case 'kv.remove':
        await _bridge.kv.remove('${options['key']}');
        return null;
      case 'kv.keys':
        return _bridge.kv.keys();
      case 'log':
        final level = '${options['level']}';
        final message = '${options['message']}';
        _bridge.events.publish('plugin.log', payload: <String, Object?>{'level': level, 'message': message});
        _onLog?.call(pluginId, level, message);
        return null;
      case 'manifest':
        return _bridge.manifest.toJson();
      default:
        final handler = extendedApiHandler;
        if (handler != null) {
          return handler(api, Map<String, Object?>.from(options));
        }
        throw StateError('unknown host api: $api');
    }
  }

  /// PluginNetwork in plugin-sized JSON: text bodies only, because a script has
  /// no use for bytes it cannot decode and binary passthrough would make the
  /// size accounting invisible.
  Future<Map<String, Object?>> _http(Map<Object?, Object?> options) async {
    final request = NetworkRequest(
      method: '${options['method'] ?? 'GET'}',
      uri: Uri.parse('${options['url']}'),
      headers: _stringMap(options['headers']),
      timeout: options['timeoutMs'] is num ? Duration(milliseconds: (options['timeoutMs']! as num).toInt()) : null,
    );
    final response = await _bridge.network.send(request);
    return <String, Object?>{
      'statusCode': response.statusCode,
      'headers': response.headers,
      'finalUri': response.finalUri.toString(),
      'bodyText': utf8.decode(response.body, allowMalformed: true),
    };
  }

  Map<String, String> _stringMap(Object? value) {
    if (value is! Map) {
      return const <String, String>{};
    }
    return Map<String, String>.fromEntries(value.entries.map((entry) => MapEntry('${entry.key}', '${entry.value}')));
  }

  /// Evaluates one unit of plugin script under the policy timeout.
  @override
  Future<SandboxOutcome> evaluate(SandboxUnit unit) => _evaluateCode(unit.source);

  /// Registers and evaluates one ES module in this sandbox. Module code may
  /// use import/export; imports resolve against modules already registered in
  /// this engine. Assigning to `globalThis` inside the module is how its
  /// surface becomes reachable from later script evaluations.
  Future<SandboxOutcome> evaluateModuleSource(String moduleName, String source) async {
    final engine = _engine;
    if (_disposed || engine == null) {
      return SandboxOutcome(failure: SandboxFailure.crashed, elapsed: Duration.zero, message: 'sandbox is closed');
    }
    final watch = Stopwatch()..start();
    try {
      await engine.evaluateModule(
        module: fjs.JsModule.code(module: moduleName, code: source),
      );
      return SandboxOutcome(failure: SandboxFailure.none, elapsed: watch.elapsed);
    } catch (error) {
      return SandboxOutcome(failure: SandboxFailure.threw, elapsed: watch.elapsed, message: '$error');
    }
  }

  /// Calls a capability method on the plugin's registration and returns the
  /// JSON string it answered with. This is the runtime's real entry; `evaluate`
  /// covers the load-time script itself.
  Future<SandboxOutcome> dispatch(String capability, String method, Map<String, Object?> args) {
    final arguments = jsonEncode(args);
    return _evaluateCode(
      '$jsGlobalName.dispatch(${jsonEncode(capability)}, ${jsonEncode(method)}, ${jsonEncode(arguments)})',
      usePromise: true,
    );
  }

  /// Reads what the plugin's script registered, as JSON: manifests plus the
  /// capability group names each registration carries.
  Future<SandboxOutcome> describeRegistrations() {
    return _evaluateCode('$jsGlobalName.describes()', usePromise: true);
  }

  Future<SandboxOutcome> _evaluateCode(String code, {bool usePromise = false}) async {
    final engine = _engine;
    if (_disposed || engine == null) {
      return SandboxOutcome(failure: SandboxFailure.crashed, elapsed: Duration.zero, message: 'sandbox is closed');
    }
    final watch = Stopwatch()..start();
    try {
      final evaluation = engine.eval(
        source: fjs.JsCode.code(code),
        options: usePromise ? fjs.JsEvalOptions.withPromise() : null,
      );
      final answer = await evaluation.timeout(
        policy.limits.timeout,
        onTimeout: () => throw TimeoutException('script exceeded ${policy.limits.timeout}'),
      );
      final value = answer.value;
      final text = value == null ? null : (value is String ? value : value.toString());
      if (text != null && text.length > policy.limits.maxOutputBytes) {
        return SandboxOutcome(
          failure: SandboxFailure.outputTooLarge,
          elapsed: watch.elapsed,
          message: 'output ${text.length} bytes exceeds the limit',
        );
      }
      return SandboxOutcome(failure: SandboxFailure.none, elapsed: watch.elapsed, value: text);
    } on TimeoutException catch (error) {
      return SandboxOutcome(failure: SandboxFailure.timedOut, elapsed: watch.elapsed, message: '${error.message}');
    } catch (error) {
      return SandboxOutcome(failure: SandboxFailure.threw, elapsed: watch.elapsed, message: '$error');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _engine?.close();
    _engine = null;
  }
}
