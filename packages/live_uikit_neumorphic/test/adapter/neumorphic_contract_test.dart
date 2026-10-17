import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_neumorphic/live_uikit_neumorphic.dart';

/// The Neumorphic adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `NeumorphicLanguageAdapter`
/// overrides with `flutter_neumorphic_ui_kit` widgets or with that library's own
/// primitives; `requireControl` raises a `LiveUiCapabilityException` for anything
/// declared without an override behind it, so drift between the declaration and the
/// methods is caught here before it ships (§17). This language declares the whole
/// contract, so the drift that matters is a control leaving that set silently.
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
    LiveUiControl.dialog,
    LiveUiControl.tabView,
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
      // The other half of the point: this language answers every control, so the set
      // above has to be the whole contract — a control added to the interface could
      // not go unhandled here without failing this expectation (§17).
      expect(adapter.capabilities.supported, LiveUiControl.values.toSet());
    });

    test('declares exactly the surfaces it owns structurally', () {
      const owned = <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell};
      for (final surface in owned) {
        expect(adapter.surfaces.supports(surface), isTrue, reason: '$surface should be native');
      }
      for (final surface in LiveUiSurface.values.toSet().difference(owned)) {
        expect(adapter.surfaces.supports(surface), isFalse, reason: '$surface should fall back');
      }
    });
  });

  group('Neumorphic resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(adapters: {LiveDesignLanguage.neumorphic: adapter});
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to the native adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.neumorphic).id, 'neumorphic');
    });

    test('a registered language resolves to this adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.neumorphic).id, 'neumorphic');
    });

    test('every control of the contract resolves to this adapter, with no diagnostic', () {
      final adapter = resolver.resolve(LiveDesignLanguage.neumorphic);
      for (final control in LiveUiControl.values) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control');
        resolver.requireControl(LiveDesignLanguage.neumorphic, control);
      }
    });

    test('a language this build did not register raises instead of degrading', () {
      expect(() => resolver.resolve(LiveDesignLanguage.fluent), throwsA(isA<LiveUiResolutionException>()));
    });
  });
}
