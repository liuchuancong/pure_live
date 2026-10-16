import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_forui/live_uikit_forui.dart';

/// The ForUI adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `ForuiLanguageAdapter` overrides
/// with native `forui` widgets; the resolver turns every other control into a
/// `controlUnsupported` downgrade, so drift between the declaration and the overrides is
/// caught here before it ships (§17).
void main() {
  const adapter = foruiUiAdapter;

  const native = {
    LiveUiControl.button,
    LiveUiControl.card,
    LiveUiControl.textField,
    LiveUiControl.switchWidget,
    LiveUiControl.checkbox,
  };
  // Derived rather than listed, so a control added to the contract cannot join
  // the fallback side silently — the suite has to be told, and that is the
  // point of the assertion (§17).
  final fallback = LiveUiControl.values.toSet().difference(native);

  group('ForUI adapter contract (§7)', () {
    test('exposes a stable id, display name and language', () {
      expect(adapter.id, foruiUiAdapterId);
      expect(adapter.id, 'forui');
      expect(adapter.displayName, 'ForUI');
      expect(adapter.language, LiveDesignLanguage.forui);
    });

    test('declares exactly the controls it renders natively', () {
      for (final control in native) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control should be native');
      }
      for (final control in fallback) {
        expect(adapter.capabilities.supports(control), isFalse, reason: '$control should fall back');
      }
      expect(adapter.capabilities.supported, hasLength(native.length));
      expect(adapter.capabilities.supported, equals(native), reason: 'the declaration is the whole native set');
    });
  });

  group('ForUI resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(adapters: {LiveDesignLanguage.forui: adapter}, fallback: SharedLanguageAdapter());
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to the native adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.forui).implementation.kind, LiveImplementationKind.adapterNative);
    });

    test('a declared control resolves native with no diagnostic', () {
      final result = resolver.resolveControl(LiveDesignLanguage.forui, LiveUiControl.button);
      expect(result.implementation.kind, LiveImplementationKind.adapterNative);
      expect(result.diagnostic, isNull);
    });

    test('an undeclared control falls back to shared and is reported', () {
      final result = resolver.resolveControl(LiveDesignLanguage.forui, LiveUiControl.slider);
      expect(result.implementation.kind, LiveImplementationKind.shared);
      expect(result.diagnostic?.code, LiveUiDiagnosticCode.controlUnsupported);
      expect(result.diagnostic?.control, LiveUiControl.slider);
    });
  });

  group('registration surface (§10)', () {
    test('the const instance and the factory hand back the same adapter', () {
      expect(createForuiUiAdapter().id, foruiUiAdapterId);
      expect(identical(createForuiUiAdapter(), foruiUiAdapter), isTrue, reason: 'the adapter is const');
    });

    test('the package exports a localization delegate forUI needs (§14)', () {
      expect(foruiLocalizationsDelegates, hasLength(1));
    });
  });
}
