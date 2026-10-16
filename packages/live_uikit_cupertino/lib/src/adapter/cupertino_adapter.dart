import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_cupertino/src/adapter/cupertino_capabilities.dart';
import 'package:live_uikit_cupertino/src/adapter/cupertino_surfaces.dart';
import 'package:live_uikit_cupertino/src/theme/cupertino_theme_mapper.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_app_bar_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_button_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_card_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_checkbox_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_host_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_list_row_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_nav_bar_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_progress_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_scaffold_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_segmented_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_select_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_slider_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_switch_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_tab_bar_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_text_field_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_toast_builder.dart';

/// Cupertino UI — the `cupertino_ui` design-language adapter (§1).
///
/// A fork of Flutter's Cupertino widgets, and this adapter covers the whole
/// contract with it: the controls, the four chrome pieces, the app host, and the
/// four controls the fork either drives differently from the neutral spec or has
/// no widget for at all (see `cupertino_capabilities.dart` for which is which).
/// Theme via `theme/`, each control via its `widgets/` builder. No business state.
class CupertinoLanguageAdapter extends SharedLanguageAdapter {
  /// The adapter.
  const new();

  static const CupertinoThemeMapper _theme = CupertinoThemeMapper();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.cupertino;

  @override
  String get id => 'cupertino';

  @override
  String get displayName => 'Cupertino UI';

  @override
  LiveUiCapabilities get capabilities => cupertinoCapabilities;

  @override
  LiveUiSurfaceCapabilities get surfaces => cupertinoSurfaces;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => CupertinoButtonBuilder.build(context, spec, this);

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => CupertinoCardBuilder.build(context, spec);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => CupertinoTextFieldBuilder.build(context, spec);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => CupertinoSwitchBuilder.build(context, spec);

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => CupertinoCheckboxBuilder.build(context, spec);

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) => CupertinoSliderBuilder.build(context, spec);

  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) {
    // `CupertinoSegmentedControl` asserts at least two segments, so a track it
    // would throw on is the shared renderer's case to draw rather than a crash in
    // the library (§15).
    if (spec.labels.length < 2) {
      return super.segmented(context, spec);
    }
    return CupertinoSegmentedBuilder.build(context, spec);
  }

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => CupertinoProgressBuilder.build(context, spec);

  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) => CupertinoSelectBuilder.build<T>(context, spec);

  @override
  Widget tabBar(BuildContext context, LanguageTabsSpec spec) => CupertinoTabBarBuilder.build(context, spec);

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => CupertinoScaffoldBuilder.build(context, spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => CupertinoAppBarBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => CupertinoListRowBuilder.build(context, spec);

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) {
    // `CupertinoTabBar` asserts a non-empty item list and an in-range selection,
    // so a bar that cannot satisfy either is the shared renderer's case to draw,
    // not a crash in the library (§15).
    if (spec.items.isEmpty || spec.index < 0 || spec.index >= spec.items.length) {
      return super.navBar(context, spec);
    }
    return CupertinoNavBarBuilder.build(context, spec);
  }

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => CupertinoToastBuilder.build(context, spec);

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) => CupertinoHostBuilder.build(context, spec);
}
