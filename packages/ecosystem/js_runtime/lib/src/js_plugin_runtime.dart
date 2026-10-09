// Module: lib/src/js_plugin_runtime.dart
// Purpose: The plugin host for one JS plugin: loads its script, reads its
// registrations and exposes its capability groups as contract objects.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/plugin/js-plugin.md section 3. The runtime receives the plugin's
// source through its constructor because the code lives on disk (or in a
// repository), owned by the installer, not inside the manifest - a manifest
// that could carry code would let a plugin rewrite itself after review.

import 'dart:convert';

import 'package:pure_live_capability/pure_live_capability.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_plugin_api/pure_live_plugin_api.dart';

import 'fjs_sandbox.dart';

/// Hosts one JS plugin. Lifecycle calls come from the host's lifecycle machine;
/// the runtime refuses to serve capability calls outside `enabled` because a
/// disabled plugin answering requests would make the registry's answer a lie.
final class JsPluginRuntime implements PluginRuntime {
  JsPluginRuntime({required this.source, this.policy = const SandboxPolicy(), this.onLog});

  /// The plugin's script, exactly as installed.
  final String source;
  final SandboxPolicy policy;
  final void Function(String pluginId, String level, String message)? onLog;

  FjsJsSandbox? _sandbox;
  HostBridge? _bridge;
  PluginManifest? _manifest;

  /// The capability group names the enabled script serves, cut down to what
  /// its manifest declared.
  Set<String> _groups = const <String>{};

  @override
  PluginRuntimeKind get kind => PluginRuntimeKind.js;

  /// The capability groups the loaded script registered. Read after [enable];
  /// empty before.
  Set<String> get registeredGroups => _groups;

  @override
  Future<void> load(PluginManifest manifest, HostBridge bridge) async {
    if (_sandbox != null) {
      throw StateError('${manifest.id} is already loaded');
    }
    _manifest = manifest;
    _bridge = bridge;
    final sandbox = FjsJsSandbox(pluginId: manifest.id, policy: policy, bridge: bridge, onLog: onLog);
    await sandbox.start();
    final outcome = await sandbox.evaluate(SandboxUnit(pluginId: manifest.id, key: 'plugin.source', source: source));
    if (!outcome.isClean) {
      await sandbox.dispose();
      throw StateError('${manifest.id} failed to load: ${outcome.message}');
    }
    _sandbox = sandbox;
  }

  @override
  Future<void> enable() async {
    final sandbox = _requireServing();
    final described = await sandbox.describeRegistrations();
    if (!described.isClean || described.value == null) {
      throw StateError('${_manifest!.id} did not describe its registrations: ${described.message}');
    }
    final descriptions = (jsonDecode(described.value!) as List).cast<Map<String, Object?>>();
    final served = <String>{};
    for (final description in descriptions) {
      final declared = _asObjectMap(description['manifest']) ?? const <String, Object?>{};
      final carried = ((description['capabilityNames'] as List?) ?? const []).map((name) => '$name').toSet();
      // The declared manifest wins over what the object happens to carry: a
      // script exposing more groups than it declared is exactly the drift the
      // manifest review is supposed to catch, so it is cut here.
      served.addAll(carried.intersection(_declaredGroups(declared)));
    }
    _groups = served;
  }

  Set<String> _declaredGroups(Map<String, Object?> declaredManifest) {
    final names = declaredManifest['capabilities'];
    if (names is! List) {
      return const <String>{};
    }
    return names.map((name) => '$name').toSet();
  }

  @override
  Future<void> disable() async {
    final sandbox = _sandbox;
    _groups.clear();
    _sandbox = null;
    await sandbox?.dispose();
  }

  @override
  Future<void> unload() async {
    await disable();
    _bridge = null;
    _manifest = null;
  }

  FjsJsSandbox _requireServing() {
    final sandbox = _sandbox;
    if (sandbox == null || _bridge == null) {
      throw StateError('${_manifest?.id ?? 'plugin'} is not enabled');
    }
    return sandbox;
  }

  /// The browse/detail group, when the plugin registered one. Dispatches over
  /// the JSON boundary and reassembles the platform models.
  JsLiveAdapter? liveAdapter() => _groups.contains('live') ? JsLiveAdapter(runtime: this) : null;

  /// The search group, when the plugin registered one.
  JsSearchAdapter? searchAdapter() => _groups.contains('search') ? JsSearchAdapter(runtime: this) : null;

  /// Dispatch that treats "no registration implements this" as null instead
  /// of an error - the distinction optional methods need.
  Future<Map<String, Object?>?> _dispatchOrNull(String group, String method) async {
    try {
      return await _dispatch(group, method, const <String, Object?>{});
    } on StateError catch (error) {
      if ('${error}'.contains('no registration implements')) {
        return null;
      }
      rethrow;
    }
  }

