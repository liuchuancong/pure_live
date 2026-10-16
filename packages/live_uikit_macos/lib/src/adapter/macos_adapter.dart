import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_macos/src/adapter/macos_capabilities.dart';
import 'package:live_uikit_macos/src/adapter/macos_surfaces.dart';
import 'package:live_uikit_macos/src/theme/macos_theme_mapper.dart';
import 'package:live_uikit_macos/src/widgets/macos_app_bar_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_button_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_card_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_checkbox_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_host_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_list_row_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_nav_bar_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_progress_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_scaffold_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_segmented_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_select_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_shell_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_slider_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_switch_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_tab_bar_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_text_field_builder.dart';
import 'package:live_uikit_macos/src/widgets/macos_toast_builder.dart';

/// macOS — the `macos_ui` design-language adapter (§1).
///
/// Implements the core contract for [LiveDesignLanguage.macos]: theme mapping
/// delegates to `theme/`, each control to its `widgets/` builder, and the
/// declared [capabilities] to `macos_capabilities.dart`. Eleven of the fifteen
/// controls are the library's own widget; the four the library does not carry —
/// the card, the tab strip, the destination strip and the toast surface — are
/// assembled from its parts, and each builder says which. It owns both structural
/// surfaces: `MacosApp` as the host and the library's `SidebarItems` list, in a
/// column of the shell's own, as the shell — the page frame stays with `scaffold`.
/// macOS widgets reuse the core's Material/Cupertino localization, so this package
/// adds no delegates.
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
  Widget card(BuildContext context, LanguageCardSpec spec) => MacosCardBuilder.build(context, spec);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => MacosTextFieldBuilder.build(context, spec);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => MacosSwitchBuilder.build(context, spec);

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
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) => MacosSegmentedBuilder.build(context, spec);

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => MacosProgressBuilder.build(context, spec);

  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) {
    // The library's pop-up button asserts that its items carry distinct values and
    // that the current value is one of them, so a spec it would throw on is the
    // shared renderer's case to draw rather than a crash in the library (§15).
    final items = spec.items;
    final unusable =
        items.any((item) => item == null) ||
        items.toSet().length != items.length ||
        (spec.value != null && !items.contains(spec.value));
    if (unusable) {
      return super.select(context, spec);
    }
    return MacosSelectBuilder.build(context, spec);
  }

  @override
  Widget tabBar(BuildContext context, LanguageTabsSpec spec) => MacosTabBarBuilder.build(context, spec);

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => MacosScaffoldBuilder.build(context, spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => MacosAppBarBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => MacosListRowBuilder.build(context, spec);

  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) => MacosNavBarBuilder.build(context, spec);

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => MacosToastBuilder.build(context, spec);

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) => MacosHostBuilder.build(context, spec);

  @override
  Widget shell(BuildContext context, LanguageShellSpec spec) => MacosShellBuilder.build(context, spec);
}
