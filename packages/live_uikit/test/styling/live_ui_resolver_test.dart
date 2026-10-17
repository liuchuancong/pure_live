import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';

/// A language adapter that renders nothing of its own: a resolver test asserts
/// *which* adapter is chosen and what it declares, never what it paints. The
/// control set and the surface set are constructor arguments so one stub can be
/// both a full declaration and a deliberately partial one (§17).
class _StubAdapter implements LanguageAdapter {
  const new({
    required this.language,
    required this.id,
    this.controls = const <LiveUiControl>{},
    this.ownedSurfaces = const <LiveUiSurface>{},
  });

  @override
  final LiveDesignLanguage language;

  @override
  final String id;

  final Set<LiveUiControl> controls;
  final Set<LiveUiSurface> ownedSurfaces;

  @override
  String get displayName => 'Stub $id';

  @override
  LiveUiCapabilities get capabilities => LiveUiCapabilities(controls);

  @override
  LiveUiSurfaceCapabilities get surfaces => LiveUiSurfaceCapabilities(ownedSurfaces);

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => child;

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => const SizedBox.shrink();

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => spec.child;

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => const SizedBox.shrink();

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => const SizedBox.shrink();

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => const SizedBox.shrink();

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) => const SizedBox.shrink();

  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) => const SizedBox.shrink();

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => const SizedBox.shrink();

  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) => const SizedBox.shrink();

  @override
  Widget tabBar(BuildContext context, LanguageTabsSpec spec) => const SizedBox.shrink();

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => spec.body;

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => Text(spec.title, textDirection: TextDirection.ltr);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => Text(spec.title, textDirection: TextDirection.ltr);

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) => const SizedBox.shrink();

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => Text(spec.message, textDirection: TextDirection.ltr);

  @override
  Widget dialog(BuildContext context, LanguageDialogSpec spec) => spec.content ?? const SizedBox.shrink();

  @override
  Widget tabView(BuildContext context, LanguageTabViewSpec spec) =>
      spec.pages.isEmpty ? const SizedBox.shrink() : spec.pages[spec.index];

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) =>
      spec.builder?.call(context, const SizedBox.shrink()) ?? const SizedBox.shrink();

  @override
  Widget shell(BuildContext context, LanguageShellSpec spec) => spec.child;
}

void main() {
  const macos = _StubAdapter(language: LiveDesignLanguage.macos, id: 'macos');
  const glass = _StubAdapter(language: LiveDesignLanguage.glass, id: 'glass');
  const registry = LanguageRegistry(adapters: {LiveDesignLanguage.macos: macos, LiveDesignLanguage.glass: glass});
  const resolver = LiveUiResolver(registry: registry);

  group('LiveUiResolver.resolve (§15.3)', () {
    test('a registered language gets its own adapter, not another one', () {
      expect(resolver.resolve(LiveDesignLanguage.macos), same(macos));
      expect(resolver.resolve(LiveDesignLanguage.glass), same(glass));
      expect(registry.isRegistered(LiveDesignLanguage.macos), isTrue);
      expect(registry.adapterFor(LiveDesignLanguage.glass), same(glass));
    });

    test('an unregistered language throws — there is no shared renderer to settle for', () {
      expect(registry.isRegistered(LiveDesignLanguage.wind), isFalse);
      expect(registry.adapterFor(LiveDesignLanguage.wind), isNull);
      expect(() => resolver.resolve(LiveDesignLanguage.wind), throwsA(isA<LiveUiResolutionException>()));
      expect(() => resolver.resolve(LiveDesignLanguage.wind), throwsA(isA<Exception>()));
    });

    test('the thrown exception names the language it could not serve', () {
      expect(
        () => resolver.resolve(LiveDesignLanguage.cupertino),
        throwsA(
          isA<LiveUiResolutionException>()
              .having((error) => error.language, 'language', LiveDesignLanguage.cupertino)
              .having((error) => error.toString(), 'message', contains('cupertino')),
        ),
      );
    });

    test('an empty registry faults for every language', () {
      const strict = LiveUiResolver(registry: LanguageRegistry(adapters: {}));
      for (final language in LiveDesignLanguage.values) {
        expect(() => strict.resolve(language), throwsA(isA<LiveUiResolutionException>()), reason: '$language');
      }
    });
  });

  group('LiveUiResolver.requireControl / requireSurface (§17)', () {
    // A stub that claims only part of the control set and one of the two
    // surfaces, so both a declaration and a gap can be asserted.
    const partial = _StubAdapter(
      language: LiveDesignLanguage.fluent,
      id: 'partial',
      controls: {LiveUiControl.button, LiveUiControl.scaffold},
      ownedSurfaces: {LiveUiSurface.appHost},
    );
    const checker = LiveUiResolver(registry: LanguageRegistry(adapters: {LiveDesignLanguage.fluent: partial}));

    test('every control inside the declaration is served without complaint', () {
      for (final control in partial.controls) {
        checker.requireControl(LiveDesignLanguage.fluent, control);
      }
      expect(partial.capabilities.supports(LiveUiControl.button), isTrue);
    });

    test('every control outside it is a capability fault naming language and control', () {
      final undeclared = LiveUiControl.values.toSet().difference(partial.controls);
      for (final control in undeclared) {
        expect(
          () => checker.requireControl(LiveDesignLanguage.fluent, control),
          throwsA(
            isA<LiveUiCapabilityException>()
                .having((error) => error.language, 'language', LiveDesignLanguage.fluent)
                .having((error) => error.control, 'control', control)
                .having((error) => error.surface, 'surface', isNull),
          ),
          reason: '$control sits outside the declaration, so claiming it would be drift (§17)',
        );
      }
    });

    test('a declared surface is served and an undeclared one faults', () {
      checker.requireSurface(LiveDesignLanguage.fluent, LiveUiSurface.appHost);
      expect(
        () => checker.requireSurface(LiveDesignLanguage.fluent, LiveUiSurface.appShell),
        throwsA(
          isA<LiveUiCapabilityException>()
              .having((error) => error.surface, 'surface', LiveUiSurface.appShell)
              .having((error) => error.language, 'language', LiveDesignLanguage.fluent)
              .having((error) => error.control, 'control', isNull),
        ),
      );
    });

    test('an unregistered language faults before its declarations are read', () {
      expect(
        () => checker.requireControl(LiveDesignLanguage.wind, LiveUiControl.button),
        throwsA(isA<LiveUiResolutionException>()),
      );
      expect(
        () => checker.requireSurface(LiveDesignLanguage.wind, LiveUiSurface.appHost),
        throwsA(isA<LiveUiResolutionException>()),
      );
    });

    test('the theme reads the very declaration the resolver asserts', () {
      // `LiveTheme.supports` is the runtime reading of the same set, so a page and
      // a CI gate cannot disagree about a language.
      expect(partial.capabilities.supports(LiveUiControl.button), isTrue);
      expect(partial.surfaces.supports(LiveUiSurface.appShell), isFalse);
    });
  });
}
