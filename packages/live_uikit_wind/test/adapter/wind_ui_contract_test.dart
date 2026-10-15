import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_wind/live_uikit_wind.dart';

/// The Wind adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `WindLanguageAdapter`
/// overrides with native `fluttersdk_wind` widgets; the resolver turns every other
/// control into a `controlUnsupported` downgrade, so drift between the declaration
/// and the overrides is caught here before it ships (§17).
void main() {
  const adapter = windUiAdapter;

  const native = {
    LiveUiControl.button,
    LiveUiControl.card,
    LiveUiControl.textField,
    LiveUiControl.switchWidget,
    LiveUiControl.checkbox,
    LiveUiControl.select,
  };
  const fallback = {LiveUiControl.slider, LiveUiControl.segmented, LiveUiControl.progress, LiveUiControl.tabBar};

  group('Wind adapter contract (§7)', () {
    test('exposes a stable id, display name and language', () {
      expect(adapter.id, windUiAdapterId);
      expect(adapter.id, 'wind');
      expect(adapter.displayName, 'Wind');
      expect(adapter.language, LiveDesignLanguage.wind);
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

  group('Wind resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(adapters: {LiveDesignLanguage.wind: adapter}, fallback: SharedLanguageAdapter());
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to the native adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.wind).implementation.kind, LiveImplementationKind.adapterNative);
    });

    test('a declared control resolves native with no diagnostic', () {
      final result = resolver.resolveControl(LiveDesignLanguage.wind, LiveUiControl.button);
      expect(result.implementation.kind, LiveImplementationKind.adapterNative);
      expect(result.diagnostic, isNull);
    });

    test('an undeclared control falls back to shared and is reported', () {
      final result = resolver.resolveControl(LiveDesignLanguage.wind, LiveUiControl.slider);
      expect(result.implementation.kind, LiveImplementationKind.shared);
      expect(result.diagnostic?.code, LiveUiDiagnosticCode.controlUnsupported);
      expect(result.diagnostic?.control, LiveUiControl.slider);
    });
  });
}