  Future<Map<String, Object?>> _dispatch(String group, String method, Map<String, Object?> args) async {
    final sandbox = _requireServing();
    final outcome = await sandbox.dispatch(group, method, args);
    if (!outcome.isClean || outcome.value == null) {
      throw StateError('$group.$method failed: ${outcome.message ?? 'no answer'}');
    }
    final decoded = jsonDecode(outcome.value!);
    return decoded is Map<String, Object?> ? decoded : <String, Object?>{'result': decoded};
  }
}

/// The live/vod group of a JS plugin, as the capability contract sees it.
/// The platform models keep their JSON helpers internal, so the boundary code
/// here carries its own narrow version.
Map<String, Object?>? _asObjectMap(Object? value) {
  if (value is! Map) {
    return null;
  }
  return Map<String, Object?>.fromEntries(value.entries.map((entry) => MapEntry('${entry.key}', entry.value)));
}

final class JsLiveAdapter implements BrowseCapability, ResolveCapability {
  JsLiveAdapter({required JsPluginRuntime runtime}) : _runtime = runtime;

  final JsPluginRuntime _runtime;

  @override
  Future<List<ContentCategory>> categories() async {
    // categories is optional in the JS surface: a plugin without it has no
    // category UI, which is a shape, not a failure.
    final answer = await _runtime._dispatchOrNull('live', 'categories');
    if (answer == null) {
      return const <ContentCategory>[];
    }
    final rows = (answer['result'] as List?) ?? (answer['items'] as List?) ?? const [];
    return <ContentCategory>[
      for (final row in rows)
        if (_asObjectMap(row) != null) ContentCategory.fromJson(_asObjectMap(row)!),
    ];
  }

  @override
  Future<PageResult<ContentSummary>> browse(ContentQuery query) async {
    final answer = await _runtime._dispatch('live', 'browse', <String, Object?>{'query': query.toJson()});
    return _pageFrom(answer);
  }

  @override
  Future<ContentDetail> detail(ContentRef ref) async {
    final answer = await _runtime._dispatch('live', 'detail', <String, Object?>{'ref': ref.toJson()});
    final summary = _asObjectMap(answer['summary']);
    if (summary == null) {
      throw StateError('live.detail returned no summary');
    }
    return ContentDetail(summary: ContentSummary.fromJson(summary), description: answer['description']?.toString());
  }

  @override
  Future<MediaTicket> resolve(ContentRef ref, {SelectionRef? quality, SelectionRef? line}) async {
    final answer = await _runtime._dispatch('live', 'resolve', <String, Object?>{
      'ref': ref.toJson(),
      if (quality != null) 'quality': quality.toJson(),
      if (line != null) 'line': line.toJson(),
    });
    final ticket = _asObjectMap(answer['ticket']) ?? answer;
    return MediaTicket.fromJson(ticket);
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final answer = await _runtime._dispatch('live', 'refresh', <String, Object?>{
      'ticket': expired.toJson(),
      'reason': reason.name,
    });
    final ticket = _asObjectMap(answer['ticket']) ?? answer;
    return MediaTicket.fromJson(ticket);
  }
}

/// The search group of a JS plugin.
final class JsSearchAdapter implements SearchCapability {
  JsSearchAdapter({required JsPluginRuntime runtime}) : _runtime = runtime;

  final JsPluginRuntime _runtime;

  @override
  Future<PageResult<ContentSummary>> search(SearchQuery query) async {
    final answer = await _runtime._dispatch('search', 'search', <String, Object?>{'query': query.toJson()});
    return _pageFrom(answer);
  }
}

/// Rebuilds one page from the JSON a plugin answered with. Missing paging
/// fields are treated as "one full page, no more", which is the honest reading
/// of a script that did not say.
PageResult<ContentSummary> _pageFrom(Map<String, Object?> answer) {
  final rows = (answer['items'] as List?) ?? const [];
  final items = <ContentSummary>[for (final row in rows) ContentSummary.fromJson(_asObjectMap(row)!)];
  return PageResult<ContentSummary>(
    items: items,
    page: (answer['page'] as num?)?.toInt() ?? 1,
    pageSize: (answer['pageSize'] as num?)?.toInt() ?? items.length,
    hasMore: answer['hasMore'] as bool? ?? false,
    mode: PageMode.values.where((mode) => mode.name == answer['mode']).firstOrNull ?? PageMode.fixedPage,
    nextCursor: answer['nextCursor'] as String?,
  );
}
