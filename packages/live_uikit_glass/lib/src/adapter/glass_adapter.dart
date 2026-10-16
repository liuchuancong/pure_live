import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_glass/src/adapter/glass_capabilities.dart';
import 'package:live_uikit_glass/src/adapter/glass_surfaces.dart';
import 'package:live_uikit_glass/src/theme/glass_theme_mapper.dart';
import 'package:live_uikit_glass/src/widgets/glass_app_bar_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_button_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_card_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_checkbox_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_host_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_list_row_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_nav_bar_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_progress_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_scaffold_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_segmented_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_select_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_slider_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_switch_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_tab_bar_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_text_field_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_toast_builder.dart';

/// Glass — the `glass_morphism_plus` design-language adapter (§1).
///
/// Implements the core contract for [LiveDesignLanguage.glass]: theme mapping
/// delegates to `theme/`, each of the fifteen controls to its `widgets/` builder,
/// and the declared [capabilities] to `glass_capabilities.dart`. The library ships
/// surfaces rather than a widget set, so four controls are the library's own
/// widgets and eleven are composed from its frosted surfaces and theme values;
/// each builder says which. No business state lives here.
class GlassLanguageAdapter extends SharedLanguageAdapter {
  /// The Glass adapter.
  const new();

  static const GlassThemeMapper _theme = GlassThemeMapper();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.glass;

  @override
  String get id => 'glass';

  @override
  String get displayName => 'Glass';

  @override
  LiveUiCapabilities get capabilities => glassCapabilities;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => GlassButtonBuilder.build(context, spec, this);

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => GlassCardBuilder.build(context, spec);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => GlassTextFieldBuilder.build(context, spec);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => GlassSwitchBuilder.build(context, spec);

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => GlassCheckboxBuilder.build(context, spec);

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) => GlassSliderBuilder.build(context, spec);

  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) => GlassSegmentedBuilder.build(context, spec);

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => GlassProgressBuilder.build(context, spec);

  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) => GlassSelectBuilder.build<T>(context, spec);

  @override
  Widget tabBar(BuildContext context, LanguageTabsSpec spec) => GlassTabBarBuilder.build(context, spec);

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => GlassScaffoldBuilder.build(context, spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => GlassAppBarBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => GlassListRowBuilder.build(context, spec);

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) => GlassNavBarBuilder.build(context, spec);

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => GlassToastBuilder.build(context, spec);

  @override
  LiveUiSurfaceCapabilities get surfaces => glassSurfaces;

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) => GlassHostBuilder.build(context, spec);
}
