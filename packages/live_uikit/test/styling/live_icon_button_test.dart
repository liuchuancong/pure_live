import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';

/// The adapter receives what the icon button means (§11): a spec, not a painting.
/// Everything it is not asked about draws a neutral placeholder — there is no
/// shared floor left to inherit, so the contract is implemented in full.
class _RecordingAdapter implements LanguageAdapter {
  const new({this.native = const <LiveUiControl>{}});

  final Set<LiveUiControl> native;

  static LanguageButtonSpec? last;

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.material;

  @override
  String get id => 'recording';

  @override
  String get displayName => 'Recording';

  @override
  LiveUiCapabilities get capabilities => LiveUiCapabilities(native);

  @override
  LiveUiSurfaceCapabilities get surfaces => const LiveUiSurfaceCapabilities.none();

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => child;

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) {
    last = spec;
    return const SizedBox.shrink();
  }

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
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => const SizedBox.shrink();

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => const SizedBox.shrink();

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) => const SizedBox.shrink();

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => const SizedBox.shrink();

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
  const providerRegistry = LanguageRegistry(adapters: {LiveDesignLanguage.material: _RecordingAdapter()});

  // A real app shell: the text direction comes with the MaterialApp rather than
  // being asserted by hand, and the Scaffold gives the dispatched control a page.
  Widget harness(Widget child) => LiveConfigProvider(
    config: const UiConfig(language: LiveDesignLanguage.material),
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

    testWidgets('the size step travels with the spec, so the language squares it', (tester) async {
      // The geometry is no longer drawn by a core base: what the page owes the
      // adapter is the step, and nothing else.
      _RecordingAdapter.last = null;
      await tester.pumpWidget(
        harness(LiveIconButton(icon: Icons.share, tooltip: 'Share', size: ControlSize.sm, onPressed: () {})),
      );
      expect(_RecordingAdapter.last!.size, ControlSize.sm);
      expect(_RecordingAdapter.last!.iconOnly, isTrue);
    });
  });

  test('the recording adapter declares no native controls, so the spec still reaches it', () {
    // Guards the test double itself: `capabilities` is empty by default, which is
    // what makes `button` the override under observation rather than a claim
    // about what the language renders natively (§17).
    expect(const _RecordingAdapter().capabilities.supports(LiveUiControl.button), isFalse);
    expect(const _RecordingAdapter(native: {LiveUiControl.button}).capabilities.supports(LiveUiControl.button), isTrue);
  });
}
