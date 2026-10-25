import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:desktop_multi_window/desktop_multi_window.dart' show WindowController, onWindowsChanged;
import 'package:flutter/services.dart' show MethodCall;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_storage/live_storage.dart'
    show RemoteChangeOutcome, RemoteStorageClient, StorageChange, StorageSnapshot, StorageStores;

import 'package:pure_live/app/logging/app_log.dart' show appLog;
import 'package:pure_live/app/providers/settings_refresh.dart' show refreshSettings;
import 'package:pure_live/app/providers/window_media_session.dart'
    show WindowMediaMethods, WindowMediaSessionHub, windowMediaReporterProvider;
import 'package:pure_live/app/providers/window_providers.dart'
    show isPrimaryWindowProvider, secondaryWindowsProvider, windowCloseProvider;
import 'package:pure_live/app/routing/app_router.dart' show appRouterProvider;

/// The method names the generic store bridge speaks over
/// `desktop_multi_window`.
abstract final class WindowStorageMethods {
  /// Clone → primary: the entries currently in a namespace.
  static const String snapshot = 'storage.snapshot';

  /// Clone → primary: write one document.
  static const String put = 'storage.put';

  /// Clone → primary: write a batch.
  static const String putAll = 'storage.putAll';

  /// Clone → primary: delete one document.
  static const String delete = 'storage.delete';

  /// Clone → primary: delete a batch.
  static const String deleteAll = 'storage.deleteAll';

  /// Clone → primary: clear a namespace.
  static const String clear = 'storage.clear';

  /// Primary → clones: committed changes.
  static const String changed = 'storage.changed';

  /// Primary → clone: close this window.
  static const String dismiss = 'shell_dismiss';

  /// Any window → another clone: raise and show the given room route. Used
  /// when a room card is pressed again while its window has navigated
  /// elsewhere.
  static const String navigate = 'shell_navigate';
}

/// The clone window's RPC client, implemented over the same transport the
/// bridge serves.
final class WindowStorageClient implements RemoteStorageClient {
  /// Sends each call through [send] (the clone boot's retrying main call).
  const new(this.send);

  /// The clone → primary call.
  final Future<Object?> Function(String method, [Object? arguments]) send;

  @override
  Future<StorageSnapshot> snapshot(String namespace) async {
    final answer = await send(WindowStorageMethods.snapshot, {'namespace': namespace});
    if (answer is! Map) {
      throw StateError('the primary window did not answer the storage snapshot');
    }
    final map = _mapOf(answer);
    // A primary from before the revision protocol answered with the entries
    // themselves; keep that answer readable during a mixed-version session.
    if (!map.containsKey('values')) return StorageSnapshot(values: map);
    return StorageSnapshot(values: _mapOf(map['values']), revision: _revisionOf(map['revision']));
  }

  @override
  Future<void> put(String namespace, String key, Object? value) async {
    _ensure(await send(WindowStorageMethods.put, {'namespace': namespace, 'key': key, 'value': value}));
  }

  @override
  Future<void> putAll(String namespace, Map<String, Object?> values) async {
    _ensure(await send(WindowStorageMethods.putAll, {'namespace': namespace, 'values': values}));
  }

  @override
  Future<void> delete(String namespace, String key) async {
    _ensure(await send(WindowStorageMethods.delete, {'namespace': namespace, 'key': key}));
  }

  @override
  Future<void> deleteAll(String namespace, Iterable<String> keys) async {
    _ensure(await send(WindowStorageMethods.deleteAll, {'namespace': namespace, 'keys': keys.toList()}));
  }

  @override
  Future<void> clear(String namespace) async {
    _ensure(await send(WindowStorageMethods.clear, {'namespace': namespace}));
  }

  static void _ensure(Object? answer) {
    if (answer == true) return;
    throw StateError('the primary window did not accept the storage command');
  }
}

/// The primary window's store server and the clone window's store client.
///
/// Only the primary writes SQLite. It serves snapshots and commands, listens
/// to its local stores and broadcasts committed changes to every clone. A
/// clone applies the broadcasts to its remote projection and never writes a
/// database.
final class WindowStorageBridge {
  /// A bridge over the current window's channel and the provider tree.
  new(this._ref) : _media = WindowMediaSessionHub(_ref);

  final Ref _ref;

  /// The media half of the same window channel: the primary's one system
  /// surface and a clone's transport buttons.
  final WindowMediaSessionHub _media;
  final LiveLog _log = appLog.forCategory('window storage');

