import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_glass/src/adapter/glass_ui_capabilities.dart';
import 'package:live_uikit_glass/src/theme/glass_theme_mapper.dart';
import 'package:live_uikit_glass/src/widgets/glass_button_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_card_builder.dart';
import 'package:live_uikit_glass/src/widgets/glass_text_field_builder.dart';

/// Glass — the `glass_morphism_plus` design-language adapter (§1).
///
/// Implements the core contract for [LiveDesignLanguage.glass]: theme mapping
/// delegates to `theme/`, each control to its `widgets/` builder, and the
/// declared [capabilities] to `glass_ui_capabilities.dart`. Unoverridden controls
/// render through the shared token base. No business state lives here.
class GlassLanguageAdapter extends SharedLanguageAdapter {
  /// The Glass adapter.
  const new();

  static const GlassThemeMapper _theme = GlassThemeMapper();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.glass;

  @override
  String get id => 'glass';

  @override
  String get displayName => 'Glass';

  @override
  LiveUiCapabilities get capabilities => glassUiCapabilities;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => GlassButtonBuilder.build(context, spec, this);

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => GlassCardBuilder.build(context, spec);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => GlassTextFieldBuilder.build(context, spec);
}
