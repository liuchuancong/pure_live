import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_cupertino/src/adapter/cupertino_capabilities.dart';
import 'package:live_uikit_cupertino/src/adapter/cupertino_surfaces.dart';
import 'package:live_uikit_cupertino/src/theme/cupertino_theme_mapper.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_app_bar_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_button_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_host_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_list_row_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_nav_bar_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_scaffold_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_slider_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_switch_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_text_field_builder.dart';

/// Cupertino UI — the `cupertino_ui` design-language adapter (§1).
///
/// A fork of Flutter's Cupertino widgets, so the mapping mirrors the core's
/// Cupertino adapter: theme via `theme/`, each control via its `widgets/`
/// builder, and the declared [capabilities] via `cupertino_capabilities.dart`.
/// Unoverridden controls fall back to the shared token base. No business state.
class CupertinoLanguageAdapter extends SharedLanguageAdapter {
  /// The adapter.
  const new();

  static const CupertinoThemeMapper _theme = CupertinoThemeMapper();

  @override
  LiveDesignLanguage get language => LiveDesignLanguage.cupertino;

  @override
  String get id => 'cupertino';

  @override
  String get displayName => 'Cupertino UI';

  @override
  LiveUiCapabilities get capabilities => cupertinoCapabilities;

  @override
  LiveUiSurfaceCapabilities get surfaces => cupertinoSurfaces;

  @override
  Widget wrap(BuildContext context, DesignToken token, Widget child) => _theme.wrap(context, token, child);

  @override
  Widget button(BuildContext context, LanguageButtonSpec spec) => CupertinoButtonBuilder.build(context, spec, this);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => CupertinoTextFieldBuilder.build(context, spec);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => CupertinoSwitchBuilder.build(context, spec);

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) => CupertinoSliderBuilder.build(context, spec);

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => CupertinoScaffoldBuilder.build(context, spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => CupertinoAppBarBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => CupertinoListRowBuilder.build(context, spec);

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) {
    // `CupertinoTabBar` asserts a non-empty item list and an in-range selection,
    // so a bar that cannot satisfy either is the shared renderer's case to draw,
    // not a crash in the library (§15).
    if (spec.items.isEmpty || spec.index < 0 || spec.index >= spec.items.length) {
      return super.navBar(context, spec);
    }
    return CupertinoNavBarBuilder.build(context, spec);
  }

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) => CupertinoHostBuilder.build(context, spec);
}
