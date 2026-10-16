import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_glass/live_uikit_glass.dart';

/// The Glass adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `GlassLanguageAdapter`
/// renders with `glass_morphism_plus` — its own widgets where the library has
/// them, its own frosted surfaces and theme values where it does not. The whole
/// contract is in that set, so this language has no fallback side and drift
/// between the declaration and the overrides is caught here before it ships (§17).
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
  };

  group('Glass adapter contract (§7)', () {
    test('exposes a stable id, display name and language', () {
      expect(adapter.id, glassAdapterId);
      expect(adapter.id, 'glass');
      expect(adapter.displayName, 'Glass');
      expect(adapter.language, LiveDesignLanguage.glass);
    });

    test('declares exactly the controls it renders natively', () {
      for (final control in native) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control should be native');
      }
      for (final control in LiveUiControl.values.toSet().difference(native)) {
        expect(adapter.capabilities.supports(control), isFalse, reason: '$control should fall back');
      }
      // The other half of the point: a glass page has no fallback side at all, so
      // the set above has to be the whole contract — and a control added to the
      // contract cannot join the shared side silently (§17).
      expect(adapter.capabilities.supported, LiveUiControl.values.toSet());
    });
  });

  group('Glass resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(adapters: {LiveDesignLanguage.glass: adapter}, fallback: SharedLanguageAdapter());
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to the native adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.glass).implementation.kind, LiveImplementationKind.adapterNative);
    });

    test('a declared control resolves native with no diagnostic', () {
      final result = resolver.resolveControl(LiveDesignLanguage.glass, LiveUiControl.button);
      expect(result.implementation.kind, LiveImplementationKind.adapterNative);
      expect(result.diagnostic, isNull);
    });

    test('every control of the contract resolves native, with no downgrade', () {
      for (final control in LiveUiControl.values) {
        final result = resolver.resolveControl(LiveDesignLanguage.glass, control);
        expect(result.implementation.kind, LiveImplementationKind.adapterNative, reason: '$control');
        expect(result.diagnostic, isNull, reason: '$control');
      }
    });

    test('a language this build did not register still resolves shared, and says so', () {
      final result = resolver.resolveControl(LiveDesignLanguage.neumorphic, LiveUiControl.segmented);
      expect(result.implementation.kind, LiveImplementationKind.shared);
      expect(result.diagnostic?.code, LiveUiDiagnosticCode.adapterMissing);
    });
  });
}
