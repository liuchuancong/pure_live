import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_cupertino_ui/src/adapter/cupertino_ui_capabilities.dart';
import 'package:live_uikit_cupertino_ui/src/theme/cupertino_ui_theme_mapper.dart';
import 'package:live_uikit_cupertino_ui/src/widgets/cupertino_ui_app_bar_builder.dart';
import 'package:live_uikit_cupertino_ui/src/widgets/cupertino_ui_button_builder.dart';
import 'package:live_uikit_cupertino_ui/src/widgets/cupertino_ui_list_row_builder.dart';
import 'package:live_uikit_cupertino_ui/src/widgets/cupertino_ui_nav_bar_builder.dart';
import 'package:live_uikit_cupertino_ui/src/widgets/cupertino_ui_scaffold_builder.dart';
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

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => CupertinoUiScaffoldBuilder.build(context, spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => CupertinoUiAppBarBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => CupertinoUiListRowBuilder.build(context, spec);

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) {
    // `CupertinoTabBar` asserts a non-empty item list and an in-range selection,
    // so a bar that cannot satisfy either is the shared renderer's case to draw,
    // not a crash in the library (§15).
    if (spec.items.isEmpty || spec.index < 0 || spec.index >= spec.items.length) {
      return super.navBar(context, spec);
    }
    return CupertinoUiNavBarBuilder.build(context, spec);
  }
}
