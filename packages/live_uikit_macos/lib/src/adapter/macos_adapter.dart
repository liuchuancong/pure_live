import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_macos/src/adapter/macos_capabilities.dart';
import 'package:live_uikit_macos/src/adapter/macos_surfaces.dart';
import 'package:live_uikit_macos/src/theme/macos_theme_mapper.dart';
import 'package:live_uikit_macos/src/widgets/macos_app_bar_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_button_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_checkbox_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_host_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_list_row_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_scaffold_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_slider_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_text_field_builder.dart';

/// macOS — the `macos_ui` design-language adapter (§1).
///
/// Implements the core contract for [LiveDesignLanguage.macos]: theme mapping
/// delegates to `theme/`, each control to its `widgets/` builder, and the
/// declared [capabilities] to `macos_capabilities.dart`. macOS widgets reuse
/// the core's Material/Cupertino localization, so this package adds no delegates.
class MacosLanguageAdapter extends SharedLanguageAdapter {
  /// The macOS adapter.
  const new();

  static const MacosThemeMapper _theme = MacosThemeMapper();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.macos;

  @override
  String get id => 'macos';

  @override
  String get displayName => 'macOS';

  @override
  LiveUiCapabilities get capabilities => macosCapabilities;

  @override
  LiveUiSurfaceCapabilities get surfaces => macosSurfaces;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => MacosButtonBuilder.build(context, spec, this);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => MacosTextFieldBuilder.build(context, spec);

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => MacosCheckboxBuilder.build(context, spec, this);

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) {
    // `MacosSlider` requires a non-null callback, so a disabled slider has no
    // native form: the shared token renderer stands in (§9/§15).
    if (!spec.enabled || spec.onChanged == null) {
      return super.slider(context, spec);
    }
    return MacosSliderBuilder.build(context, spec);
  }

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => MacosScaffoldBuilder.build(context, spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => MacosAppBarBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => MacosListRowBuilder.build(context, spec);

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) => MacosHostBuilder.build(context, spec);
}
