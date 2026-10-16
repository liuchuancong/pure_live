import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_material/live_uikit_material.dart';

/// The Material UI adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `MaterialLanguageAdapter`
/// overrides with native `material_ui` widgets; the resolver turns every other
/// control into a `controlUnsupported` downgrade, so drift between the declaration
/// and the overrides is caught here before it ships (§17).
void main() {
  const adapter = materialAdapter;

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
    LiveUiControl.tabView,
    LiveUiControl.dialog,
    LiveUiControl.scaffold,
    LiveUiControl.appBar,
    LiveUiControl.listRow,
    LiveUiControl.navBar,
    LiveUiControl.toast,
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

  group('Material UI adapter contract (§7)', () {
    test('exposes a stable id, display name and language', () {
      expect(adapter.id, materialAdapterId);
      expect(adapter.id, 'material');
      expect(adapter.displayName, 'Material UI');
      expect(adapter.language, LiveDesignLanguage.material);
    });

    test('declares exactly the controls it renders natively', () {
      for (final control in native) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control should be native');
      }
      // The other half of the point: this language has no fallback side at all,
      // so the set above has to be the whole contract.
      expect(adapter.capabilities.supported, LiveUiControl.values.toSet());
    });
  });

  group('Material UI resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(
      adapters: {LiveDesignLanguage.material: adapter},
      fallback: SharedLanguageAdapter(),
    );
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to the native adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.material).implementation.kind, LiveImplementationKind.adapterNative);
    });

    test('a declared control resolves native with no diagnostic', () {
      final result = resolver.resolveControl(LiveDesignLanguage.material, LiveUiControl.button);
      expect(result.implementation.kind, LiveImplementationKind.adapterNative);
      expect(result.diagnostic, isNull);
    });

    test('every control of the contract resolves native, with no downgrade', () {
      for (final control in LiveUiControl.values) {
        final result = resolver.resolveControl(LiveDesignLanguage.material, control);
        expect(result.implementation.kind, LiveImplementationKind.adapterNative, reason: '$control');
        expect(result.diagnostic, isNull, reason: '$control');
      }
    });

    test('a language this build did not register still resolves shared, and says so', () {
      final result = resolver.resolveControl(LiveDesignLanguage.glass, LiveUiControl.select);
      expect(result.implementation.kind, LiveImplementationKind.shared);
      expect(result.diagnostic?.code, LiveUiDiagnosticCode.adapterMissing);
    });
  });
}
