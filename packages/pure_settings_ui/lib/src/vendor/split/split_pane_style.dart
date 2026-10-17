import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_split.dart';
import 'package:pure_settings_ui/src/vendor/sections/abstract_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/custom_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/platforms/fluent_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/settings_section.dart';
import 'package:pure_settings_ui/src/vendor/split/adwaita_split.dart';
import 'package:pure_settings_ui/src/vendor/split/fluent_split.dart';
import 'package:pure_settings_ui/src/vendor/split/macos_split.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_page_header.dart';
import 'package:pure_settings_ui/src/vendor/split/sidebar_keyboard.dart';
import 'package:pure_settings_ui/src/vendor/split/split_geometry.dart';
import 'package:pure_settings_ui/src/vendor/utils/content_column.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

/// How one style family draws the panes of a split view in one layout:
/// what differs between the styles around the same settings list and the
/// same detail navigator. Internal.
///
/// `SettingsSplitView` builds its panes the same way in every style and
/// asks this for the rest, so no style's details live in the view itself.
abstract class SplitPaneStyle {
  const SplitPaneStyle(this.platform, this.geometry);

  /// The style of [platform] for a view laid out as [geometry] says.
  factory SplitPaneStyle.of(DevicePlatform platform, SplitGeometry geometry) =>
      switch (settingsStyleFamily(platform)) {
        SettingsStyleFamily.cupertino => _CupertinoPaneStyle(
          platform,
          geometry,
        ),
        SettingsStyleFamily.material => _MaterialPaneStyle(platform, geometry),
        SettingsStyleFamily.web => _WebPaneStyle(platform, geometry),
        SettingsStyleFamily.macos => _MacosPaneStyle(platform, geometry),
        SettingsStyleFamily.fluent => _FluentPaneStyle(platform, geometry),
        SettingsStyleFamily.adwaita => _AdwaitaPaneStyle(platform, geometry),
        SettingsStyleFamily.pure => PurePaneStyle(platform, geometry),
      };

  final DevicePlatform platform;
  final SplitGeometry geometry;

  /// Whether the list pane is one of two panes, not the root page of one.
  bool get isSplit => geometry.isSplit;

  /// Whether sections and tiles draw the style's sidebar rows instead of
  /// its cards: the macOS, Windows and GNOME sidebars.
  bool get sidebar => false;

  /// The padding of the list pane's list. Null keeps the list's own.
  EdgeInsetsGeometry? get listPadding;

  /// Whether the list pane's tiles drop their leading icons.
  bool get hidesLeading => false;

  /// The line between the panes, at the list pane's end edge, if any.
  BorderSide? paneEdge(SettingsThemeData theme) => null;

  /// The sections of the list pane's list: [sections] with what the style
  /// puts before or between them. [title] is the pane's title.
  List<AbstractSettingsSection> listSections(
    List<AbstractSettingsSection> sections,
    Widget? title,
  ) => sections;

  /// The list pane's content: the style's header over [pane]'s list.
  ///
  /// The list sits in the same widget structure in both layouts, so the
  /// list pane (it moves between them under a `GlobalKey`) keeps its scroll
  /// position.
  Widget buildListPane(SplitListPaneParts pane);

  /// Tells the pages under [child], the detail pane, where to put their
  /// content column (see [SettingsContentColumnHint]): iPad and Android
  /// pages fill the detail pane, the desktop styles keep their own columns.
  Widget detailColumn(Widget child) => SettingsContentColumnHint(
    paneWidth: geometry.detailWidth,
    fillWidth: true,
    child: child,
  );
}

/// What a split view gives its [SplitPaneStyle] to build the list pane's
/// content from. Internal.
@immutable
class SplitListPaneParts {
  const SplitListPaneParts({
    required this.viewContext,
    required this.title,
    required this.onBack,
    required this.onTogglePane,
    required this.background,
    required this.largeTitleHidden,
    required this.list,
  });

  /// The split view's context in the list pane. The list gets its
  /// `MediaQuery` from here (see [settingsHeaderOverBody]): the pane's, which
  /// with two panes has no padding at the end side.
  final BuildContext viewContext;

  /// The pane's title, if any.
  final Widget? title;

  /// Leaves the settings screen. Null when there is nowhere to go back to.
  final VoidCallback? onBack;

  /// Opens or closes the Windows style's compact rail over the detail pane.
  final VoidCallback onTogglePane;

  /// The pane's background.
  final Color? background;

  /// Whether the iOS large title has scrolled under the bar.
  final ValueNotifier<bool> largeTitleHidden;

  /// The pane's settings list.
  final Widget list;
}

/// iPad Settings' sidebar, and the Settings root of an iPhone in one pane.
class _CupertinoPaneStyle extends SplitPaneStyle {
  const _CupertinoPaneStyle(super.platform, super.geometry);

  @override
  EdgeInsetsGeometry? get listPadding =>
      isSplit ? const EdgeInsets.only(bottom: 20) : null;

  @override
  List<AbstractSettingsSection> listSections(
    List<AbstractSettingsSection> sections,
    Widget? title,
  ) => title == null
      ? sections
      : [
          CustomSettingsSection(child: SettingsLargeTitle(title: title)),
          ...sections,
        ];

