import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';

/// The adapter receives what the icon button means (§11): a spec, not a painting.
class _RecordingAdapter extends SharedLanguageAdapter {
  const new({this.native = const <LiveUiControl>{}});

  final Set<LiveUiControl> native;

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.materialUi;

  @override
  String get id => 'recording';

  @override
  String get displayName => 'Recording';

  @override
  LiveUiCapabilities get capabilities => LiveUiCapabilities(native);

  static LanguageButtonSpec? last;

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) {
    last = spec;
    return const SizedBox.shrink();
  }
}

void main() {
  const providerRegistry = LanguageRegistry(
    adapters: {LiveDesignLanguage.materialUi: _RecordingAdapter()},
    fallback: SharedLanguageAdapter(),
  );

  // A real app shell: the tooltip the renderer wraps needs an Overlay, and the
  // text direction comes with the MaterialApp rather than being asserted by hand.
  Widget harness(Widget child, {UiConfig? config}) => LiveConfigProvider(
    config: config ?? const UiConfig(language: LiveDesignLanguage.materialUi),
    registry: providerRegistry,
    child: MaterialApp(home: Scaffold(body: child)),
  );

  group('LiveIconButton dispatches through the adapter (§11/ADR 0004)', () {
    testWidgets('the spec carries the icon-only intent, not a painted box', (tester) async {
      _RecordingAdapter.last = null;
      await tester.pumpWidget(
        harness(
          LiveIconButton(
            icon: Icons.favorite,
            tooltip: 'Favourite',
            selected: true,
            size: ControlSize.lg,
            onPressed: () {},
          ),
        ),
      );

      final spec = _RecordingAdapter.last;
      expect(spec, isNotNull);
      expect(spec!.iconOnly, isTrue);
      expect(spec.label, isEmpty, reason: 'an empty label is the contract; iconOnly says do not paint it');
      expect(spec.icon, Icons.favorite);
      expect(spec.tooltip, 'Favourite');
      expect(spec.selected, isTrue);
      expect(spec.size, ControlSize.lg);
      expect(spec.variant, ButtonVariant.ghost);
      expect(spec.enabled, isTrue);
    });

    testWidgets('a null callback still disables it, and `enabled: false` too', (tester) async {
      _RecordingAdapter.last = null;
      await tester.pumpWidget(harness(const LiveIconButton(icon: Icons.share, tooltip: 'Share')));
      expect(_RecordingAdapter.last!.enabled, isFalse);

      await tester.pumpWidget(
        harness(LiveIconButton(icon: Icons.share, tooltip: 'Share', enabled: false, onPressed: () {})),
      );
      expect(_RecordingAdapter.last!.enabled, isFalse);
    });

    testWidgets('the token renderer draws glyph, name and square — no text', (tester) async {
      // The default language is the shared token base, so this is the renderer
      // the adapters are required to agree with.
      await tester.pumpWidget(
        harness(
          LiveIconButton(key: const Key('icon-button'), icon: Icons.favorite, tooltip: 'Favourite', onPressed: () {}),
          config: const UiConfig(),
        ),
      );

      expect(find.byType(Icon), findsOneWidget);
      expect(find.byType(Text), findsNothing, reason: 'the empty label must never reach the screen');
      expect(find.byType(Tooltip), findsOneWidget);

      // The square comes from the icon-only branch, sized by the md height step.
      final sized = tester
          .widgetList<SizedBox>(find.ancestor(of: find.byType(LiveBox), matching: find.byType(SizedBox)))
          .toList();
      final theme = LiveTheme.of(tester.element(find.byKey(const Key('icon-button'))));
      expect(sized.any((box) => box.width == theme.button.controlHeight), isTrue);
      expect(sized.any((box) => box.height == theme.button.controlHeight), isTrue);
    });

    testWidgets('the accessible name survives as the icon semantics label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          LiveIconButton(icon: Icons.favorite, tooltip: 'Favourite', onPressed: () {}),
          config: const UiConfig(),
        ),
      );
      expect(
        tester.getSemantics(find.byType(Icon)).getSemanticsData().label,
        contains('Favourite'),
        reason: 'an icon with no text still has to say what it does',
      );
      handle.dispose();
    });

    testWidgets('selected paints the primary foreground (§2.3)', (tester) async {
      late LiveBox rendered;
      await tester.pumpWidget(
        harness(
          LiveIconButton(icon: Icons.favorite, tooltip: 'Favourite', selected: true, onPressed: () {}),
          config: const UiConfig(),
        ),
      );
      rendered = tester.widget<LiveBox>(find.byType(LiveBox));
      final theme = LiveTheme.of(tester.element(find.byType(LiveBox)));
      expect(rendered.style(InteractionState.normal).foreground, theme.colors.primary);
      expect(rendered.style(InteractionState.disabled).foreground, theme.colors.textDisabled);
    });
  });

  test('the recording adapter declares no native controls, so the spec still reaches it', () {
    // Guards the test double itself: `capabilities` is empty by default, which is
    // what makes `button` the override under observation rather than a fallback.
    expect(const _RecordingAdapter().capabilities.supports(LiveUiControl.button), isFalse);
    expect(const _RecordingAdapter(native: {LiveUiControl.button}).capabilities.supports(LiveUiControl.button), isTrue);
  });
}
