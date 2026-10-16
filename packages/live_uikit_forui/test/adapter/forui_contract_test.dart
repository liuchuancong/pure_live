import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_forui/live_uikit_forui.dart';

/// The ForUI adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `ForuiLanguageAdapter` overrides
/// with `forui`'s own widgets; the resolver turns every other control into a
/// `controlUnsupported` downgrade, so drift between the declaration and the overrides is
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
  // the fallback side silently — the suite has to be told, and that is the
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
      // Derived, so a surface added to the contract cannot join the fallback
      // side silently — the same rule as the control set below (§17).
      expect(adapter.surfaces.supported, LiveUiSurface.values.toSet());
    });

    test('declares exactly the controls it renders natively', () {
      // All seventeen: forui 0.27.5 carries a widget for every control the contract
      // names but one, and the controls it lacks are composed from its own parts or
      // from the widgets layer (§9).
      for (final control in native) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control should be native');
      }
      for (final control in fallback) {
        expect(adapter.capabilities.supports(control), isFalse, reason: '$control should fall back');
      }
      // The other half of the point: this language has no fallback side at all,
      // so the set above has to be the whole contract.
      expect(adapter.capabilities.supported, LiveUiControl.values.toSet());
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

    test('every control of the contract resolves native, with no downgrade', () {
      for (final control in LiveUiControl.values) {
        final result = resolver.resolveControl(LiveDesignLanguage.forui, control);
        expect(result.implementation.kind, LiveImplementationKind.adapterNative, reason: '$control');
        expect(result.diagnostic, isNull, reason: '$control');
      }
    });

    test('a language this build did not register still resolves shared, and says so', () {
      final result = resolver.resolveControl(LiveDesignLanguage.glass, LiveUiControl.segmented);
      expect(result.implementation.kind, LiveImplementationKind.shared);
      expect(result.diagnostic?.code, LiveUiDiagnosticCode.adapterMissing);
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
