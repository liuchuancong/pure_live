import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';

void main() {
  const adapter = fluentAdapter;

  test('declares exactly the surfaces it owns structurally', () {
    for (final surface in const <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell}) {
      expect(adapter.surfaces.supports(surface), isTrue, reason: '$surface should be native');
    }
    for (final surface in LiveUiSurface.values.toSet().difference(const <LiveUiSurface>{
      LiveUiSurface.appHost,
      LiveUiSurface.appShell,
    })) {
      expect(adapter.surfaces.supports(surface), isFalse, reason: '$surface should fall back');
    }
  });

  group('Fluent adapter contract (§7)', () {
    test('exposes a stable id and display name', () {
      expect(adapter.id, fluentAdapterId);
      expect(adapter.id, 'fluent');
      expect(adapter.displayName, 'Fluent');
    });

    test('declares exactly the controls it renders natively', () {
      // All seventeen: Fluent renders every control, and the five without a
      // one-for-one library widget say so in their builder (§9).
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
      // Derived rather than listed, so a control added to the contract cannot
      // join the undeclared side silently — the suite has to be told (§17).
      for (final control in LiveUiControl.values.toSet().difference(native)) {
        expect(adapter.capabilities.supports(control), isFalse, reason: '$control should fall back');
      }
      // The other half of the point: this language declares no gap at all, so the
      // set above has to be the whole contract.
      expect(adapter.capabilities.supported, LiveUiControl.values.toSet());
    });
  });

  group('Fluent resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(adapters: {LiveDesignLanguage.fluent: adapter});
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to this adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.fluent).id, 'fluent');
    });

    test('every control of the contract resolves to this adapter, with no diagnostic', () {
      final adapter = resolver.resolve(LiveDesignLanguage.fluent);
      for (final control in LiveUiControl.values) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control');
        resolver.requireControl(LiveDesignLanguage.fluent, control);
      }
    });

    test('a language this build did not register raises instead of degrading', () {
      expect(() => resolver.resolve(LiveDesignLanguage.glass), throwsA(isA<LiveUiResolutionException>()));
    });
  });
}
