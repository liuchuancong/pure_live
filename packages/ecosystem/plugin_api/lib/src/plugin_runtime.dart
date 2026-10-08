// Module: lib/src/plugin_runtime.dart
// Purpose: The runtime that hosts one plugin, whichever way its code executes.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/plugin-contract.md section 1 (Runtime: native / js / data) and section 2 (the plugin
// and the host communicate only through the capability contract). Interfaces only in this wave: the native
// runtime is a Dart call table, the js runtime wraps fjs and the data runtime is a parser, and each of those
// belongs to the plugin host in W10.

import 'package:pure_live_platform/pure_live_platform.dart';

import 'host_bridge.dart';

/// Hosts one loaded plugin.
abstract interface class PluginRuntime {
  /// Which of the three execution forms this runtime implements.
  PluginRuntimeKind get kind;

  /// Brings the plugin up with the bridge it may reach. The manifest is the already-validated declaration:
  /// a runtime must not re-read a manifest from disk here, because that would let a plugin change its own
  /// permission ceiling after review.
  Future<void> load(PluginManifest manifest, HostBridge bridge);

  /// Publishes the plugin's capabilities to the registry so features can consume them.
  Future<void> enable();

  /// Withdraws the plugin and releases what it held; its data stays.
  Future<void> disable();

  /// Releases the code and the namespace, the last thing a runtime is asked to do.
  Future<void> unload();
}
