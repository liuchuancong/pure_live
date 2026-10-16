import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_macos/live_uikit_macos.dart';

/// The macOS adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set is a declaration of fact: it must list exactly the controls
/// `MacosLanguageAdapter` overrides with native `macos_ui` widgets. The resolver
/// turns every other control into a `controlUnsupported` downgrade, so a set that
/// drifts from the overrides is a bug this test catches before it ships (§17).
void main() {
  const adapter = macosUiAdapter;

  const native = {
    LiveUiControl.button,
    LiveUiControl.textField,
    LiveUiControl.checkbox,
    LiveUiControl.slider,
    LiveUiControl.scaffold,
    LiveUiControl.appBar,
    LiveUiControl.listRow,
    LiveUiControl.appHost,
  };
  // Derived rather than listed, so a control added to the contract cannot join the
  // fallback side silently — the suite has to be told (§17).
  final fallback = LiveUiControl.values.toSet().difference(native);

  group('macOS adapter contract (§7)', () {
    test('exposes a stable id, display name and language', () {
      expect(adapter.id, macosUiAdapterId);
      expect(adapter.id, 'macos');
      expect(adapter.displayName, 'macOS');
      expect(adapter.language, LiveDesignLanguage.macos);
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

  group('macOS resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(adapters: {LiveDesignLanguage.macos: adapter}, fallback: SharedLanguageAdapter());
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to the native adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.macos).implementation.kind, LiveImplementationKind.adapterNative);
    });

    test('a declared control resolves native with no diagnostic', () {
      final result = resolver.resolveControl(LiveDesignLanguage.macos, LiveUiControl.button);
      expect(result.implementation.kind, LiveImplementationKind.adapterNative);
      expect(result.diagnostic, isNull);
    });

    test('an undeclared control falls back to shared and is reported', () {
      final result = resolver.resolveControl(LiveDesignLanguage.macos, LiveUiControl.card);
      expect(result.implementation.kind, LiveImplementationKind.shared);
      expect(result.diagnostic?.code, LiveUiDiagnosticCode.controlUnsupported);
      expect(result.diagnostic?.control, LiveUiControl.card);
    });
  });
}
