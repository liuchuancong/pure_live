import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_wind/src/adapter/wind_ui_capabilities.dart';
import 'package:live_uikit_wind/src/theme/wind_theme_mapper.dart';
import 'package:live_uikit_wind/src/widgets/wind_button_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_checkbox_builder.dart';
import 'package:live_uikit_wind/src/widgets/wind_switch_builder.dart';

/// Wind — the `fluttersdk_wind` design-language adapter (§1).
///
/// Implements the core contract for [LiveDesignLanguage.wind]: theme mapping
/// delegates to `theme/`, each control to its `widgets/` builder, and the
/// declared [capabilities] to `wind_ui_capabilities.dart`. Controls Wind cannot
/// map cleanly fall back to the shared token renderer. No business state here.
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
  LiveUiCapabilities get capabilities => windUiCapabilities;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => WindButtonBuilder.build(context, spec, this);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => WindSwitchBuilder.build(context, spec);

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => WindCheckboxBuilder.build(context, spec, this);
}
