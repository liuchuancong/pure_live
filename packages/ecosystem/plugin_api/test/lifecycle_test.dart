// Module: test/lifecycle_test.dart
// Purpose: Verify the plugin lifecycle table, especially the re-initialisation rule after Disabled.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_plugin_api/pure_live_plugin_api.dart';
import 'package:test/test.dart';

void main() {
  test('test_lifecycle_documentedChain_isWalkable', () {
    final lifecycle = PluginLifecycle('com.purelive.source.bilibili');

    lifecycle.goTo(PluginLifecycleState.verified);
    lifecycle.goTo(PluginLifecycleState.loaded);
    lifecycle.goTo(PluginLifecycleState.initialized);
    lifecycle.goTo(PluginLifecycleState.enabled);

    expect(lifecycle.state, PluginLifecycleState.enabled);
    expect(lifecycle.isEnabled, isTrue);
  });

  test('test_lifecycle_disabledToEnabled_mustPassThroughInitializedAgain', () {
    // plugin-lifecycle.md section 2: the bridge is re-injected and permissions are re-read at that moment,
    // so a disabled plugin cannot jump straight back to being consumable.
    final lifecycle = PluginLifecycle('com.purelive.source.bilibili');
    for (final state in <PluginLifecycleState>[
      PluginLifecycleState.verified,
      PluginLifecycleState.loaded,
      PluginLifecycleState.initialized,
      PluginLifecycleState.enabled,
      PluginLifecycleState.disabled,
    ]) {
      lifecycle.goTo(state);
    }

    expect(lifecycle.canGoTo(PluginLifecycleState.enabled), isFalse);
    expect(() => lifecycle.goTo(PluginLifecycleState.enabled), throwsA(isA<PluginLifecycleException>()));

    lifecycle.goTo(PluginLifecycleState.initialized);
    lifecycle.goTo(PluginLifecycleState.enabled);
    expect(lifecycle.isEnabled, isTrue);
  });

  test('test_lifecycle_skippingVerification_isRefused', () {
    final lifecycle = PluginLifecycle('com.purelive.source.bilibili');

    expect(() => lifecycle.goTo(PluginLifecycleState.loaded), throwsA(isA<PluginLifecycleException>()));
    expect(lifecycle.state, PluginLifecycleState.installed);
  });

  test('test_lifecycle_uninstallIsReachableFromEveryLiveStateAndThenTerminal', () {
    for (final state in PluginLifecycleState.values.where((s) => s != PluginLifecycleState.uninstalled)) {
      final lifecycle = PluginLifecycle('p', state: state);

      expect(lifecycle.canGoTo(PluginLifecycleState.uninstalled), isTrue, reason: state.name);
      lifecycle.goTo(PluginLifecycleState.uninstalled);

      expect(
        PluginLifecycle.transitions[PluginLifecycleState.uninstalled],
        isEmpty,
        reason: 'an uninstalled plugin has no next state',
      );
      expect(lifecycle.canGoTo(PluginLifecycleState.installed), isFalse);
    }
  });

  test('test_lifecycle_everyTransitionIsAnnounced', () {
    // plugin-lifecycle.md section 2 requires plugin.enabled / plugin.disabled events; the hook is where the
    // host publishes them, so it has to fire on every legal move and on none of the refused ones.
    final moves = <String>[];
    final lifecycle = PluginLifecycle(
      'com.purelive.source.bilibili',
      onChanged: (from, to) => moves.add('${from.name}>${to.name}'),
    );

    lifecycle.goTo(PluginLifecycleState.verified);
    expect(
      () => lifecycle.goTo(PluginLifecycleState.verified),
      throwsA(isA<PluginLifecycleException>()),
      reason: 'a repeated move is not a transition',
    );
    expect(() => lifecycle.goTo(PluginLifecycleState.enabled), throwsA(anything));

    expect(moves, <String>['installed>verified']);
    expect('$lifecycle', contains('verified'));
  });

  test('test_lifecycle_tableCoversEveryState', () {
    // A state missing from the table would be silently unreachable rather than obviously wrong.
    expect(PluginLifecycle.transitions.keys.toSet(), PluginLifecycleState.values.toSet());
  });
}
