import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_glass/live_uikit_glass.dart';

/// The Glass adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `GlassLanguageAdapter`
/// renders with `glass_morphism_plus` — its own widgets where the library has
/// them, its own frosted surfaces and theme values where it does not. The whole
/// contract is in that set, so no control of it is answered by another adapter,
/// and drift between the declaration and the overrides is caught here before it
/// ships (§17).
void main() {
  const adapter = glassAdapter;

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

  group('Glass adapter contract (§7)', () {
    test('exposes a stable id, display name and language', () {
      expect(adapter.id, glassAdapterId);
      expect(adapter.id, 'glass');
      expect(adapter.displayName, 'Glass');
      expect(adapter.language, LiveDesignLanguage.glass);
    });

    test('declares exactly the surfaces it owns structurally', () {
      // Both sides of the pair now: `WidgetsApp` under `GlassTheme` for the host,
      // and a frosted navigation column composed from the library's own
      // `GlassContainer`s for the shell (§ surfaces).
      const owned = <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell};
      for (final surface in owned) {
        expect(adapter.surfaces.supports(surface), isTrue, reason: '$surface should be native');
      }
      for (final surface in LiveUiSurface.values.toSet().difference(owned)) {
        expect(adapter.surfaces.supports(surface), isFalse, reason: '$surface should fall back');
      }
      // Derived from the whole enum, so a surface added to the contract cannot
      // be left off the declaration silently — the same rule as the control set
      // below (§17).
      expect(adapter.surfaces.supported, LiveUiSurface.values.toSet());
    });

    test('declares exactly the controls it renders natively', () {
      for (final control in native) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control should be native');
      }
      for (final control in LiveUiControl.values.toSet().difference(native)) {
        expect(adapter.capabilities.supports(control), isFalse, reason: '$control should fall back');
      }
      // The other half of the point: a glass page asks this adapter for every
      // control, so the set above has to be the whole contract — and a control
      // added to the contract cannot go undeclared here silently (§17).
      expect(adapter.capabilities.supported, LiveUiControl.values.toSet());
    });
  });

  group('Glass resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(adapters: {LiveDesignLanguage.glass: adapter});
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to the native adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.glass).id, 'glass');
    });

    test('a registered language resolves to this adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.glass).id, 'glass');
    });

    test('every control of the contract resolves to this adapter, with no diagnostic', () {
      final adapter = resolver.resolve(LiveDesignLanguage.glass);
      for (final control in LiveUiControl.values) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control');
        resolver.requireControl(LiveDesignLanguage.glass, control);
      }
    });

    test('a language this build did not register raises instead of degrading', () {
      expect(() => resolver.resolve(LiveDesignLanguage.fluent), throwsA(isA<LiveUiResolutionException>()));
    });
  });
}
