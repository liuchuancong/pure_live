import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_fluent/src/adapter/fluent_ui_capabilities.dart';
import 'package:live_uikit_fluent/src/theme/fluent_theme_mapper.dart';
import 'package:live_uikit_fluent/src/widgets/fluent_button_builder.dart';
import 'package:live_uikit_fluent/src/widgets/fluent_card_builder.dart';
import 'package:live_uikit_fluent/src/widgets/fluent_checkbox_builder.dart';
import 'package:live_uikit_fluent/src/widgets/fluent_list_row_builder.dart';
import 'package:live_uikit_fluent/src/widgets/fluent_progress_builder.dart';
import 'package:live_uikit_fluent/src/widgets/fluent_scaffold_builder.dart';
import 'package:live_uikit_fluent/src/widgets/fluent_select_builder.dart';
import 'package:live_uikit_fluent/src/widgets/fluent_slider_builder.dart';
import 'package:live_uikit_fluent/src/widgets/fluent_switch_builder.dart';
import 'package:live_uikit_fluent/src/widgets/fluent_text_field_builder.dart';
import 'package:live_uikit_fluent/src/widgets/fluent_toast_builder.dart';

/// Fluent — the `fluent_ui` design-language adapter (§1).
///
/// Implements the core [LanguageAdapter] contract for [LiveDesignLanguage.fluent]:
/// theme mapping is delegated to `theme/`, each control to its `widgets/`
/// builder, and the declared [capabilities] to `fluent_ui_capabilities.dart`. A
/// control the adapter does not override still renders through the shared token
/// base it extends, so nothing disappears — it just is not Fluent-native (§15.3).
class FluentLanguageAdapter extends SharedLanguageAdapter {
  /// The Fluent adapter.
  const new();

  static const FluentThemeMapper _theme = FluentThemeMapper();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.fluent;

  @override
  String get id => 'fluent';

  @override
  String get displayName => 'Fluent';

  @override
  LiveUiCapabilities get capabilities => fluentUiCapabilities;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => FluentButtonBuilder.build(context, spec, this);

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => FluentCardBuilder.build(context, spec);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => FluentTextFieldBuilder.build(context, spec);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => FluentSwitchBuilder.build(context, spec);

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => FluentCheckboxBuilder.build(context, spec, this);

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) => FluentSliderBuilder.build(context, spec);

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => FluentProgressBuilder.build(context, spec);

  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) => FluentSelectBuilder.build<T>(context, spec);

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => FluentScaffoldBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => FluentListRowBuilder.build(context, spec);

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => FluentToastBuilder.build(context, spec);
}
