import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_material_ui/src/adapter/material_ui_capabilities.dart';
import 'package:live_uikit_material_ui/src/theme/material_ui_theme_mapper.dart';
import 'package:live_uikit_material_ui/src/widgets/material_ui_app_bar_builder.dart';
import 'package:live_uikit_material_ui/src/widgets/material_ui_button_builder.dart';
import 'package:live_uikit_material_ui/src/widgets/material_ui_card_builder.dart';
import 'package:live_uikit_material_ui/src/widgets/material_ui_checkbox_builder.dart';
import 'package:live_uikit_material_ui/src/widgets/material_ui_host_builder.dart';
import 'package:live_uikit_material_ui/src/widgets/material_ui_list_row_builder.dart';
import 'package:live_uikit_material_ui/src/widgets/material_ui_nav_bar_builder.dart';
import 'package:live_uikit_material_ui/src/widgets/material_ui_progress_builder.dart';
import 'package:live_uikit_material_ui/src/widgets/material_ui_scaffold_builder.dart';
import 'package:live_uikit_material_ui/src/widgets/material_ui_segmented_builder.dart';
import 'package:live_uikit_material_ui/src/widgets/material_ui_slider_builder.dart';
import 'package:live_uikit_material_ui/src/widgets/material_ui_switch_builder.dart';
import 'package:live_uikit_material_ui/src/widgets/material_ui_text_field_builder.dart';

/// Material UI — the `material_ui` design-language adapter (§1).
///
/// A fork of Flutter's Material widgets, so it mirrors the core Material
/// coverage (button/card/field/switch/checkbox/slider/segmented/progress);
/// select and tabs fall back to the shared token base. Theme via `theme/`, each
/// control via its `widgets/` builder, [capabilities] via the capabilities file.
class MaterialUiLanguageAdapter extends SharedLanguageAdapter {
  /// The adapter.
  const new();

  static const MaterialUiThemeMapper _theme = MaterialUiThemeMapper();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.materialUi;

  @override
  String get id => 'materialUi';

  @override
  String get displayName => 'Material UI';

  @override
  LiveUiCapabilities get capabilities => materialUiCapabilities;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => MaterialUiButtonBuilder.build(context, spec, this);

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => MaterialUiCardBuilder.build(context, spec);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => MaterialUiTextFieldBuilder.build(context, spec);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => MaterialUiSwitchBuilder.build(context, spec);

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) =>
      MaterialUiCheckboxBuilder.build(context, spec, this);

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) {
    // A disabled slider is the one case Material UI cannot render: the fork
    // dereferences a focus node it only creates for an interactive slider, so
    // the shared token renderer stands in rather than throwing (§15).
    if (!spec.enabled || spec.onChanged == null) {
      return super.slider(context, spec);
    }
    return MaterialUiSliderBuilder.build(context, spec);
  }

  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) => MaterialUiSegmentedBuilder.build(context, spec);

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => MaterialUiProgressBuilder.build(context, spec);

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => MaterialUiScaffoldBuilder.build(context, spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => MaterialUiAppBarBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => MaterialUiListRowBuilder.build(context, spec);

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) {
    // The fork's bar asserts at least two destinations and an in-range selection,
    // so a bar that could not satisfy it — a single destination, an index from a
    // shell whose list just shrank — is the shared renderer's case to draw rather
    // than a crash in the library (§15).
    if (spec.items.length < 2 || spec.index < 0 || spec.index >= spec.items.length) {
      return super.navBar(context, spec);
    }
    return MaterialUiNavBarBuilder.build(context, spec);
  }

  @override
  Widget host(BuildContext context, LanguageHostSpec spec) => MaterialUiHostBuilder.build(context, spec);
}
