import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_wind/src/adapter/wind_capabilities.dart';
import 'package:live_uikit_wind/src/theme/wind_theme_mapper.dart';
import 'package:live_uikit_wind/src/widgets/wind_button_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_card_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_checkbox_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_select_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_switch_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_text_field_builder.dart';

/// Wind — the `fluttersdk_wind` design-language adapter (§1).
///
/// Implements the core contract for [LiveDesignLanguage.wind]: theme mapping
/// delegates to `theme/`, the six native controls (button, card, text field,
/// switch, checkbox, select) to their `widgets/` builders, and the declared
/// [capabilities] to `wind_capabilities.dart`. Every other control — slider,
/// segmented, progress, tab bar — falls back to the shared token
/// renderer and is reported by the resolver as `controlUnsupported` (§7/§15).
/// No business state here.
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
}
