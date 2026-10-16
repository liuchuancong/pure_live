import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
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
      const native = {
        LiveUiControl.button,
        LiveUiControl.card,
        LiveUiControl.textField,
        LiveUiControl.switchWidget,
        LiveUiControl.checkbox,
        LiveUiControl.slider,
        LiveUiControl.progress,
        LiveUiControl.select,
        LiveUiControl.scaffold,
        LiveUiControl.listRow,
        LiveUiControl.toast,
      };
      for (final control in native) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control should be native');
      }
      // Derived rather than listed, so a control added to the contract cannot
      // join the fallback side silently — the suite has to be told (§17).
      for (final control in LiveUiControl.values.toSet().difference(native)) {
        expect(adapter.capabilities.supports(control), isFalse, reason: '$control should fall back');
      }
      // Named because they are the two a reader expects Fluent to have: it has
      // no single-choice segmented track, and its `TabView` is a whole tab view,
      // not a strip.
      expect(adapter.capabilities.supports(LiveUiControl.segmented), isFalse);
      expect(adapter.capabilities.supports(LiveUiControl.tabBar), isFalse);
    });
  });

  group('Fluent resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(
      adapters: {LiveDesignLanguage.fluent: adapter},
      fallback: SharedLanguageAdapter(),
    );
    const resolver = LiveUiResolver(registry: registry);

    test('a declared control resolves native with no diagnostic', () {
      final result = resolver.resolveControl(LiveDesignLanguage.fluent, LiveUiControl.button);
      expect(result.implementation.kind, LiveImplementationKind.adapterNative);
      expect(result.diagnostic, isNull);
    });

    test('an undeclared control falls back to shared and is reported', () {
      final result = resolver.resolveControl(LiveDesignLanguage.fluent, LiveUiControl.segmented);
      expect(result.implementation.kind, LiveImplementationKind.shared);
      expect(result.diagnostic?.code, LiveUiDiagnosticCode.controlUnsupported);
      expect(result.diagnostic?.control, LiveUiControl.segmented);
    });
  });
}
