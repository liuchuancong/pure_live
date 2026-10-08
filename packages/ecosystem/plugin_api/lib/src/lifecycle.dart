// Module: lib/src/lifecycle.dart
// Purpose: The plugin lifecycle state machine and the transitions a host is allowed to make.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/plugin/plugin-lifecycle.md section 1:
// Installed -> Verified -> Loaded -> Initialized -> Enabled <-> Disabled -> Uninstalled.
// The table below is that chain plus the two rules the document states in section 2: going back from
// Disabled to Enabled must pass through Initialized again, and every transition has to be announced.

import 'package:pure_live_platform/pure_live_platform.dart';

/// Where one plugin is.
enum PluginLifecycleState {
  /// On disk and in the registry, not checked yet.
  installed,

  /// Manifest, signature and compatibility passed.
  verified,

  /// Code loaded: a compiled native body, a compiled JS script or a ready data parser.
  loaded,

  /// `init(HostBridge)` succeeded and the plugin holds its sandbox bridge.
  initialized,

  /// Visible to the CapabilityRegistry and consumable by features.
  enabled,

  /// Out of the registry and resources reclaimed; data kept.
  disabled,

  /// Code and namespace data removed.
  uninstalled,
}

/// A transition the table does not allow.
final class PluginLifecycleException implements Exception {
  const PluginLifecycleException({required this.pluginId, required this.from, required this.to});

  final ExtensionId pluginId;
  final PluginLifecycleState from;
  final PluginLifecycleState to;

  @override
  String toString() => 'PluginLifecycleException($pluginId cannot go from ${from.name} to ${to.name})';
}

/// The lifecycle of one plugin.
///
/// It is a separate object from the runtime because the host, not the plugin, owns these states: a plugin
/// that could set itself to `enabled` would be its own installer.
final class PluginLifecycle {
  PluginLifecycle(
    this.pluginId, {
    PluginLifecycleState state = PluginLifecycleState.installed,
    void Function(PluginLifecycleState from, PluginLifecycleState to)? onChanged,
  }) : _state = state,
       _onChanged = onChanged;

  /// The legal moves. Anything absent from this table is refused, which is what makes "Disabled to Enabled
  /// needs to re-run Initialized" a fact rather than a sentence in a document.
  static const Map<PluginLifecycleState, Set<PluginLifecycleState>> transitions =
      <PluginLifecycleState, Set<PluginLifecycleState>>{
        PluginLifecycleState.installed: <PluginLifecycleState>{
          PluginLifecycleState.verified,
          PluginLifecycleState.uninstalled,
        },
        PluginLifecycleState.verified: <PluginLifecycleState>{
          PluginLifecycleState.loaded,
          PluginLifecycleState.uninstalled,
        },
        PluginLifecycleState.loaded: <PluginLifecycleState>{
          PluginLifecycleState.initialized,
          PluginLifecycleState.uninstalled,
        },
        PluginLifecycleState.initialized: <PluginLifecycleState>{
          PluginLifecycleState.enabled,
          PluginLifecycleState.disabled,
          PluginLifecycleState.uninstalled,
        },
        PluginLifecycleState.enabled: <PluginLifecycleState>{
          PluginLifecycleState.disabled,
          PluginLifecycleState.uninstalled,
        },
        PluginLifecycleState.disabled: <PluginLifecycleState>{
          PluginLifecycleState.initialized,
          PluginLifecycleState.uninstalled,
        },
        PluginLifecycleState.uninstalled: <PluginLifecycleState>{},
      };

  final ExtensionId pluginId;
  final void Function(PluginLifecycleState from, PluginLifecycleState to)? _onChanged;

  PluginLifecycleState _state;

  PluginLifecycleState get state => _state;

  bool canGoTo(PluginLifecycleState next) => transitions[_state]?.contains(next) ?? false;

  /// Moves to [next], or throws when the table does not allow it.
  void goTo(PluginLifecycleState next) {
    if (!canGoTo(next)) {
      throw PluginLifecycleException(pluginId: pluginId, from: _state, to: next);
    }
    final previous = _state;
    _state = next;
    _onChanged?.call(previous, next);
  }

  /// Whether the plugin may be consumed by a feature right now.
  bool get isEnabled => _state == PluginLifecycleState.enabled;

  @override
  String toString() => 'PluginLifecycle($pluginId ${_state.name})';
}
