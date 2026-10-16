import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_material/src/adapter/material_capabilities.dart';
import 'package:live_uikit_material/src/adapter/material_surfaces.dart';
import 'package:live_uikit_material/src/theme/material_theme_mapper.dart';
import 'package:live_uikit_material/src/widgets/material_app_bar_builder.dart';
import 'package:live_uikit_material/src/widgets/material_button_builder.dart';
import 'package:live_uikit_material/src/widgets/material_card_builder.dart';
import 'package:live_uikit_material/src/widgets/material_checkbox_builder.dart';
import 'package:live_uikit_material/src/widgets/material_dialog_builder.dart';
import 'package:live_uikit_material/src/widgets/material_host_builder.dart';
import 'package:live_uikit_material/src/widgets/material_list_row_builder.dart';
import 'package:live_uikit_material/src/widgets/material_nav_bar_builder.dart';
import 'package:live_uikit_material/src/widgets/material_progress_builder.dart';
import 'package:live_uikit_material/src/widgets/material_scaffold_builder.dart';
import 'package:live_uikit_material/src/widgets/material_segmented_builder.dart';
import 'package:live_uikit_material/src/widgets/material_select_builder.dart';
import 'package:live_uikit_material/src/widgets/material_shell_builder.dart';
import 'package:live_uikit_material/src/widgets/material_slider_builder.dart';
import 'package:live_uikit_material/src/widgets/material_switch_builder.dart';
import 'package:live_uikit_material/src/widgets/material_tab_bar_builder.dart';
import 'package:live_uikit_material/src/widgets/material_tab_view_builder.dart';
import 'package:live_uikit_material/src/widgets/material_text_field_builder.dart';
import 'package:live_uikit_material/src/widgets/material_toast_builder.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Material UI — the `material_ui` design-language adapter (§1).
///
/// A fork of Flutter's Material widgets, so it covers the whole contract with
/// the library's own widgets — the controls, the four chrome pieces, the app
/// host and the shell. Theme via `theme/`, each control via its `widgets/`
/// builder, [capabilities] via the capabilities file.
///
/// Three specs are drawn here rather than by a builder, because they are the
/// shapes the fork refuses to build: a slider that must not move, a destination
/// strip that cannot hold a selection and a value no item carries — see
/// [slider], [navBar] and [select].
class MaterialLanguageAdapter extends SharedLanguageAdapter {
  /// The adapter.
  const new();

  static const MaterialThemeMapper _theme = MaterialThemeMapper();

  /// The key of the inert slider [slider] draws, so a caller (and §16's tests)
  /// can tell it from the live `mu.Slider`.
  static const ValueKey<String> inertSliderKey = ValueKey<String>('material:inert-slider');

  /// The key of the inert destination strip [navBar] draws, so a caller (and
  /// §16's tests) can tell it from the live `mu.NavigationBar`.
  static const ValueKey<String> inertNavBarKey = ValueKey<String>('material:inert-nav-bar');

  /// The diameter of the thumb drawn on the inert slider, the standard Material
  /// thumb size — the fork's own thumb shape is only reachable through the live
  /// widget's state, which is the thing that cannot build.
  static const double inertThumbSize = 20;

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.material;

  @override
  String get id => 'material';

  @override
  String get displayName => 'Material UI';

  @override
  LiveUiCapabilities get capabilities => materialCapabilities;

