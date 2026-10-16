import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_forui/src/adapter/forui_capabilities.dart';
import 'package:live_uikit_forui/src/theme/forui_theme_mapper.dart';
import 'package:live_uikit_forui/src/widgets/forui_button_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_card_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_checkbox_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_switch_builder.dart';
import 'package:live_uikit_forui/src/widgets/forui_text_field_builder.dart';

/// ForUI — the `forui` design-language adapter (§1).
///
/// Implements the core contract for [LiveDesignLanguage.forui]: the theme mapping
/// delegates to `theme/`, each native control to its `widgets/` builder, and the
/// declared [capabilities] to `forui_capabilities.dart`. The five controls this
/// package does not override render through the shared token base and are reported by
/// the resolver, so the gaps are visible rather than silent. No business state lives
/// here.
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
}
