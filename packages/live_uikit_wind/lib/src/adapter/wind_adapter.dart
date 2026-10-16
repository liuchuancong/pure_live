import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_wind/src/adapter/wind_capabilities.dart';
import 'package:live_uikit_wind/src/adapter/wind_surfaces.dart';
import 'package:live_uikit_wind/src/theme/wind_theme_mapper.dart';
import 'package:live_uikit_wind/src/widgets/wind_app_bar_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_button_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_card_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_checkbox_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_host_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_list_row_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_nav_bar_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_progress_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_scaffold_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_segmented_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_select_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_shell_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_slider_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_switch_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_tab_bar_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_text_field_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_toast_builder.dart';

/// Wind — the `fluttersdk_wind` design-language adapter (§1).
///
/// Implements the core contract for [LiveDesignLanguage.wind] end to end: theme
/// mapping delegates to `theme/`, all fifteen controls to their `widgets/`
/// builders, the declared [capabilities] to `wind_capabilities.dart` and the
/// declared structural surfaces to `wind_surfaces.dart` — the `WidgetsApp` +
/// `WindTheme` host and the navigation column, both in `widgets/`. Six of
/// them are drawn by a fork widget (`WButton`, `WCard`+token surface, `WInput`,
/// `WSwitch`, `WCheckbox`, `WSelect`); the other nine are composed out of the
/// fork's own parts — `WDiv`/`WCard` surfaces, `WAnchor` interaction, `WText`/
/// `WIcon` leaves and `WButton` for a segment — coloured from Wind's Tailwind
/// maps (`bg-primary-500`, `bg-gray-*`, `rounded-*`, `border-*`, `shadow`) and
/// driven through its `hover:` / `selected:` / `disabled:` state prefixes —
/// because `fluttersdk_wind` ships no slider, segmented track, progress bar, tab
/// strip, page frame, bar, list row, navigation bar, navigation column or toast.
/// Each builder says which it is. No business state here.
class WindLanguageAdapter extends SharedLanguageAdapter {
  /// The Wind adapter.
  const new();

  static const WindThemeMapper _theme = WindThemeMapper();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.wind;

  @override
  String get id => 'wind';

  @override
  String get displayName => 'Wind';

  @override
  LiveUiCapabilities get capabilities => windCapabilities;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => WindButtonBuilder.build(context, spec, this);

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => WindCardBuilder.build(context, spec);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => WindTextFieldBuilder.build(context, spec);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => WindSwitchBuilder.build(context, spec);

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => WindCheckboxBuilder.build(context, spec, this);

  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) => WindSelectBuilder.build<T>(context, spec);

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) => WindSliderBuilder.build(context, spec);

  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) => WindSegmentedBuilder.build(context, spec);

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => WindProgressBuilder.build(context, spec);

  @override
  Widget tabBar(BuildContext context, LanguageTabsSpec spec) => WindTabBarBuilder.build(context, spec);

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => WindScaffoldBuilder.build(context, spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => WindAppBarBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => WindListRowBuilder.build(context, spec);

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) => WindNavBarBuilder.build(context, spec);

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => WindToastBuilder.build(context, spec);

  @override
  LiveUiSurfaceCapabilities get surfaces => windSurfaces;

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) => WindHostBuilder.build(context, spec);

  @override
  Widget shell(BuildContext context, LanguageShellSpec spec) => WindShellBuilder.build(context, spec);
}