  bool _registered = false;
  String? _selfId;
  StreamSubscription<StorageChange>? _localChanges;
  StreamSubscription<void>? _windowSetSub;
  Timer? _timer;
  Timer? _heartbeat;
  Timer? _settingsTimer;
  final Map<String, StorageChange> _pending = {};
  final Map<String, int> _revisions = {};
  final Set<String> _resyncing = {};

  /// Arms the window channel and (in the primary) the local change watch.
  Future<void> register() async {
    if (_registered) return;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final self = await WindowController.fromCurrentEngine();
        _selfId = self.windowId;
        await self.setWindowMethodHandler(_handle);
        _registered = true;
        if (_ref.read(isPrimaryWindowProvider)) {
          _localChanges = StorageStores.instance.changes.listen(_queue);
          // A revision heartbeat covers the last broadcast being lost: a
          // clone that sees a newer revision without its values fetches a
          // fresh snapshot instead of staying stale until the next write.
          _heartbeat ??= Timer.periodic(const Duration(seconds: 20), (_) => unawaited(_broadcastRevisions()));
        }
        // A room window can be closed with its native X, which never goes
        // through SecondaryWindows. Forget it as soon as the plugin reports
        // the change, or a stale entry keeps answering for a dead engine.
        _windowSetSub = onWindowsChanged.listen((_) => unawaited(_pruneWindowSet()));
        return;
      } on Object catch (error, stackTrace) {
        if (attempt >= 4) {
          _log.warning(
            'the window storage bridge could not register',
            fields: {'error': '$error', 'stack': '$stackTrace'},
          );
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }
  }

