import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_cupertino/live_uikit_cupertino.dart';

/// The Cupertino UI adapter's contract and capability declarations (§7/§16/§17).
///
/// The capability set must list exactly the controls `CupertinoLanguageAdapter`
/// overrides with native `cupertino_ui` widgets; the resolver turns every other
/// control into a `controlUnsupported` downgrade, so drift between the declaration
/// and the overrides is caught here before it ships (§17).
void main() {
  const adapter = cupertinoAdapter;

  const native = {
    LiveUiControl.button,
    LiveUiControl.textField,
    LiveUiControl.switchWidget,
    LiveUiControl.slider,
    LiveUiControl.scaffold,
    LiveUiControl.appBar,
    LiveUiControl.listRow,
    LiveUiControl.navBar,
  };
  // Derived rather than listed, so a control added to the contract cannot join the
  // fallback side silently — the suite has to be told (§17).
  final fallback = LiveUiControl.values.toSet().difference(native);

  test('declares exactly the surfaces it owns structurally', () {
    for (final surface in const <LiveUiSurface>{LiveUiSurface.appHost}) {
      expect(adapter.surfaces.supports(surface), isTrue, reason: '$surface should be native');
    }
    for (final surface in LiveUiSurface.values.toSet().difference(const <LiveUiSurface>{LiveUiSurface.appHost})) {
      expect(adapter.surfaces.supports(surface), isFalse, reason: '$surface should fall back');
    }
  });

  group('Cupertino UI adapter contract (§7)', () {
    test('exposes a stable id, display name and language', () {
      expect(adapter.id, cupertinoAdapterId);
      expect(adapter.id, 'cupertino');
      expect(adapter.displayName, 'Cupertino UI');
      expect(adapter.language, LiveDesignLanguage.cupertino);
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

  group('Cupertino UI resolution through the core resolver (§15.3)', () {
    const registry = LanguageRegistry(
      adapters: {LiveDesignLanguage.cupertino: adapter},
      fallback: SharedLanguageAdapter(),
    );
    const resolver = LiveUiResolver(registry: registry);

    test('a registered language resolves to the native adapter', () {
      expect(resolver.resolve(LiveDesignLanguage.cupertino).implementation.kind, LiveImplementationKind.adapterNative);
    });

    test('a declared control resolves native with no diagnostic', () {
      final result = resolver.resolveControl(LiveDesignLanguage.cupertino, LiveUiControl.button);
      expect(result.implementation.kind, LiveImplementationKind.adapterNative);
      expect(result.diagnostic, isNull);
    });

    test('an undeclared control falls back to shared and is reported', () {
      final result = resolver.resolveControl(LiveDesignLanguage.cupertino, LiveUiControl.card);
      expect(result.implementation.kind, LiveImplementationKind.shared);
      expect(result.diagnostic?.code, LiveUiDiagnosticCode.controlUnsupported);
      expect(result.diagnostic?.control, LiveUiControl.card);
    });
  });
}
