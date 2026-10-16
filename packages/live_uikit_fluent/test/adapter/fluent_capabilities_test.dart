import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';

void main() {
  const adapter = fluentAdapter;

  test('declares exactly the surfaces it owns structurally', () {
    for (final surface in const <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell}) {
      expect(adapter.surfaces.supports(surface), isTrue, reason: '$surface should be native');
    }
    for (final surface in LiveUiSurface.values.toSet().difference(const <LiveUiSurface>{
      LiveUiSurface.appHost,
      LiveUiSurface.appShell,
    })) {
      expect(adapter.surfaces.supports(surface), isFalse, reason: '$surface should fall back');
    }
  });

  group('Fluent adapter contract (§7)', () {
    test('exposes a stable id and display name', () {
      expect(adapter.id, fluentAdapterId);
      expect(adapter.id, 'fluent');
      expect(adapter.displayName, 'Fluent');
    });

    test('declares exactly the controls it renders natively', () {
      // All fifteen: Fluent renders every control, and the four without a
      // one-for-one library widget say so in their builder (§9).
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
      for (final control in native) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control should be native');
      }
      // Derived rather than listed, so a control added to the contract cannot
      // join the fallback side silently — the suite has to be told (§17).
      for (final control in LiveUiControl.values.toSet().difference(native)) {
        expect(adapter.capabilities.supports(control), isFalse, reason: '$control should fall back');
      }
      // The other half of the point: this language has no fallback side at all,
      // so the set above has to be the whole contract.
      expect(adapter.capabilities.supported, LiveUiControl.values.toSet());
    });
  });

  group('Fluent resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(
      adapters: {LiveDesignLanguage.fluent: adapter},
      fallback: SharedLanguageAdapter(),
    );
    const resolver = LiveUiResolver(registry: registry);

    test('a declared control resolves native with no diagnostic', () {
      final result = resolver.resolveControl(LiveDesignLanguage.fluent, LiveUiControl.button);
      expect(result.implementation.kind, LiveImplementationKind.adapterNative);
      expect(result.diagnostic, isNull);
    });

    test('every control of the contract resolves native for Fluent', () {
      for (final control in LiveUiControl.values) {
        final result = resolver.resolveControl(LiveDesignLanguage.fluent, control);
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