  /// Releases the local change watch and the broadcast timer.
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    _settingsTimer?.cancel();
    _settingsTimer = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _pending.clear();
    _resyncing.clear();
    await _localChanges?.cancel();
    _localChanges = null;
    await _windowSetSub?.cancel();
    _windowSetSub = null;
    await _media.dispose();
  }

  Future<void> _pruneWindowSet() async {
    final windows = _ref.read(secondaryWindowsProvider);
    if (windows == null) return;
    final List<WindowController> live;
    try {
      live = await WindowController.getAll();
    } on Object {
      return;
    }
    final ids = {for (final window in live) window.windowId};
    for (final window in windows.opened) {
      if (!ids.contains(window.id)) windows.noteGone(window.id);
    }
  }

  Future<Object?> _handle(MethodCall call) {
    if (WindowMediaMethods.isMedia(call.method)) {
      return _media.handle(call);
    }
    final primary = _ref.read(isPrimaryWindowProvider);
    return primary ? _handlePrimary(call) : _handleClone(call);
  }

  Future<Object?> _handlePrimary(MethodCall call) async {
    final arguments = _mapOf(call.arguments);
    final namespace = arguments['namespace'];
    if (namespace is! String || namespace.isEmpty) {
      throw ArgumentError('storage call without a namespace');
    }
    final store = await StorageStores.instance.openStore(namespace);
    switch (call.method) {
      case WindowStorageMethods.snapshot:
        // Read the values and the revision in one synchronous turn: a write
        // either completed before both reads or after both, never between.
        return <String, Object?>{
          'values': store.entries,
          'revision': _revisions[namespace] ?? 0,
        };
      case WindowStorageMethods.put:
        await store.put(arguments['key'] as String? ?? '', arguments['value']);
        _bumpSettings(namespace);
        return true;
      case WindowStorageMethods.putAll:
        await store.putAll(_mapOf(arguments['values']));
        _bumpSettings(namespace);
        return true;
      case WindowStorageMethods.delete:
        await store.delete(arguments['key'] as String? ?? '');
        _bumpSettings(namespace);
        return true;
      case WindowStorageMethods.deleteAll:
        final keys = switch (arguments['keys']) {
          final List<Object?> list => [
            for (final key in list)
              if (key is String) key,
          ],
          _ => const <String>[],
        };
        await store.deleteAll(keys);
        _bumpSettings(namespace);
        return true;
      case WindowStorageMethods.clear:
        await store.clear();
        _bumpSettings(namespace);
        return true;
      default:
        return null;
    }
  }

  Future<Object?> _handleClone(MethodCall call) async {
    switch (call.method) {
      case WindowStorageMethods.changed:
        final arguments = _mapOf(call.arguments);
        final namespace = arguments['namespace'];
        if (namespace is String && namespace.isNotEmpty) {
          final values = _mapOf(arguments['values']);
          final change = StorageChange(
            namespace: namespace,
            values: values,
            revision: _revisionOf(arguments['revision']),
          );
          final outcome = StorageStores.instance.reload(change);
          if (outcome == RemoteChangeOutcome.gap) {
            // Do not apply a delta whose predecessors are missing; one fresh
            // snapshot is both cheaper and correct.
            unawaited(_resync(namespace));
          } else if (outcome == RemoteChangeOutcome.applied && namespace == 'settings') {
            _scheduleSettingsRefresh();
          }
        }
      case WindowStorageMethods.dismiss:
        // Say goodbye to the media surface while the channel is still here;
        // the primary also prunes a window that vanishes without this.
        try {
          await _ref.read(windowMediaReporterProvider.notifier).release();
        } on Object {
          // The report queue is best-effort during shutdown.
        }
        await _ref.read(windowCloseProvider)?.call();
      case WindowStorageMethods.navigate:
        final route = _mapOf(call.arguments)['route'];
        if (route is String && route.isNotEmpty) {
          final router = _ref.read(appRouterProvider);
          // A window already showing the room only comes forward; `go` to
          // the same location would rebuild the room and restart playback.
          final current = router.routerDelegate.currentConfiguration.lastOrNull?.matchedLocation;
          if (current != route) {
            router.go(route);
          }
        }
    }
    return null;
  }

  void _bumpSettings(String namespace) {
    if (namespace != 'settings') return;
    _scheduleSettingsRefresh();
  }

  void _scheduleSettingsRefresh() {
    _settingsTimer?.cancel();
    _settingsTimer = Timer(const Duration(milliseconds: 32), () => refreshSettings(_ref));
  }

  void _queue(StorageChange change) {
    final namespace = change.namespace;
    final revision = (_revisions[namespace] ?? 0) + 1;
    _revisions[namespace] = revision;
    final pending = _pending[namespace];
    _pending[namespace] = StorageChange(
      namespace: namespace,
      values: {...?pending?.values, ...change.values},
      revision: revision,
    );
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 16), () => unawaited(_flush()));
  }

  Future<void> _resync(String namespace) async {
    if (!_resyncing.add(namespace)) return;
    try {
      final moved = await StorageStores.instance.resync(namespace);
      if (moved && namespace == 'settings') _scheduleSettingsRefresh();
    } on Object catch (error, stackTrace) {
      _log.warning(
        'a namespace could not be reconciled',
        fields: {'namespace': namespace, 'error': '$error', 'stack': '$stackTrace'},
      );
    } finally {
      _resyncing.remove(namespace);
    }
  }

  Future<void> _broadcastRevisions() async {
    if (_revisions.isEmpty) return;
    final List<WindowController> windows;
    try {
      windows = await WindowController.getAll();
    } on Object {
      return;
    }
    for (final window in windows) {
      if (window.windowId == _selfId) continue;
      for (final entry in _revisions.entries) {
        try {
          await window
              .invokeMethod<Object>(WindowStorageMethods.changed, {
                'namespace': entry.key,
                'revision': entry.value,
                'values': const <String, Object?>{},
              })
              .timeout(const Duration(seconds: 2));
        } on Object {
          // A window that closed or has not armed its handler yet.
        }
      }
    }
  }

  Future<void> _flush() async {
    _timer = null;
    if (_pending.isEmpty) return;
    final batches = Map<String, StorageChange>.of(_pending);
    _pending.clear();
    final List<WindowController> windows;
    try {
      windows = await WindowController.getAll();
    } on Object {
      return;
    }
    for (final window in windows) {
      if (window.windowId == _selfId) continue;
      for (final entry in batches.entries) {
        final change = entry.value;
        try {
          await window
              .invokeMethod<Object>(WindowStorageMethods.changed, {
                'namespace': entry.key,
                'values': change.values,
                'revision': change.revision,
              })
              .timeout(const Duration(seconds: 2));
        } on Object {
          // A window that closed or has not armed its handler yet.
        }
      }
    }
  }
}

/// The bridge, built once per engine and registered from the root.
final windowStorageBridgeProvider = Provider<WindowStorageBridge>((ref) {
  final bridge = WindowStorageBridge(ref);
  ref.onDispose(() => unawaited(bridge.dispose()));
  return bridge;
});

int _revisionOf(Object? value) => value is int ? value : (value is num ? value.toInt() : 0);

Map<String, Object?> _mapOf(Object? value) => switch (value) {
  final Map<Object?, Object?> map => {for (final entry in map.entries) '${entry.key}': _jsonValue(entry.value)},
  _ => const <String, Object?>{},
};

/// StandardMessageCodec hands nested maps back with dynamic keys. Built
/// value and the settings readers expect string keys at every level, so
/// the bridge normalises the whole document before it enters a store.
Object? _jsonValue(Object? value) => switch (value) {
  final Map<Object?, Object?> map => {for (final entry in map.entries) '${entry.key}': _jsonValue(entry.value)},
  final List<Object?> list => [for (final entry in list) _jsonValue(entry)],
  _ => value,
};
