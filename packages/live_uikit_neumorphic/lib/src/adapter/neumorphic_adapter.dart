import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_neumorphic/src/adapter/neumorphic_capabilities.dart';
import 'package:live_uikit_neumorphic/src/theme/neumorphic_theme_mapper.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_button_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_card_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_checkbox_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_slider_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_switch_builder.dart';
import 'package:live_uikit_neumorphic/src/widgets/neumorphic_text_field_builder.dart';

/// Neumorphic — the `flutter_neumorphic_ui_kit` design-language adapter (§1).
///
/// Implements the core contract for [LiveDesignLanguage.neumorphic]: theme
/// mapping delegates to `theme/`, each control to its `widgets/` builder, and the
/// declared [capabilities] to `neumorphic_capabilities.dart`. Unoverridden
/// controls render through the shared token base. No business state lives here.
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
}
