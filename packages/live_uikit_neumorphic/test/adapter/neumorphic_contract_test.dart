import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_neumorphic/live_uikit_neumorphic.dart';

/// The Neumorphic adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `NeumorphicLanguageAdapter`
/// overrides with native `flutter_neumorphic_ui_kit` widgets; the resolver turns
/// every other control into a `controlUnsupported` downgrade, so drift between the
/// declaration and the overrides is caught here before it ships (§17).
void main() {
  const adapter = neumorphicAdapter;

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
    LiveUiControl.toast,
  };
  // Derived rather than listed, so a control added to the contract cannot join the
  // fallback side silently — the suite has to be told (§17).
  final fallback = LiveUiControl.values.toSet().difference(native);

  group('Neumorphic adapter contract (§7)', () {
    test('exposes a stable id, display name and language', () {
      expect(adapter.id, neumorphicAdapterId);
      expect(adapter.id, 'neumorphic');
      expect(adapter.displayName, 'Neumorphic');
      expect(adapter.language, LiveDesignLanguage.neumorphic);
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

  group('Neumorphic resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(
      adapters: {LiveDesignLanguage.neumorphic: adapter},
      fallback: SharedLanguageAdapter(),
    );
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to the native adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.neumorphic).implementation.kind, LiveImplementationKind.adapterNative);
    });

    test('a declared control resolves native with no diagnostic', () {
      final result = resolver.resolveControl(LiveDesignLanguage.neumorphic, LiveUiControl.button);
      expect(result.implementation.kind, LiveImplementationKind.adapterNative);
      expect(result.diagnostic, isNull);
    });

    test('an undeclared control falls back to shared and is reported', () {
      // The four chrome pieces are this build's remaining fallback side; naming one
      // keeps the downgrade path honest while the rest of the contract is native.
      final result = resolver.resolveControl(LiveDesignLanguage.neumorphic, LiveUiControl.scaffold);
      expect(result.implementation.kind, LiveImplementationKind.shared);
      expect(result.diagnostic?.code, LiveUiDiagnosticCode.controlUnsupported);
      expect(result.diagnostic?.control, LiveUiControl.scaffold);
    });
  });
}
