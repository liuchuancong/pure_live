import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_cupertino/src/adapter/cupertino_capabilities.dart';
import 'package:live_uikit_cupertino/src/adapter/cupertino_surfaces.dart';
import 'package:live_uikit_cupertino/src/theme/cupertino_theme_mapper.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_app_bar_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_button_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_card_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_checkbox_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_dialog_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_host_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_list_row_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_nav_bar_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_progress_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_scaffold_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_segmented_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_select_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_shell_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_slider_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_switch_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_tab_bar_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_tab_view_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_text_field_builder.dart';
import 'package:live_uikit_cupertino/src/widgets/cupertino_toast_builder.dart';

/// Cupertino UI — the `cupertino_ui` design-language adapter (§1).
///
/// A fork of Flutter's Cupertino widgets, and this adapter covers the whole
/// contract with it: the controls, the four chrome pieces, both structural
/// surfaces — the `CupertinoApp` host and a shell composed out of the library's
/// list pieces, since it ships no rail — and the five controls the fork either
/// drives differently from the neutral spec or has no widget for at all (see
/// `cupertino_capabilities.dart` for which is which).
/// Theme via `theme/`, each control via its `widgets/` builder. No business state.
///
/// Two specs are drawn here rather than by a builder, because they are the shapes
/// the library's widget refuses to build at all: a segmented track with fewer
/// than two labels and a destination bar with nothing to choose between — see
/// [segmented] and [navBar].
class CupertinoLanguageAdapter implements LanguageAdapter {
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
  Widget button(BuildContext context, LanguageButtonSpec spec) => CupertinoButtonBuilder.build(context, spec);

  @override
  Widget card(BuildContext context, LanguageCardSpec spec) => CupertinoCardBuilder.build(context, spec);

  @override
  Widget textField(BuildContext context, LanguageTextFieldSpec spec) => CupertinoTextFieldBuilder.build(context, spec);

  @override
  Widget switchWidget(BuildContext context, LanguageSwitchSpec spec) => CupertinoSwitchBuilder.build(context, spec);

  @override
  Widget checkbox(BuildContext context, LanguageCheckboxSpec spec) => CupertinoCheckboxBuilder.build(context, spec);

  @override
  Widget slider(BuildContext context, LanguageSliderSpec spec) => CupertinoSliderBuilder.build(context, spec);

  /// The segmented track, or its inert form.
  ///
  /// `cu.CupertinoSegmentedControl` asserts `children.length >= 2`, so a track
  /// with one label (or none) is a spec the fork throws on — and one destination
  /// is not a choice out of a set anyway. It is drawn as the library's own inert
  /// press target, the `cu.CupertinoButton` with a null callback that
  /// `CupertinoTabBarBuilder` already uses for a dead tab: the label keeps its
  /// place, tinted with `theme.tabs.itemColor` (the unselected role, so nothing
  /// reads as chosen), and it reports no tap. An empty label list is no cell at
  /// all (§15).
  @override
  Widget segmented(BuildContext context, LanguageSegmentedSpec spec) {
    if (spec.labels.length >= 2) {
      return CupertinoSegmentedBuilder.build(context, spec);
    }
    if (spec.labels.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = LiveTheme.of(context);
    return cu.CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.sm, vertical: theme.token.scale.sizes.xxs),
      foregroundColor: theme.tabs.itemColor,
      onPressed: null,
      child: Text(spec.labels.first, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  @override
  Widget progress(BuildContext context, LanguageProgressSpec spec) => CupertinoProgressBuilder.build(context, spec);

  @override
  Widget select<T>(BuildContext context, LanguageSelectSpec<T> spec) => CupertinoSelectBuilder.build<T>(context, spec);

  @override
  Widget tabBar(BuildContext context, LanguageTabsSpec spec) => CupertinoTabBarBuilder.build(context, spec);

  @override
  Widget tabView(BuildContext context, LanguageTabViewSpec spec) => CupertinoTabViewBuilder.build(context, spec);

  @override
  Widget scaffold(BuildContext context, LanguageScaffoldSpec spec) => CupertinoScaffoldBuilder.build(context, spec);

  @override
  Widget appBar(BuildContext context, LanguageAppBarSpec spec) => CupertinoAppBarBuilder.build(context, spec);

  @override
  Widget listRow(BuildContext context, LanguageListRowSpec spec) => CupertinoListRowBuilder.build(context, spec);

  /// The destination bar, or its inert form.
  ///
  /// `cu.CupertinoTabBar` asserts a non-empty item list and an in-range
  /// `currentIndex`, and a single destination is not a selection to make. So an
  /// empty bar, a one-cell bar and a bar whose index fell out of a shrunken shell
  /// are all drawn here, out of the same parts the live bar uses: the bar's own
  /// surface role (`theme.colors.bgElevated`, the colour
  /// `CupertinoNavBarBuilder` hands to the fork) under the hairline iOS draws on
  /// top of it, with one inert cell per destination — `cu.CupertinoButton` with a
  /// null callback in `theme.tabs.itemColor`, so no cell carries a selection and
  /// none reports a tap. No destinations leaves the surface and its hairline only
  /// (§15).
  @override
  Widget navBar(BuildContext context, LanguageNavBarSpec spec) {
    if (spec.items.length >= 2 && spec.index >= 0 && spec.index < spec.items.length) {
      return CupertinoNavBarBuilder.build(context, spec);
    }
    final theme = LiveTheme.of(context);
    final role = theme.tabs.itemColor;
    final pad = theme.token.scale.sizes.xxs;
    return ColoredBox(
      color: theme.colors.bgElevated,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(width: 0.5, color: theme.colors.border)),
            ),
          ),
          if (spec.items.isNotEmpty)
            Row(children: [for (final item in spec.items) Expanded(child: _inertDestination(item, role, pad))]),
        ],
      ),
    );
  }

  @override
  Widget toast(BuildContext context, LanguageToastSpec spec) => CupertinoToastBuilder.build(context, spec);

  @override
  Widget dialog(BuildContext context, LanguageDialogSpec spec) => CupertinoDialogBuilder.build(context, spec);

  @override
  Widget appHost(BuildContext context, LanguageHostSpec spec) => CupertinoHostBuilder.build(context, spec);

  @override
  Widget shell(BuildContext context, LanguageShellSpec spec) => CupertinoShellBuilder.build(context, spec);

  /// One cell of the inert bar [navBar] draws: the library's press target with
  /// its callback left off, which is Cupertino's own dead state — the glyph and
  /// label stay in the unselected role [role] and the tap reports nothing.
  static Widget _inertDestination(LiveNavBarItem item, Color role, double pad) {
    return cu.CupertinoButton(
      minimumSize: Size.zero,
      padding: EdgeInsets.symmetric(vertical: pad),
      foregroundColor: role,
      onPressed: null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 28),
          Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
