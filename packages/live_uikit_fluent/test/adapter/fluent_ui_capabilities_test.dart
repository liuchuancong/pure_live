import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';

void main() {
  const adapter = fluentUiAdapter;

  group('Fluent adapter contract (§7)', () {
    test('exposes a stable id and display name', () {
      expect(adapter.id, fluentUiAdapterId);
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
      };
      for (final control in native) {
        expect(adapter.capabilities.supports(control), isTrue, reason: '$control should be native');
      }
      // Controls fluent_ui has no matching widget for fall back to the shared
      // renderer (no segmented control; `TabView` is a whole tab view, not a strip).
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
