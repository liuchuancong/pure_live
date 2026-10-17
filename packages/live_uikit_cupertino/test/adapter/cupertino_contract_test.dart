import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_cupertino/live_uikit_cupertino.dart';

/// The Cupertino UI adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `CupertinoLanguageAdapter`
/// overrides and the surfaces it owns; the resolver raises a
/// `LiveUiCapabilityException` for anything declared without a matching override,
/// so drift between the declaration and the overrides is caught here before it
/// ships (§17).
void main() {
  const adapter = cupertinoAdapter;

  const native = {
    LiveUiControl.button,
    LiveUiControl.card,
    LiveUiControl.textField,
    LiveUiControl.switchWidget,
    LiveUiControl.checkbox,
    LiveUiControl.slider,
    LiveUiControl.segmented,
    LiveUiControl.progress,
    LiveUiControl.select,
    LiveUiControl.tabBar,
    LiveUiControl.scaffold,
    LiveUiControl.appBar,
    LiveUiControl.listRow,
    LiveUiControl.navBar,
    LiveUiControl.toast,
    LiveUiControl.dialog,
    LiveUiControl.tabView,
  };

  test('declares exactly the surfaces it owns structurally', () {
    const owned = <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell};
    for (final surface in owned) {
      expect(adapter.surfaces.supports(surface), isTrue, reason: '$surface should be native');
    }
    for (final surface in LiveUiSurface.values.toSet().difference(owned)) {
      expect(adapter.surfaces.supports(surface), isFalse, reason: '$surface should fall back');
    }
  });

  group('Cupertino UI adapter contract (§7)', () {
    test('exposes a stable id, display name and language', () {
      expect(adapter.id, cupertinoAdapterId);
      expect(adapter.id, 'cupertino');
      expect(adapter.displayName, 'Cupertino UI');
      expect(adapter.language, LiveDesignLanguage.cupertino);
    });

    test('declares exactly the controls it renders natively', () {
      // All seventeen: Cupertino renders every control, and the five with no
      // one-for-one library widget say so in their builder (§9).
      for (final control in native) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control should be native');
      }
      for (final control in LiveUiControl.values.toSet().difference(native)) {
        expect(adapter.capabilities.supports(control), isFalse, reason: '$control should fall back');
      }
      // The other half of the point: this language declares the whole contract,
      // so the set above has to be every control `LiveUiControl` exposes.
      expect(adapter.capabilities.supported, LiveUiControl.values.toSet());
    });
  });

  group('Cupertino UI resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(adapters: {LiveDesignLanguage.cupertino: adapter});
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to the native adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.cupertino).id, 'cupertino');
    });

    test('a registered language resolves to this adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.cupertino).id, 'cupertino');
    });

    test('every control of the contract resolves to this adapter, with no diagnostic', () {
      final adapter = resolver.resolve(LiveDesignLanguage.cupertino);
      for (final control in LiveUiControl.values) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control');
        resolver.requireControl(LiveDesignLanguage.cupertino, control);
      }
    });

    test('a language this build did not register raises instead of degrading', () {
      expect(() => resolver.resolve(LiveDesignLanguage.fluent), throwsA(isA<LiveUiResolutionException>()));
    });
  });
}
