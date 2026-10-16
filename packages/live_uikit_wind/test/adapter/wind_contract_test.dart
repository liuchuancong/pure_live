import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_wind/live_uikit_wind.dart';

/// The Wind adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `WindLanguageAdapter`
/// overrides with `fluttersdk_wind`'s own parts — mapped where the library has a
/// widget for the job, composed where it does not; the resolver turns every other
/// control into a `controlUnsupported` downgrade, so drift between the declaration
/// and the overrides is caught here before it ships (§17).
void main() {
  const adapter = windAdapter;

  group('Wind adapter contract (§7)', () {
    test('exposes a stable id, display name and language', () {
      expect(adapter.id, windAdapterId);
      expect(adapter.id, 'wind');
      expect(adapter.displayName, 'Wind');
      expect(adapter.language, LiveDesignLanguage.wind);
    });

    test('declares exactly the controls it renders natively', () {
      // All fifteen: Wind renders every control, and the nine whose library has
      // no widget for the job say so in their builder (§9).
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
      // Derived rather than listed, so a control added to the contract cannot join
      // the fallback side silently — the suite has to be told (§17).
      for (final control in LiveUiControl.values.toSet().difference(native)) {
        expect(adapter.capabilities.supports(control), isFalse, reason: '$control should fall back');
      }
      // The other half of the point: this language has no fallback side at all, so
      // the set above has to be the whole contract.
      expect(adapter.capabilities.supported, LiveUiControl.values.toSet());
    });

    test('owns the app host and not the shell in this build', () {
      // The library ships no application widget, so the host is this adapter's
      // `WidgetsApp` under a `WindTheme` scope; the shell is still the core's,
      // and the declaration has to say exactly that (§ surfaces).
      expect(adapter.surfaces.supported, {LiveUiSurface.appHost});
      expect(adapter.surfaces.supports(LiveUiSurface.appShell), isFalse);
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

    test('every control of the contract resolves native, with no downgrade', () {
      for (final control in LiveUiControl.values) {
        final result = resolver.resolveControl(LiveDesignLanguage.wind, control);
        expect(result.implementation.kind, LiveImplementationKind.adapterNative, reason: '$control');
        expect(result.diagnostic, isNull, reason: '$control');
      }
    });

    test('a language this build did not register still resolves shared, and says so', () {
      final result = resolver.resolveControl(LiveDesignLanguage.neumorphic, LiveUiControl.slider);
      expect(result.implementation.kind, LiveImplementationKind.shared);
      expect(result.diagnostic?.code, LiveUiDiagnosticCode.adapterMissing);
    });
  });
}
