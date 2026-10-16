import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';

/// A stand-in for a package adapter: a distinct native implementation whose
/// only job is to be registered under a language (§15.6 kind reproduction).
class _FakeNativeAdapter extends SharedLanguageAdapter {
  const new();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.macos;
}

void main() {
  const shared = SharedLanguageAdapter();
  const native = _FakeNativeAdapter();

  group('LiveUiResolver (§15.3)', () {
    test('resolves a registered language to its native adapter, no diagnostic', () {
      const registry = LanguageRegistry(adapters: {LiveDesignLanguage.macos: native}, fallback: shared);
      const resolver = LiveUiResolver(registry: registry);

      final resolution = resolver.resolve(LiveDesignLanguage.macos);

      expect(resolution.implementation.adapter, same(native));
      expect(resolution.implementation.kind, LiveImplementationKind.adapterNative);
      expect(resolution.diagnostic, isNull);
    });

    test('downgrades an unregistered language to shared and records why', () {
      const registry = LanguageRegistry(adapters: {}, fallback: shared);
      const resolver = LiveUiResolver(registry: registry);

      final resolution = resolver.resolve(LiveDesignLanguage.glass);

      expect(resolution.implementation.adapter, same(shared));
      expect(resolution.implementation.kind, LiveImplementationKind.shared);
      expect(resolution.diagnostic?.code, LiveUiDiagnosticCode.adapterMissing);
      expect(resolution.diagnostic?.language, LiveDesignLanguage.glass);
      expect(resolution.diagnostic?.kind, LiveImplementationKind.shared);
    });

    test('a fail-fast policy throws rather than render a silent blank', () {
      const registry = LanguageRegistry(adapters: {}, fallback: shared);
      const resolver = LiveUiResolver(
        registry: registry,
        policy: LiveUiFallbackPolicy(onMissingAdapter: LiveUiFallbackAction.failFast),
      );

      expect(() => resolver.resolve(LiveDesignLanguage.wind), throwsA(isA<LiveUiResolutionException>()));
    });
  });
}
