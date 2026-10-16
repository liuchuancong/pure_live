import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_forui/src/adapter/forui_capabilities.dart';
import 'package:live_uikit_forui/src/adapter/forui_surfaces.dart';
import 'package:live_uikit_forui/src/theme/forui_theme_mapper.dart';
import 'package:live_uikit_forui/src/widgets/forui_app_bar_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_button_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_card_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_checkbox_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_host_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_list_row_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_nav_bar_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_progress_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_scaffold_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_segmented_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_select_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_slider_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_switch_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_tab_bar_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_text_field_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_toast_builder.dart';

/// ForUI — the `forui` design-language adapter (§1).
///
/// Implements the core contract for [LiveDesignLanguage.forui]: the theme mapping
/// delegates to `theme/`, every one of the fifteen controls to its `widgets/` builder, and
/// the declared [capabilities] to `forui_capabilities.dart` — so nothing inside a ForUI
/// page is drawn by the shared token renderer. The one control with no library widget to
/// map is `segmented`, which is composed out of forui's own `FButton` group and says so
/// in its builder; every other builder records the spec fields the library has no slot
/// for, so the gaps are visible rather than silent. No business state lives here. The
/// structural surfaces (app host, app shell) are not this package's yet, so they stay
/// inherited and the resolver reports them.
class ForuiLanguageAdapter extends SharedLanguageAdapter {
  /// The ForUI adapter.
  const new();

  static const ForuiThemeMapper _theme = ForuiThemeMapper();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.forui;

  @override
  String get id => 'forui';

  @override
  String get displayName => 'ForUI';

  @override
  LiveUiCapabilities get capabilities => foruiCapabilities;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => ForuiButtonBuilder.build(context, spec, this);

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => ForuiCardBuilder.build(context, spec);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => ForuiTextFieldBuilder.build(context, spec);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => ForuiSwitchBuilder.build(context, spec);

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => ForuiCheckboxBuilder.build(context, spec);

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) => ForuiSliderBuilder.build(context, spec);

  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) => ForuiSegmentedBuilder.build(context, spec);

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => ForuiProgressBuilder.build(context, spec);

  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) => ForuiSelectBuilder.build<T>(context, spec);

  @override
  Widget tabBar(BuildContext context, LanguageTabsSpec spec) => ForuiTabBarBuilder.build(context, spec);

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => ForuiScaffoldBuilder.build(context, spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => ForuiAppBarBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => ForuiListRowBuilder.build(context, spec);

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) => ForuiNavBarBuilder.build(context, spec);

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => ForuiToastBuilder.build(context, spec);

  @override
  LiveUiSurfaceCapabilities get surfaces => foruiSurfaces;

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) => ForuiHostBuilder.build(context, spec);
}
