import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_neumorphic/src/adapter/neumorphic_capabilities.dart';
import 'package:live_uikit_neumorphic/src/adapter/neumorphic_surfaces.dart';
import 'package:live_uikit_neumorphic/src/theme/neumorphic_theme_mapper.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_app_bar_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_button_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_card_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_checkbox_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_host_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_list_row_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_nav_bar_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_progress_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_scaffold_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_segmented_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_select_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_slider_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_switch_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_tab_bar_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_text_field_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_toast_builder.dart';

/// Neumorphic — the `flutter_neumorphic_ui_kit` design-language adapter (§1).
///
/// Implements the core contract for [LiveDesignLanguage.neumorphic]: theme
/// mapping delegates to `theme/`, each control to its `widgets/` builder, and the
/// declared [capabilities] to `neumorphic_capabilities.dart`. No business state
/// lives here.
///
/// All fifteen controls are built from this library, and each builder says whether
/// it mapped a widget or composed one. Mapped: button, card, text field, switch,
/// checkbox, slider, `progress` (`NeuProgressBar` already is a recessed trough with
/// a domed fill) and `appBar` (`NeuAppBar` is a `NeuContainer` plane around a
/// `NavigationToolbar`; only its `bottom` slot, which wants a `PreferredSizeWidget`,
/// is handled outside the widget). Composed, from `NeuContainer`/`NeuShape` faces and
/// `NeuTheme.of` depth, radius and accent, because the library has no such widget:
/// `segmented` (a pressed dish of cells, the chosen one domed), `select` (a field
/// plane plus an option dish that opens inline — no overlay, because the core owns
/// it), `tabBar` (domed cells; `NeuBottomNav` cannot be a strip: it demands ≥2 items,
/// a non-null callback and a `SafeArea` bottom-bar wrapper), `navBar` (a docked slab
/// whose active destination presses *into* it — the same widget that cannot be a
/// strip does state an active destination, and that is the part worth keeping),
/// `listRow` (a flat plane that becomes a pressed dish when selected, since this
/// style says "on" with depth rather than with a fill), `toast` (a raised plane;
/// `LiveToast.show` keeps the overlay, the fade and the timer) and `scaffold` (the
/// page surface itself — a flat plane at zero depth and zero radius with the bars
/// stacked on it, because the only frame-shaped widget reachable from the dependency
/// is Material's own `Scaffold`, which would hand the page back to Material).
///
/// Nothing here falls through to the shared token base: [capabilities] is the whole
/// contract (§15.3), and a page that mixes these controls has no Material renderer in
/// its subtree.
class NeumorphicLanguageAdapter extends SharedLanguageAdapter {
  /// The Neumorphic adapter.
  const new();

  static const NeumorphicThemeMapper _theme = NeumorphicThemeMapper();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.neumorphic;

  @override
  String get id => 'neumorphic';

  @override
  String get displayName => 'Neumorphic';

  @override
  LiveUiCapabilities get capabilities => neumorphicCapabilities;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => NeumorphicButtonBuilder.build(context, spec, this);

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => NeumorphicCardBuilder.build(context, spec);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => NeumorphicTextFieldBuilder.build(context, spec);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => NeumorphicSwitchBuilder.build(context, spec);

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) =>
      NeumorphicCheckboxBuilder.build(context, spec, this);

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) => NeumorphicSliderBuilder.build(context, spec);

  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) => NeumorphicSegmentedBuilder.build(context, spec);

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => NeumorphicProgressBuilder.build(context, spec);

  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) => NeumorphicSelectBuilder.build<T>(context, spec);

  @override
  Widget tabBar(BuildContext context, LanguageTabsSpec spec) => NeumorphicTabBarBuilder.build(context, spec);

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => NeumorphicScaffoldBuilder.build(context, spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => NeumorphicAppBarBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => NeumorphicListRowBuilder.build(context, spec);

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) => NeumorphicNavBarBuilder.build(context, spec);

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => NeumorphicToastBuilder.build(context, spec);

  @override
  LiveUiSurfaceCapabilities get surfaces => neumorphicSurfaces;

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) => NeumorphicHostBuilder.build(context, spec);
}
