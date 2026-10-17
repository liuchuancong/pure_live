import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_material/live_uikit_material.dart';

/// The Material UI adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `MaterialLanguageAdapter`
/// overrides with `material_ui` widgets, and its surfaces exactly the two it owns:
/// the resolver raises a `LiveUiCapabilityException` for a declaration with no
/// override behind it, so drift between the sets and the methods is caught here
/// before it ships (§17).
void main() {
  const adapter = materialAdapter;

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
    LiveUiControl.tabView,
    LiveUiControl.dialog,
    LiveUiControl.scaffold,
    LiveUiControl.appBar,
    LiveUiControl.listRow,
    LiveUiControl.navBar,
    LiveUiControl.toast,
  };

  test('declares exactly the surfaces it owns structurally', () {
    const owned = <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell};
    for (final surface in owned) {
      expect(adapter.surfaces.supports(surface), isTrue, reason: '$surface should be native');
    }
    for (final surface in LiveUiSurface.values.toSet().difference(owned)) {
      expect(adapter.surfaces.supports(surface), isFalse, reason: '$surface should fall back');
    }
  });

  group('Material UI adapter contract (§7)', () {
    test('exposes a stable id, display name and language', () {
      expect(adapter.id, materialAdapterId);
      expect(adapter.id, 'material');
      expect(adapter.displayName, 'Material UI');
      expect(adapter.language, LiveDesignLanguage.material);
    });

    test('declares exactly the controls it renders natively', () {
      for (final control in native) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control should be native');
      }
      // The other half of the point: this language serves the whole contract, so
      // the set above has to be every member of the enum and not merely a subset.
      expect(adapter.capabilities.supported, LiveUiControl.values.toSet());
    });
  });

  group('Material UI resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(adapters: {LiveDesignLanguage.material: adapter});
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to the native adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.material).id, 'material');
    });

    test('a registered language resolves to this adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.material).id, 'material');
    });

    test('every control of the contract resolves to this adapter, with no diagnostic', () {
      final adapter = resolver.resolve(LiveDesignLanguage.material);
      for (final control in LiveUiControl.values) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control');
        resolver.requireControl(LiveDesignLanguage.material, control);
      }
    });

    test('a language this build did not register raises instead of degrading', () {
      expect(() => resolver.resolve(LiveDesignLanguage.fluent), throwsA(isA<LiveUiResolutionException>()));
    });
  });
}
