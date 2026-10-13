import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_cupertino_ui/src/adapter/cupertino_ui_capabilities.dart';
import 'package:live_uikit_cupertino_ui/src/theme/cupertino_ui_theme_mapper.dart';
import 'package:live_uikit_cupertino_ui/src/widgets/cupertino_ui_button_builder.dart';
import 'package:live_uikit_cupertino_ui/src/widgets/cupertino_ui_slider_builder.dart';
import 'package:live_uikit_cupertino_ui/src/widgets/cupertino_ui_switch_builder.dart';
import 'package:live_uikit_cupertino_ui/src/widgets/cupertino_ui_text_field_builder.dart';

/// Cupertino UI — the `cupertino_ui` design-language adapter (§1).
///
/// A fork of Flutter's Cupertino widgets, so the mapping mirrors the core's
/// Cupertino adapter: theme via `theme/`, each control via its `widgets/`
/// builder, and the declared [capabilities] via `cupertino_ui_capabilities.dart`.
/// Unoverridden controls fall back to the shared token base. No business state.
class CupertinoUiLanguageAdapter extends SharedLanguageAdapter {
  /// The adapter.
  const new();

  static const CupertinoUiThemeMapper _theme = CupertinoUiThemeMapper();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.cupertinoUi;

  @override
  String get id => 'cupertinoUi';

  @override
  String get displayName => 'Cupertino UI';

  @override
  LiveUiCapabilities get capabilities => cupertinoUiCapabilities;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => CupertinoUiButtonBuilder.build(context, spec, this);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) =>
      CupertinoUiTextFieldBuilder.build(context, spec);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => CupertinoUiSwitchBuilder.build(context, spec);

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) => CupertinoUiSliderBuilder.build(context, spec);
}
