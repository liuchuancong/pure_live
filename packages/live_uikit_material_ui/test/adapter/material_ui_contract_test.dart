import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_material_ui/live_uikit_material_ui.dart';

/// The Material UI adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `MaterialUiLanguageAdapter`
/// overrides with native `material_ui` widgets; the resolver turns every other
/// control into a `controlUnsupported` downgrade, so drift between the declaration
/// and the overrides is caught here before it ships (§17).
void main() {
  const adapter = materialUiAdapter;

  const native = {
    LiveUiControl.button,
    LiveUiControl.card,
    LiveUiControl.textField,
    LiveUiControl.switchWidget,
    LiveUiControl.checkbox,
    LiveUiControl.slider,
    LiveUiControl.segmented,
    LiveUiControl.progress,
    LiveUiControl.scaffold,
    LiveUiControl.appBar,
    LiveUiControl.listRow,
    LiveUiControl.navBar,
  };
  // Derived rather than listed, so a control added to the contract cannot join the
  // fallback side silently — the suite has to be told (§17).
  final fallback = LiveUiControl.values.toSet().difference(native);

  group('Material UI adapter contract (§7)', () {
    test('exposes a stable id, display name and language', () {
      expect(adapter.id, materialUiAdapterId);
      expect(adapter.id, 'materialUi');
      expect(adapter.displayName, 'Material UI');
      expect(adapter.language, LiveDesignLanguage.materialUi);
    });

    test('declares exactly the controls it renders natively', () {
      for (final control in native) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control should be native');
      }
      for (final control in fallback) {
        expect(adapter.capabilities.supports(control), isFalse, reason: '$control should fall back');
      }
    });
  });

  group('Material UI resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(
      adapters: {LiveDesignLanguage.materialUi: adapter},
      fallback: SharedLanguageAdapter(),
    );
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to the native adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.materialUi).implementation.kind, LiveImplementationKind.adapterNative);
    });

    test('a declared control resolves native with no diagnostic', () {
      final result = resolver.resolveControl(LiveDesignLanguage.materialUi, LiveUiControl.button);
      expect(result.implementation.kind, LiveImplementationKind.adapterNative);
      expect(result.diagnostic, isNull);
    });

    test('an undeclared control falls back to shared and is reported', () {
      final result = resolver.resolveControl(LiveDesignLanguage.materialUi, LiveUiControl.select);
      expect(result.implementation.kind, LiveImplementationKind.shared);
      expect(result.diagnostic?.code, LiveUiDiagnosticCode.controlUnsupported);
      expect(result.diagnostic?.control, LiveUiControl.select);
    });
  });
}
