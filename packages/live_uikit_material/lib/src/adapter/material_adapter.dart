import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_material/src/adapter/material_capabilities.dart';
import 'package:live_uikit_material/src/adapter/material_surfaces.dart';
import 'package:live_uikit_material/src/theme/material_theme_mapper.dart';
import 'package:live_uikit_material/src/widgets/material_app_bar_builder.dart';
import 'package:live_uikit_material/src/widgets/material_button_builder.dart';
import 'package:live_uikit_material/src/widgets/material_card_builder.dart';
import 'package:live_uikit_material/src/widgets/material_checkbox_builder.dart';
import 'package:live_uikit_material/src/widgets/material_host_builder.dart';
import 'package:live_uikit_material/src/widgets/material_list_row_builder.dart';
import 'package:live_uikit_material/src/widgets/material_nav_bar_builder.dart';
import 'package:live_uikit_material/src/widgets/material_progress_builder.dart';
import 'package:live_uikit_material/src/widgets/material_scaffold_builder.dart';
import 'package:live_uikit_material/src/widgets/material_segmented_builder.dart';
import 'package:live_uikit_material/src/widgets/material_shell_builder.dart';
import 'package:live_uikit_material/src/widgets/material_slider_builder.dart';
import 'package:live_uikit_material/src/widgets/material_switch_builder.dart';
import 'package:live_uikit_material/src/widgets/material_text_field_builder.dart';

/// Material UI — the `material_ui` design-language adapter (§1).
///
/// A fork of Flutter's Material widgets, so it mirrors the core Material
/// coverage (button/card/field/switch/checkbox/slider/segmented/progress);
/// select and tabs fall back to the shared token base. Theme via `theme/`, each
/// control via its `widgets/` builder, [capabilities] via the capabilities file.
class MaterialLanguageAdapter extends SharedLanguageAdapter {
  /// The adapter.
  const new();

  static const MaterialThemeMapper _theme = MaterialThemeMapper();

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

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) {
    // A disabled slider is the one case Material UI cannot render: the fork
    // dereferences a focus node it only creates for an interactive slider, so
    // the shared token renderer stands in rather than throwing (§15).
    if (!spec.enabled || spec.onChanged == null) {
      return super.slider(context, spec);
    }
    return MaterialSliderBuilder.build(context, spec);
  }

  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) => MaterialSegmentedBuilder.build(context, spec);

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => MaterialProgressBuilder.build(context, spec);

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => MaterialScaffoldBuilder.build(context, spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => MaterialAppBarBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => MaterialListRowBuilder.build(context, spec);

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) {
    // The fork's bar asserts at least two destinations and an in-range selection,
    // so a bar that could not satisfy it — a single destination, an index from a
    // shell whose list just shrank — is the shared renderer's case to draw rather
    // than a crash in the library (§15).
    if (spec.items.length < 2 || spec.index < 0 || spec.index >= spec.items.length) {
      return super.navBar(context, spec);
    }
    return MaterialNavBarBuilder.build(context, spec);
  }

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) => MaterialHostBuilder.build(context, spec);

  @override
  Widget shell(BuildContext context, LanguageShellSpec spec) => MaterialShellBuilder.build(context, spec);
}
