// Module: lib/src/host_bridge.dart
// Purpose: The only surface a plugin may reach the host through, expressed in plugin-sized terms.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/provider-contract.md section 2 - a provider is initialised with a HostBridge that
// offers PluginNetwork, namespaced kv, permission-checked cookie access and event publishing, and must not
// reach past it to the host.
//
// These ports deliberately mirror the platform contracts in pure_live_permission instead of importing them.
// A JS plugin cannot hold a Dart ExtensionNetwork object, and the bridge is the subset a script is allowed
// to see; the host implements this interface by adapting the platform services, which is where the two
// vocabularies meet in one place on purpose.

import 'package:pure_live_platform/pure_live_platform.dart';

/// Network access for one plugin. Requests to a host the declaration did not name are refused here, not in
/// the plugin.
abstract interface class PluginNetwork {
  Future<NetworkResponse> send(NetworkRequest request);
}

/// Cookie access for the domains this plugin declared. There is no global jar behind it.
abstract interface class PluginCookieAccess {
  Future<List<Cookie>> read(Uri uri);

  Future<void> write(Cookie cookie);

  Future<void> clear({String? host});
}

/// Key/value storage inside this plugin's own namespace.
abstract interface class PluginKvStore {
  Future<Object?> read(String key);

  Future<void> write(String key, Object? value);

  Future<void> remove(String key);

  Future<List<String>> keys();
}

/// Events a plugin may publish. It cannot subscribe to host-internal events through the bridge.
abstract interface class PluginEventSink {
  void publish(String name, {Map<String, Object?> payload});
}

/// Everything a loaded plugin can ask the host for.
abstract interface class HostBridge {
  PluginNetwork get network;

  PluginCookieAccess get cookies;

  PluginKvStore get kv;

  PluginEventSink get events;

  /// The plugin's own declaration, so it can read its capabilities without a second source of truth.
  PluginManifest get manifest;
}

/// The default event sink: keeps the newest events in memory.
///
/// It exists so a host can wire a plugin without inventing a bus first, and so a test can read what a plugin
/// published. It is bounded because a plugin in a loop must not grow the host's memory.
final class InMemoryPluginEventSink implements PluginEventSink {
  InMemoryPluginEventSink({this.capacity = 128});

  final int capacity;
  final List<Map<String, Object?>> _events = <Map<String, Object?>>[];

  @override
  void publish(String name, {Map<String, Object?> payload = const <String, Object?>{}}) {
    _events.add(<String, Object?>{'name': name, 'payload': payload});
    while (_events.length > capacity) {
      _events.removeAt(0);
    }
  }

  List<Map<String, Object?>> get published => List<Map<String, Object?>>.unmodifiable(_events);
}
