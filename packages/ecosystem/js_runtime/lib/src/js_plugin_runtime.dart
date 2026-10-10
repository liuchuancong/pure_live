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

  Set<String> _groups = const <String>{};

  /// The capability groups the loaded script registered, cut down to what its manifest declared. Read after
  /// [enable]; empty before. Unmodifiable: this used to hand out the live set, so a caller could add a group the
  /// manifest never declared - or clear the runtime's own state - through a getter.
  Set<String> get registeredGroups => Set<String>.unmodifiable(_groups);

  @override
  PluginRuntimeKind get kind => PluginRuntimeKind.js;

  /// The live sandbox, while the plugin is enabled. Hosts that speak a second
  /// vocabulary over the same script (a music feature reading an lx script,
  /// say) attach their own facade to this sandbox instead of spawning a second
  /// engine - two engines per plugin would double every global the script set.
  FjsJsSandbox? get sandbox => _sandbox;

  @override
  Future<void> load(PluginManifest manifest, HostBridge bridge) async {
    if (_sandbox != null) {
      throw StateError('${manifest.id} is already loaded');
    }
    _manifest = manifest;
    _bridge = bridge;
    final sandbox = FjsJsSandbox(pluginId: manifest.id, policy: policy, bridge: bridge, onLog: onLog);
    try {
      await sandbox.start();
      final outcome = await sandbox.evaluate(SandboxUnit(pluginId: manifest.id, key: 'plugin.source', source: source));
      if (!outcome.isClean) {
        throw StateError('${manifest.id} failed to load: ${outcome.message}');
      }
      _sandbox = sandbox;
    } on Object {
      // A failed load used to leave the manifest and bridge behind with no sandbox, so the runtime reported
      // "not enabled" while still holding the identity and the host handle of a plugin that had never started -
      // and the half-built engine leaked. Nothing survives a load that did not happen.
      await sandbox.dispose();
      _manifest = null;
      _bridge = null;
      _groups = const <String>{};
      rethrow;
    }
  }

  @override
  Future<void> enable() async {
    final sandbox = _requireServing();
    final described = await sandbox.describeRegistrations();
    if (!described.isClean || described.value == null) {
      throw StateError('${_manifest!.id} did not describe its registrations: ${described.message}');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(described.value!);
    } on FormatException catch (error) {
      throw StateError('${_manifest!.id} described itself in text that is not JSON: ${error.message}');
    }
    // A script that describes itself as an object, a number or a list of strings is a broken plugin, not a
    // host crash: the message says what arrived, and one odd registration must not lose the ones that are fine.
    final served = <String>{};
    for (final description in decoded is List ? decoded : const <Object?>[]) {
      final entry = _asObjectMap(description);
      if (entry == null) {
        continue;
      }
      final declared = _asObjectMap(entry['manifest']) ?? const <String, Object?>{};
      final carried = _asList(entry['capabilityNames']).map((name) => '$name').toSet();
      // The declared manifest wins over what the object happens to carry: a
      // script exposing more groups than it declared is exactly the drift the
      // manifest review is supposed to catch, so it is cut here.
      served.addAll(carried.intersection(_declaredGroups(declared)));
    }
    if (decoded is! List) {
      throw StateError('${_manifest!.id} described itself as ${decoded.runtimeType}, not a list of registrations');
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
  ///
  /// The check is on a named failure type, not on the wording of an exception message: the prelude answers an
  /// unimplemented method with a marker object precisely so this decision does not depend on text.
  Future<Map<String, Object?>?> _dispatchOrNull(String group, String method) async {
    try {
      return await _dispatch(group, method, const <String, Object?>{});
    } on NoRegistration {
      return null;
    }
  }

  Future<Map<String, Object?>> _dispatch(String group, String method, Map<String, Object?> args) async {
    final sandbox = _requireServing();
    final outcome = await sandbox.dispatch(group, method, args);
    if (!outcome.isClean || outcome.value == null) {
      throw StateError('$group.$method failed: ${outcome.message ?? 'no answer'}');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(outcome.value!);
    } on FormatException {
      throw StateError('$group.$method answered with text that is not JSON');
    }
    final map = _asObjectMap(decoded);
    if (map != null && map['__noRegistration__'] is String) {
      throw NoRegistration('${map['__noRegistration__']} is not implemented by ${_manifest?.id ?? 'this plugin'}');
    }
    return map ?? <String, Object?>{'result': decoded};
  }
}

/// A capability method no registration of this plugin implements.
///
/// Its own type because the runtime has to tell this apart from a failure: an optional method that is simply
/// absent is a shape of the plugin, and a call that failed is an error the user should hear about.
final class NoRegistration implements Exception {
  const NoRegistration(this.message);

  final String message;

  @override
  String toString() => 'NoRegistration($message)';
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

/// A list field the plugin may have answered with anything. Not a list is zero rows, never a crash.
List<Object?> _asList(Object? value) => value is List ? value : const <Object?>[];

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
    final rows = _asList(answer['result'] ?? answer['items']);
    return <ContentCategory>[
      for (final row in rows)
        if (_asObjectMap(row) case final Map<String, Object?> category)
          if (_categoryFrom(category) case final ContentCategory parsed) parsed,
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
    return _ticketFrom(answer, 'live', 'resolve');
  }

  @override
  Future<MediaTicket> refresh(MediaTicket expired, RefreshReason reason) async {
    final answer = await _runtime._dispatch('live', 'refresh', <String, Object?>{
      'ticket': expired.toJson(),
      'reason': reason.name,
    });
    return _ticketFrom(answer, 'live', 'refresh');
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
  // One malformed row is a row, not a page: `_asObjectMap(row)!` used to throw on whatever the script answered
  // differently (a string in the list, a summary missing its ref), and the whole page was lost with it - which
  // to the user reads as an empty result rather than a partial one.
  final rows = answer['items'] is List ? answer['items']! as List : const <Object?>[];
  final items = <ContentSummary>[
    for (final row in rows)
      if (_asObjectMap(row) case final Map<String, Object?> summary)
        if (_summaryFrom(summary) case final ContentSummary summaryRow) summaryRow,
  ];
  final declaredPageSize = (answer['pageSize'] as num?)?.toInt();
  return PageResult<ContentSummary>(
    items: items,
    page: (answer['page'] as num?)?.toInt() ?? 1,
    pageSize: declaredPageSize ?? items.length,
    hasMore: answer['hasMore'] as bool? ?? false,
    mode: PageMode.values.where((mode) => mode.name == answer['mode']).firstOrNull ?? PageMode.fixedPage,
    nextCursor: answer['nextCursor'] is String ? answer['nextCursor']! as String : null,
  );
}

/// Rebuilds one row, or null when the script did not give enough to name the content.
ContentSummary? _summaryFrom(Map<String, Object?> row) {
  final ref = _asObjectMap(row['ref']);
  if (ref == null) {
    return null;
  }
  try {
    return ContentSummary.fromJson(row);
  } on Object {
    // A row whose own fields are the wrong shape is dropped for the same reason: the list is still useful.
    return null;
  }
}

/// One category row, or null when the plugin did not name it. Dropped rather than fatal: the category browser
/// is more useful with the rows that came through than with an error page replacing all of them.
ContentCategory? _categoryFrom(Map<String, Object?> row) {
  if (row['id'] is! String || (row['id']! as String).isEmpty) {
    return null;
  }
  try {
    return ContentCategory.fromJson(row);
  } on Object {
    return null;
  }
}

/// A ticket a plugin answered with, or a named failure. `MediaTicket.fromJson` throws on a missing uri, and the
/// script is not the caller - a plugin that answers garbage must fail as "this plugin answered garbage", with
/// the group and method in the message the user's diagnostics will show.
MediaTicket _ticketFrom(Map<String, Object?> answer, String group, String method) {
  final ticket = _asObjectMap(answer['ticket']) ?? answer;
  try {
    return MediaTicket.fromJson(ticket);
  } on Object catch (error) {
    throw StateError('$group.$method answered with a ticket that cannot be read: $error');
  }
}