  @override
  Widget buildListPane(SplitListPaneParts pane) {
    final title = pane.title;
    return settingsHeaderOverBody(
      pane.viewContext,
      header: ValueListenableBuilder<bool>(
        valueListenable: pane.largeTitleHidden,
        builder: (context, hidden, _) => SettingsPageBar(
          platform: platform,
          title: title,
          // With a large title in the list, the bar shows the title
          // only once it scrolled away, like iOS.
          showTitle: title == null || hidden,
          onBack: pane.onBack,
        ),
      ),
      body: NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) {
            pane.largeTitleHidden.value = notification.metrics.pixels > 40;
          }
          return false;
        },
        child: pane.list,
      ),
    );
  }
}

/// Android Settings' homepage, the list pane of its two-pane layout.
class _MaterialPaneStyle extends SplitPaneStyle {
  const _MaterialPaneStyle(super.platform, super.geometry);

  @override
  EdgeInsetsGeometry? get listPadding =>
      isSplit ? const EdgeInsets.only(bottom: 16) : null;

  /// AOSP Settings drops the icons of a list pane narrower than 380dp.
  @override
  bool get hidesLeading => isSplit && geometry.listWidth < 380;

  @override
  Widget buildListPane(SplitListPaneParts pane) {
    final title = pane.title;
    if (title != null) {
      return SettingsCollapsingTitleView(
        title: title,
        onBack: pane.onBack,
        background: pane.background,
        body: pane.list,
      );
    }
    return settingsHeaderOverBody(
      pane.viewContext,
      header: SettingsPageBar(
        platform: platform,
        title: null,
        onBack: pane.onBack,
      ),
      body: pane.list,
    );
  }
}

/// Chrome's settings menu; one pane is a page.
class _WebPaneStyle extends SplitPaneStyle {
  const _WebPaneStyle(super.platform, super.geometry);

  @override
  EdgeInsetsGeometry? get listPadding =>
      isSplit ? const EdgeInsets.symmetric(vertical: 8) : null;

  @override
  List<AbstractSettingsSection> listSections(
    List<AbstractSettingsSection> sections,
    Widget? title,
  ) => isSplit
      // Chrome's menu separates its groups with a full-width line.
      ? _interleave(
          _shownSections(sections),
          (_) => const CustomSettingsSection(child: _WebMenuSeparator()),
        )
      : sections;

  @override
  Widget buildListPane(SplitListPaneParts pane) => settingsHeaderOverBody(
    pane.viewContext,
    header: isSplit
        ? _WebMenuHeader(title: pane.title, onBack: pane.onBack)
        : SettingsPageBar(
            platform: platform,
            title: pane.title,
            onBack: pane.onBack,
          ),
    body: pane.list,
  );

  /// Chrome's 680px column, nearer the menu.
  @override
  Widget detailColumn(Widget child) => SettingsContentColumnHint(
    paneWidth: geometry.detailWidth,
    endReserve: webDetailEndReserve(geometry.detailWidth),
    child: child,
  );
}

/// The System Settings sidebar. One pane shows the list as a page of cards.
class _MacosPaneStyle extends SplitPaneStyle {
  const _MacosPaneStyle(super.platform, super.geometry);

  @override
  bool get sidebar => isSplit;

  @override
  EdgeInsetsGeometry? get listPadding => isSplit
      // Room for the first row's focus ring, which the list's viewport
      // would clip: the list starts that much higher (see buildListPane).
      ? const EdgeInsets.only(top: kMacosFocusRingWidth, bottom: 10)
      : null;

  /// A hairline on the sidebar.
  @override
  BorderSide? paneEdge(SettingsThemeData theme) =>
      BorderSide(color: macosSidebarEdgeColor(theme), width: 0.5);

  @override
  List<AbstractSettingsSection> listSections(
    List<AbstractSettingsSection> sections,
    Widget? title,
  ) => isSplit
      ? _interleave(
          _shownSections(sections),
          (_) => const CustomSettingsSection(child: MacosSidebarSectionGap()),
        )
      : sections;

  // The keyboard navigation and the window focus wrap the list in both
  // layouts, so its structure stays the same.
  @override
  Widget buildListPane(SplitListPaneParts pane) => MacosWindowActivity(
    child: SettingsSidebarKeyboard(
      enabled: isSplit,
      selectionFollowsFocus: true,
      child: settingsHeaderOverBody(
        pane.viewContext,
        // The sidebar runs under the title bar; one pane is a page.
        header: isSplit
            ? MacosSidebarTopBar(onBack: pane.onBack)
            : MacosToolbar(title: pane.title, onBack: pane.onBack),
        // The macOS sidebar list reaches up under the (transparent)
        // toolbar strip by the width of the focus ring, which its top
        // padding leaves free, so its first row stays at the strip's
        // bottom and its ring isn't clipped.
        body: CustomSingleChildLayout(
          delegate: _ExtendUpDelegate(isSplit ? kMacosFocusRingWidth : 0),
          child: pane.list,
        ),
      ),
    ),
  );
}