  @override
  LiveUiSurfaceCapabilities get surfaces => materialSurfaces;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => MaterialButtonBuilder.build(context, spec, this);

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => MaterialCardBuilder.build(context, spec);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => MaterialTextFieldBuilder.build(context, spec);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => MaterialSwitchBuilder.build(context, spec);

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) =>
      MaterialCheckboxBuilder.build(context, spec, this);

  /// The slider, or its inert form.
  ///
  /// A dead slider is the one case `material_ui` cannot build: 1.6.0 reads
  /// `widget.focusNode ?? _focusNode!`, and `_focusNode` is only created for an
  /// interactive slider, so `mu.Slider(onChanged: null)` — and `enabled: false`,
  /// which reaches the same line — throws while building. It is drawn here
  /// instead, out of the fork's own slider theme: `mu.SliderTheme.of(context)`
  /// already ships the disabled active/inactive track and thumb colours, and the
  /// inert M3 form is exactly what they describe — the rail at `trackHeight`, the
  /// filled portion up to the value and the thumb dot sitting on it, the whole
  /// thing under an `IgnorePointer` and tagged with [inertSliderKey]. The value
  /// stays on screen and no drag reaches the callback (§15: no shared floor).
  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) {
    if (spec.enabled && spec.onChanged != null) {
      return MaterialSliderBuilder.build(context, spec);
    }
    return _inertSlider(context, spec);
  }

  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) => MaterialSegmentedBuilder.build(context, spec);

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => MaterialProgressBuilder.build(context, spec);

  /// The select, fed only the choice the library can carry.
  ///
  /// The fork's `mu.DropdownButton` asserts that its current value matches
  /// exactly one item. A value the list does not carry is not a choice — and,
  /// measured on 1.6.0, it is not a crash either: that assert short-circuits while
  /// `value == null`, which is the library's own *nothing chosen* state, and the
  /// slot it paints then is `hint`, where [LanguageSelectSpec.placeholder]
  /// already rides. So the off-list value is dropped to null — the field shows
  /// its placeholder instead of pretending the value is selected — and the opened
  /// menu keeps only choosable items, dropping null and repeated item values for
  /// the same "exactly one" reason (§15: no shared floor).
  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) =>
      MaterialSelectBuilder.build<T>(context, _chosenOrNull(spec));

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => MaterialScaffoldBuilder.build(context, spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => MaterialAppBarBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => MaterialListRowBuilder.build(context, spec);

  /// The destination strip, or its inert form.
  ///
  /// `mu.NavigationBar` asserts at least two destinations and an in-range
  /// selection, and one destination is not a choice between anything. So a bar
  /// with a single cell, an empty bar and a bar whose index fell out of a
  /// shrunken shell are all drawn here: the elevated surface role the live bar
  /// sits on, one unlabelled-as-selected cell per destination in
  /// `theme.tabs.itemColor` (the unselected role — nothing carries a selection),
  /// and no press target at all, so a tap reports nothing. An empty list is the
  /// surface alone ([inertNavBarKey] tags it) (§15: no shared floor).
  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) {
    if (spec.items.length >= 2 && spec.index >= 0 && spec.index < spec.items.length) {
      return MaterialNavBarBuilder.build(context, spec);
    }
    final theme = LiveTheme.of(context);
    final role = theme.tabs.itemColor;
    final pad = theme.token.scale.sizes.xxs;
    return ColoredBox(
      key: inertNavBarKey,
      color: theme.colors.bgElevated,
      child: Row(children: [for (final item in spec.items) Expanded(child: _inertDestination(item, role, pad))]),
    );
  }

  @override
  Widget tabBar(BuildContext context, LanguageTabsSpec spec) => MaterialTabBarBuilder.build(context, spec);

  @override
  Widget tabView(BuildContext context, LanguageTabViewSpec spec) => MaterialTabViewBuilder.build(context, spec);

  @override
  Widget dialog(BuildContext context, LanguageDialogSpec spec) => MaterialDialogBuilder.build(context, spec);

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => MaterialToastBuilder.build(context, spec);

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) => MaterialHostBuilder.build(context, spec);

  @override
  Widget shell(BuildContext context, LanguageShellSpec spec) => MaterialShellBuilder.build(context, spec);

  /// The inert slider described on [slider]: the fork's disabled track and thumb,
  /// laid out at the value's fraction and unreachable to input.
  static Widget _inertSlider(BuildContext context, LanguageSliderSpec spec) {
    final theme = LiveTheme.of(context);
    final sliderTheme = mu.SliderTheme.of(context);
    final fraction = _fraction(spec);
    final trackHeight = sliderTheme.trackHeight ?? 4.0;
    final railColor =
        sliderTheme.disabledInactiveTrackColor ?? sliderTheme.inactiveTrackColor ?? theme.slider.railColor;
    final fillColor = sliderTheme.disabledActiveTrackColor ?? sliderTheme.activeTrackColor ?? theme.slider.trackColor;
    final thumbColor = sliderTheme.disabledThumbColor ?? sliderTheme.thumbColor ?? theme.slider.handleColor;
    const half = inertThumbSize / 2;
    // An unbounded parent gets the library's own minimum slider width rather than
    // an infinite track.
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        if (!constraints.hasBoundedWidth) {
          width = 200;
        }
        final travel = width - inertThumbSize;
        final filled = (travel * fraction).clamp(0.0, travel);
        return IgnorePointer(
          key: inertSliderKey,
          child: Semantics(
            slider: true,
            value: spec.value.toStringAsFixed(2),
            child: SizedBox(
              width: width,
              height: inertThumbSize,
              child: Stack(
                children: [
                  Positioned(
                    left: half,
                    right: half,
                    top: (inertThumbSize - trackHeight) / 2,
                    height: trackHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: railColor, borderRadius: BorderRadius.circular(trackHeight / 2)),
                    ),
                  ),
                  Positioned(
                    left: half,
                    width: filled,
                    top: (inertThumbSize - trackHeight) / 2,
                    height: trackHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(trackHeight / 2)),
                    ),
                  ),
                  Positioned(
                    left: (travel * fraction).clamp(0.0, travel),
                    top: 0,
                    width: inertThumbSize,
                    height: inertThumbSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: thumbColor,
                        border: Border.all(color: theme.slider.handleBorderColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The spec's value as the fraction of its range the inert rail shows.
  static double _fraction(LanguageSliderSpec spec) {
    final span = spec.max - spec.min;
    if (span <= 0) {
      return 0;
    }
    return ((spec.value - spec.min) / span).clamp(0.0, 1.0);
  }

  /// [spec] rewritten so the fork's assert is satisfied: the item values it can
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

  /// One cell of the inert strip [navBar] draws: the destination's glyph and
  /// label in the unselected role [role], with no press target under them, so the
  /// cell can neither read as chosen nor report a tap.
  static Widget _inertDestination(LiveNavBarItem item, Color role, double pad) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, color: role, size: 24),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: role),
          ),
        ],
      ),
    );
  }
}
