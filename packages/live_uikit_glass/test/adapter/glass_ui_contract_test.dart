import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_glass/live_uikit_glass.dart';

/// The Glass adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `GlassLanguageAdapter`
/// overrides with native `glass_morphism_plus` widgets; the resolver turns every
/// other control into a `controlUnsupported` downgrade, so drift between the
/// declaration and the overrides is caught here before it ships (§17).
void main() {
  const adapter = glassUiAdapter;

  const native = {LiveUiControl.button, LiveUiControl.card, LiveUiControl.textField};
  // Derived rather than listed, so a control added to the contract cannot join the
  // fallback side silently — the suite has to be told (§17).
  final fallback = LiveUiControl.values.toSet().difference(native);

  group('Glass adapter contract (§7)', () {
    test('exposes a stable id, display name and language', () {
      expect(adapter.id, glassUiAdapterId);
      expect(adapter.id, 'glass');
      expect(adapter.displayName, 'Glass');
      expect(adapter.language, LiveDesignLanguage.glass);
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

    test('an undeclared control falls back to shared and is reported', () {
      final result = resolver.resolveControl(LiveDesignLanguage.glass, LiveUiControl.checkbox);
      expect(result.implementation.kind, LiveImplementationKind.shared);
      expect(result.diagnostic?.code, LiveUiDiagnosticCode.controlUnsupported);
      expect(result.diagnostic?.control, LiveUiControl.checkbox);
    });
  });
}
