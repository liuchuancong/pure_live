import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_neumorphic/live_uikit_neumorphic.dart';

/// The Neumorphic adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `NeumorphicLanguageAdapter`
/// overrides with `flutter_neumorphic_ui_kit` widgets or with that library's own
/// primitives; the resolver turns every other control into a `controlUnsupported`
/// downgrade, so drift between the declaration and the overrides is caught here
/// before it ships (§17). This language declares the whole contract, so the drift
/// that matters is a control joining the fallback side silently.
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
    LiveUiControl.scaffold,
    LiveUiControl.appBar,
    LiveUiControl.listRow,
    LiveUiControl.navBar,
    LiveUiControl.toast,
  };

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
      // The other half of the point: this language has no fallback side at all, so
      // the set above has to be the whole contract — a control added to the
      // interface could not join the downgrade list without failing here (§17).
      expect(adapter.capabilities.supported, LiveUiControl.values.toSet());
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

    test('every control of the contract resolves native, with no downgrade', () {
      for (final control in LiveUiControl.values) {
        final result = resolver.resolveControl(LiveDesignLanguage.neumorphic, control);
        expect(result.implementation.kind, LiveImplementationKind.adapterNative, reason: '$control');
        expect(result.diagnostic, isNull, reason: '$control');
      }
    });

    test('a language this build did not register still resolves shared, and says so', () {
      // The fallback is a report, not a silent stand-in: only the language actually
      // registered here gets the Neumorphic path, and anything else is named as
      // missing rather than quietly drawn by the token base.
      final result = resolver.resolveControl(LiveDesignLanguage.fluent, LiveUiControl.scaffold);
      expect(result.implementation.kind, LiveImplementationKind.shared);
      expect(result.diagnostic?.code, LiveUiDiagnosticCode.adapterMissing);
    });
  });
}
