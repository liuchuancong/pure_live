import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_forui/live_uikit_forui.dart';

/// The ForUI adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `ForuiLanguageAdapter` overrides
/// with `forui`'s own widgets; a control the adapter declares without overriding turns
/// into a capability exception, so drift between the declaration and the overrides is
/// caught here before it ships (§17). This language declares the whole contract, so the
/// drift this suite guards is now a control that silently *stops* being native.
void main() {
  const adapter = foruiAdapter;

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
  // Derived rather than listed, so a control added to the contract cannot join
  // the undeclared side silently — the suite has to be told, and that is the
  // point of the assertion (§17).
  final fallback = LiveUiControl.values.toSet().difference(native);

  group('ForUI adapter contract (§7)', () {
    test('exposes a stable id, display name and language', () {
      expect(adapter.id, foruiAdapterId);
      expect(adapter.id, 'forui');
      expect(adapter.displayName, 'ForUI');
      expect(adapter.language, LiveDesignLanguage.forui);
    });

    test('declares exactly the surfaces it owns structurally', () {
      // Both sides of the pair now: `WidgetsApp` under `FTheme` for the host,
      // and `FSidebar` — which needs nothing above that theme and never paints
      // a body of its own — for the shell (§ surfaces).
      const owned = <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell};
      for (final surface in owned) {
        expect(adapter.surfaces.supports(surface), isTrue, reason: '$surface should be native');
      }
      for (final surface in LiveUiSurface.values.toSet().difference(owned)) {
        expect(adapter.surfaces.supports(surface), isFalse, reason: '$surface should fall back');
      }
      // Derived, so a surface added to the contract cannot join the unowned side
      // silently — the same rule as the control set below (§17).
      expect(adapter.surfaces.supported, LiveUiSurface.values.toSet());
    });

    test('declares exactly the controls it renders natively', () {
      // All seventeen: fourteen map one-for-one onto a `forui` widget of their own, and
      // the three that do not are composed from the library's own parts or from the
      // widgets layer (§9).
      for (final control in native) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control should be native');
      }
      for (final control in fallback) {
        expect(adapter.capabilities.supports(control), isFalse, reason: '$control should fall back');
      }
      // The other half of the point: this language leaves nothing in the contract
      // undeclared, so the set above has to be the whole contract.
      expect(adapter.capabilities.supported, LiveUiControl.values.toSet());
    });
  });

  group('ForUI resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(adapters: {LiveDesignLanguage.forui: adapter});
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to the native adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.forui).id, 'forui');
    });

    test('a registered language resolves to this adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.forui).id, 'forui');
    });

    test('every control of the contract resolves to this adapter, with no diagnostic', () {
      final adapter = resolver.resolve(LiveDesignLanguage.forui);
      for (final control in LiveUiControl.values) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control');
        resolver.requireControl(LiveDesignLanguage.forui, control);
      }
    });

    test('a language this build did not register raises instead of degrading', () {
      expect(() => resolver.resolve(LiveDesignLanguage.fluent), throwsA(isA<LiveUiResolutionException>()));
    });
  });

  group('registration surface (§10)', () {
    test('the const instance and the factory hand back the same adapter', () {
      expect(createForuiAdapter().id, foruiAdapterId);
      expect(identical(createForuiAdapter(), foruiAdapter), isTrue, reason: 'the adapter is const');
    });

    test('the package exports a localization delegate forUI needs (§14)', () {
      expect(foruiLocalizationsDelegates, hasLength(1));
    });
  });
}
