import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_wind/live_uikit_wind.dart';

/// The Wind adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `WindLanguageAdapter`
/// overrides with `fluttersdk_wind`'s own parts — mapped where the library has a
/// widget for the job, composed where it does not; the resolver turns every other
/// control into a a capability exception, so drift between the declaration
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
      // All seventeen: Wind renders every control, and the eleven whose library
      // has no widget for the job say so in their builder (§9).
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
        LiveUiControl.dialog,
        LiveUiControl.tabView,
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

    test('owns both structural surfaces in this build', () {
      // The library ships no application widget, so the host is this adapter's
      // `WidgetsApp` under a `WindTheme` scope; it ships no navigation structure
      // either, so the shell is the column `WindShellBuilder` composes out of its
      // styled parts. The declaration has to say exactly that (§ surfaces).
      expect(adapter.surfaces.supported, {LiveUiSurface.appHost, LiveUiSurface.appShell});
      for (final surface in LiveUiSurface.values.toSet().difference(adapter.surfaces.supported)) {
        expect(adapter.surfaces.supports(surface), isFalse, reason: '$surface should fall back');
      }
    });
  });

  group('Wind resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(adapters: {LiveDesignLanguage.wind: adapter});
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to the native adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.wind).id, 'wind');
    });

    test('a registered language resolves to this adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.wind).id, 'wind');
    });

    test('every control of the contract resolves to this adapter, with no diagnostic', () {
      final adapter = resolver.resolve(LiveDesignLanguage.wind);
      for (final control in LiveUiControl.values) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control');
        resolver.requireControl(LiveDesignLanguage.wind, control);
      }
    });

    test('a language this build did not register raises instead of degrading', () {
      expect(() => resolver.resolve(LiveDesignLanguage.fluent), throwsA(isA<LiveUiResolutionException>()));
    });
  });
}
