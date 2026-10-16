import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_macos/src/adapter/macos_capabilities.dart';
import 'package:live_uikit_macos/src/adapter/macos_surfaces.dart';
import 'package:live_uikit_macos/src/theme/macos_theme_mapper.dart';
import 'package:live_uikit_macos/src/widgets/macos_app_bar_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_button_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_card_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_checkbox_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_dialog_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_host_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_list_row_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_nav_bar_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_progress_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_scaffold_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_segmented_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_select_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_shell_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_slider_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_switch_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_tab_bar_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_tab_view_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_text_field_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_toast_builder.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// macOS — the `macos_ui` design-language adapter (§1).
///
/// Implements the core contract for [LiveDesignLanguage.macos]: theme mapping
/// delegates to `theme/`, each control to its `widgets/` builder, and the
/// declared [capabilities] to `macos_capabilities.dart`. Eleven of the seventeen
/// controls are the library's own widget; the six the library does not carry in
/// this shape — the card, the tab strip, the destination strip, the toast surface,
/// the dialog surface whose actions the library's alert cannot take, and the page
/// switcher under the strip — are assembled from its parts, and each builder says
/// which. It owns both structural
/// surfaces: `MacosApp` as the host and the library's `SidebarItems` list, in a
/// column of the shell's own, as the shell — the page frame stays with `scaffold`.
/// macOS widgets reuse the core's Material/Cupertino localization, so this package
/// adds no delegates.
///
/// Two of those assemblies are the adapter's own, because they are the shapes the
/// library refuses to build: a slider with nothing to drag and a selection that
/// names no item — see [slider] and [select].
class MacosLanguageAdapter extends SharedLanguageAdapter {
  /// The macOS adapter.
  const new();

  static const MacosThemeMapper _theme = MacosThemeMapper();

  /// The diameter of the thumb [slider] draws for a dead slider.
  ///
  /// `MacosSlider` keeps its own thumb (`_ContinuousThumb`) private, so the
  /// static form reuses the library's published thumb colour at the size the
  /// continuous macOS control is drawn at.
  static const double inertThumbSize = 12;

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.macos;

  @override
  String get id => 'macos';

  @override
  String get displayName => 'macOS';

  @override
  LiveUiCapabilities get capabilities => macosCapabilities;

  @override
  LiveUiSurfaceCapabilities get surfaces => macosSurfaces;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => MacosButtonBuilder.build(context, spec, this);

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => MacosCardBuilder.build(context, spec);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => MacosTextFieldBuilder.build(context, spec);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => MacosSwitchBuilder.build(context, spec);

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => MacosCheckboxBuilder.build(context, spec, this);

  /// The slider, or its inert form.
  ///
  /// `macos_ui` has no dead slider: `MacosSlider.onChanged` is a required,
  /// non-nullable callback, so a spec with no callback (or `enabled: false`) is
  /// one the library cannot build at all, and a closure that swallowed the value
  /// would leave a control that still moves under the pointer. It is drawn here
  /// out of the library's own static parts instead — its determinate rail,
  /// `macos.ProgressBar` (a track with a filled portion, inert by construction,
  /// whose value is a percentage) in the token's primary, and the thumb in the
  /// library's published `MacosColors.sliderThumbColor`, parked at the value's
  /// fraction under an `IgnorePointer`. Same rail-and-thumb reading, nothing to
  /// drag, and no shared floor to hand the spec to (§9/§15).
  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) {
    if (spec.enabled && spec.onChanged != null) {
      return MacosSliderBuilder.build(context, spec);
    }
    return _inertSlider(context, spec);
  }

  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) => MacosSegmentedBuilder.build(context, spec);

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => MacosProgressBuilder.build(context, spec);

  /// The pop-up select, fed only the selection the library can carry.
  ///
  /// `MacosPopupButton` asserts that its current value matches exactly one of its
  /// items. A value the list does not carry is not such a selection — and it is
  /// not a crash waiting to happen either: measured on 2.2.2, that assert
  /// short-circuits while `value == null`, which is the library's own *nothing
  /// chosen* state, the one whose slot [LanguageSelectSpec.placeholder] already
  /// rides in as the button's `hint`. So the off-list value is dropped to null —
  /// the field shows the placeholder and the value is not treated as legal — and
  /// the menu keeps only choosable values, dropping null and repeated item values
  /// for the same "exactly one" reason (§15: no shared floor).
  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) =>
      MacosSelectBuilder.build<T>(context, _chosenOrNull(spec));

  @override
  Widget tabBar(BuildContext context, LanguageTabsSpec spec) => MacosTabBarBuilder.build(context, spec);

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => MacosScaffoldBuilder.build(context, spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => MacosAppBarBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => MacosListRowBuilder.build(context, spec);

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) => MacosNavBarBuilder.build(context, spec);

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => MacosToastBuilder.build(context, spec);

  @override
  Widget dialog(BuildContext context, LanguageDialogSpec spec) => MacosDialogBuilder.build(context, spec);

  @override
  Widget tabView(BuildContext context, LanguageTabViewSpec spec) => MacosTabViewBuilder.build(context, spec);

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) => MacosHostBuilder.build(context, spec);

  @override
  Widget shell(BuildContext context, LanguageShellSpec spec) => MacosShellBuilder.build(context, spec);

  /// The dead slider described on [slider]: [macos.ProgressBar]'s rail with the
  /// library's thumb colour at [inertThumbSize], unable to report a value.
  static Widget _inertSlider(BuildContext context, LanguageSliderSpec spec) {
    final theme = LiveTheme.of(context);
    final fraction = _fraction(spec);
    return IgnorePointer(
      child: Semantics(
        slider: true,
        value: spec.value.toStringAsFixed(2),
        child: SizedBox(
          height: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The rail needs a width to divide; an unbounded parent gets the
              // library's own minimum slider width rather than an infinite track.
              var width = constraints.maxWidth;
              if (!constraints.hasBoundedWidth) {
                width = 200;
              }
              final travel = width - inertThumbSize;
              return SizedBox(
                width: width,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: inertThumbSize / 2),
                      child: macos.ProgressBar(
                        value: fraction * 100,
                        height: 4,
                        trackColor: theme.colors.primary,
                        backgroundColor: theme.colors.fillSecondary,
                      ),
                    ),
                    Positioned(
                      left: (travel * fraction).clamp(0.0, travel),
                      child: Container(
                        width: inertThumbSize,
                        height: inertThumbSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: macos.MacosDynamicColor.resolve(macos.MacosColors.sliderThumbColor, context),
                          border: Border.all(color: theme.colors.border),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The spec's value as the fraction of its range the rail shows.
  static double _fraction(LanguageSliderSpec spec) {
    final span = spec.max - spec.min;
    if (span <= 0) {
      return 0;
    }
    return ((spec.value - spec.min) / span).clamp(0.0, 1.0);
  }

  /// [spec] rewritten so the library's assert is satisfied: the values it can
  /// actually carry (non-null, one of each) and a current value that is either a
  /// member of that list or nothing at all.
  static LanguageSelectSpec<T> _chosenOrNull<T>(LanguageSelectSpec<T> spec) {
    final items = <T>[];
    for (final item in spec.items) {
      if (item != null && !items.contains(item)) {
        items.add(item);
      }
    }
    return LanguageSelectSpec<T>(
      items: items,
      itemLabel: spec.itemLabel,
      onChanged: spec.onChanged,
      value: spec.value != null && items.contains(spec.value) ? spec.value : null,
      placeholder: spec.placeholder,
      enabled: spec.enabled,
    );
  }
}