/// Windows Settings' `NavigationView` pane: open, or the compact icon rail
/// ([SplitGeometry.compactPane]). One pane shows the list as a page of
/// cards.
class _FluentPaneStyle extends SplitPaneStyle {
  const _FluentPaneStyle(super.platform, super.geometry);

  @override
  bool get sidebar => isSplit;

  @override
  EdgeInsetsGeometry? get listPadding => isSplit
      // Windows Settings' open pane starts its items 16 from the
      // window edge; the rail and the pane opened from it keep
      // NavigationView's own 4.
      ? EdgeInsetsDirectional.only(
          start: geometry.compactPane ? 0 : kFluentPaneGutter,
          bottom: 8,
        )
      : null;

  @override
  List<AbstractSettingsSection> listSections(
    List<AbstractSettingsSection> sections,
    Widget? title,
  ) => isSplit
      ? _interleave(
          _shownSections(sections),
          (next) => CustomSettingsSection(
            child: FluentPaneSeparator(
              beforeTitle: next is SettingsSection && next.title != null,
            ),
          ),
        )
      : sections;

  // The keyboard navigation and the selection indicator wrap the list in
  // both layouts, so its structure stays the same.
  @override
  Widget buildListPane(SplitListPaneParts pane) => FluentNavigationPane(
    enabled: isSplit,
    child: settingsHeaderOverBody(
      pane.viewContext,
      header: isSplit
          ? FluentPaneHeader(
              title: pane.title,
              onBack: pane.onBack,
              onTogglePane: geometry.compactPane ? pane.onTogglePane : null,
            )
          : FluentPageHeader(title: pane.title, onBack: pane.onBack),
      // One pane shows the title as a Windows page title over the list.
      body: FluentPageTitleAbove(above: !isSplit, child: pane.list),
    ),
  );
}

/// GNOME Settings' sidebar, which it also shows as the first page when it's
/// collapsed to one pane.
class _AdwaitaPaneStyle extends SplitPaneStyle {
  const _AdwaitaPaneStyle(super.platform, super.geometry);

  @override
  bool get sidebar => true;

  @override
  EdgeInsetsGeometry? get listPadding => const EdgeInsets.only(
    top: kAdwaitaSidebarPaddingTop,
    bottom: kAdwaitaSidebarPaddingBottom,
  );

  /// GNOME's 1px sidebar border.
  @override
  BorderSide? paneEdge(SettingsThemeData theme) =>
      BorderSide(color: adwaitaSidebarBorderColor(theme));

  @override
  List<AbstractSettingsSection> listSections(
    List<AbstractSettingsSection> sections,
    Widget? title,
  ) => _interleave(
    _shownSections(sections),
    (_) => const CustomSettingsSection(child: AdwaitaSidebarSeparator()),
  );

  @override
  Widget buildListPane(SplitListPaneParts pane) => SettingsSidebarKeyboard(
    child: settingsHeaderOverBody(
      pane.viewContext,
      header: AdwaitaHeaderBar(title: pane.title, onBack: pane.onBack),
      body: pane.list,
    ),
  );
}

/// [sections] without the [SettingsSection]s that have no tiles (they show
/// nothing), so separators between sections don't double up.
List<AbstractSettingsSection> _shownSections(
  List<AbstractSettingsSection> sections,
) => [
  for (final section in sections)
    if (section is! SettingsSection || section.tiles.isNotEmpty) section,
];

/// [sections] with a separator from [separatorBefore] between each two.
List<AbstractSettingsSection> _interleave(
  List<AbstractSettingsSection> sections,
  AbstractSettingsSection Function(AbstractSettingsSection next)
  separatorBefore,
) => [
  for (final (index, section) in sections.indexed) ...[
    if (index > 0) separatorBefore(section),
    section,
  ],
];

/// Chrome's settings toolbar over the menu: "Settings" in 22px.
class _WebMenuHeader extends StatelessWidget {
  const _WebMenuHeader({required this.title, required this.onBack});

  final Widget? title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            if (onBack != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: SettingsArrowBackButton(
                  onPressed: onBack,
                  iconSize: 20,
                  color: SettingsTheme.of(context).themeData.leadingIconsColor,
                ),
              )
            else
              const SizedBox(width: 24),
            if (title != null)
              Expanded(child: SettingsHeaderTitle(title: title)),
          ],
        ),
      ),
    );
  }
}

/// The line between groups in Chrome's settings menu.
class _WebMenuSeparator extends StatelessWidget {
  const _WebMenuSeparator();

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        height: 1,
        color:
            theme.dividerColor ??
            theme.settingsTileTextColor?.withValues(alpha: 0.12),
      ),
    );
  }
}

/// Lays its child out [extent] taller and that far up, over what is above.
class _ExtendUpDelegate extends SingleChildLayoutDelegate {
  const _ExtendUpDelegate(this.extent);

  final double extent;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.copyWith(
        minHeight: constraints.minHeight + extent,
        maxHeight: constraints.maxHeight + extent,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(0, -extent);

  @override
  bool shouldRelayout(_ExtendUpDelegate oldDelegate) =>
      extent != oldDelegate.extent;
}
