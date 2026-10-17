import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_metrics.dart';
import 'package:pure_settings_ui/src/vendor/sections/abstract_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/platforms/adwaita_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/platforms/fluent_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/platforms/macos_settings_section.dart';
import 'package:pure_settings_ui/src/vendor/sections/settings_section.dart';
import 'package:pure_settings_ui/src/vendor/split/split_geometry.dart';
import 'package:pure_settings_ui/src/vendor/utils/content_column.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_settings_ui/src/vendor/utils/unresolved_platform.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureTheme;

/// Where a [SettingsList] reads light or dark mode from when
/// [SettingsList.brightness] is null.
enum ApplicationType {
  /// Use this parameter if you are using the MaterialApp
  material,

  /// Use this parameter if you are using the CupertinoApp
  cupertino,

  /// Use this parameter if you are using the MaterialApp for Android
  /// and the CupertinoApp for iOS. On iOS and macOS the brightness comes from
  /// the CupertinoTheme, which follows the Material theme in a MaterialApp.
  both,
}

/// A scrollable settings screen in the platform's style.
///
/// It picks one of six styles from [platform] (auto-detected by default):
/// iOS, macOS, Windows, Android (also Fuchsia), GNOME (Linux) or web. Colors
/// come from the style's defaults and the app theme, merged with [lightTheme]
/// or [darkTheme], and on wide screens the content stays in a column (see
/// [contentPadding]).
class SettingsList extends StatelessWidget {
  /// Creates a settings list from [sections].
  const SettingsList({
    required this.sections,
    this.shrinkWrap = false,
    this.physics,
    this.platform,
    this.lightTheme,
    this.darkTheme,
    this.brightness,
    this.contentPadding,
    this.scrollController,
    this.applicationType = ApplicationType.material,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    super.key,
  });

  /// Passed to the inner [ListView]. Set it, with [physics], to put the list
  /// inside another scroll view.
  final bool shrinkWrap;

  /// Passed to the inner [ListView].
  final ScrollPhysics? physics;

  /// The style to use. Null or [DevicePlatform.device] detects it from the
  /// app: [DevicePlatform.web] in a browser, otherwise the one for
  /// `Theme.of(context).platform`.
  final DevicePlatform? platform;

  /// Colors and text styles merged over the style's defaults in light mode.
  final SettingsThemeData? lightTheme;

  /// Colors and text styles merged over the style's defaults in dark mode.
  final SettingsThemeData? darkTheme;

  /// Forces light or dark colors. When null, the brightness comes from the
  /// app theme, as set by [applicationType].
  ///
  /// The Android and web styles take their colors from the app's
  /// [ColorScheme]. When it has the other brightness, they use a scheme of
  /// this brightness made from its primary color
  /// (`ColorScheme.fromSeed`), for the list and for the Material widgets in
  /// it.
  final Brightness? brightness;

  /// Replaces the default padding of the inner [ListView]. The default keeps
  /// the tiles in the style's content column on wide lists (810 wide, 680 on
  /// the web, 640 on macOS, 1000 on Windows, at most 600 on Linux); see
  /// [calculateDefaultPadding].
  final EdgeInsetsGeometry? contentPadding;

  /// The sections, top to bottom: [SettingsSection]s,
  /// `CustomSettingsSection`s or your own [AbstractSettingsSection]s.
  final List<AbstractSettingsSection> sections;

  /// Where light or dark mode comes from when [brightness] is null.
  final ApplicationType applicationType;

  /// Passed to the inner [ListView].
  final ScrollController? scrollController;

  /// Controls how the settings list is aligned along the cross axis.
  /// Defaults to [CrossAxisAlignment.center] (content is centered on wide
  /// screens). Use [CrossAxisAlignment.start] to align the content with the
  /// start edge (left in LTR, right in RTL). Has no effect when
  /// [contentPadding] is set.
  final CrossAxisAlignment crossAxisAlignment;

  static bool _debugDidWarnMissingTheme = false;

  /// Lets tests see the missing-theme warning again after it was printed.
  @visibleForTesting
  static void debugResetMissingThemeWarning() {
    _debugDidWarnMissingTheme = false;
  }

  /// Colors, brightness and the style itself come from pure_uikit's resolved
  /// `PureTheme`, so a list under a `PureConfigProvider` follows the app's
  /// design language, accent and brightness. Without one this widget degrades
  /// to the device platform and to default colors. Say so once in debug builds.
  void _debugWarnIfMissingTheme(BuildContext context) {
    if (_debugDidWarnMissingTheme) return;
    if (PureTheme.maybeOf(context) != null) return;
    _debugDidWarnMissingTheme = true;
    debugPrint(
      'pure_settings_ui: SettingsList found no PureTheme above it, so it '
      'detects the device platform instead of the app design language and '
      'uses default colors. Wrap the app in pure_uikit PureConfigProvider '
      '(PureApp does) to get the design-language style.',
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      _debugWarnIfMissingTheme(context);
      return true;
    }());

    // A list in a page opened from a settings tile takes the style inputs it
    // leaves unset from the list that opened the page.
    final config = SettingsStyleConfig(
      platform: this.platform,
      brightness: brightness,
      lightTheme: lightTheme,
      darkTheme: darkTheme,
      applicationType: applicationType,
    ).inheritFrom(SettingsStyleScope.inheritedConfigOf(context));
    final style = config.resolve(context);
    final platform = style.platform;
    final themeData = style.themeData;
    // A Windows list right under a page title starts closer to it: its
    // first section that shows anything is told so.
    final underPageTitle =
        platform == DevicePlatform.windows && FluentPageTitleAbove.of(context);
    final afterPageTitleIndex = underPageTitle ? _firstShownIndex : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the width the parent gives the list, not the screen width, so
        // a list in a narrow pane of a wide window fits the pane. Fall back to
        // the screen width when the width is unbounded.
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        return Container(
          color: themeData.settingsListBackground,
          width: width,
          alignment: crossAxisAlignment == CrossAxisAlignment.start
              ? AlignmentDirectional.topStart
              : Alignment.center,
          child: SettingsStyleScope(
            config: style.resolvedConfig,
            child: SettingsTheme(
              themeData: themeData,
              platform: platform,
              child: FluentPageTitleAbove(
                // Not for lists nested in this one.
                above: false,
                child: ListView.builder(
                  controller: scrollController,
                  physics: physics,
                  shrinkWrap: shrinkWrap,
                  itemCount: sections.length,
                  padding:
                      contentPadding ??
                      _defaultPadding(context, platform, width),
                  itemBuilder: (BuildContext context, int index) {
                    if (index == afterPageTitleIndex) {
                      return FluentSectionContext(
                        afterPageTitle: true,
                        child: sections[index],
                      );
                    }
                    if (platform != DevicePlatform.macOS) {
                      return sections[index];
                    }
                    return MacosSectionContext(
                      followsFooter: _previousEndsWithFooter(index),
                      child: sections[index],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// [calculateDefaultPadding], adjusted for a split view's detail pane
  /// (see [SettingsContentColumnHint]).
  EdgeInsets _defaultPadding(
    BuildContext context,
    DevicePlatform platform,
    double width,
  ) {
    final hint = SettingsContentColumnHint.of(context, width);
    if (hint != null && hint.fillWidth && _fillsDetailPane(platform)) {
      // A page in the detail pane of iPad or Android Settings fills the
      // pane: no spare width to turn into side padding. (These styles have
      // no minimum side padding, so a zero width gives just that.)
      return calculateDefaultPadding(platform, context, width: 0);
    }
    final reserve = hint?.endReserve ?? 0;
    final padding = calculateDefaultPadding(
      platform,
      context,
      width: width - reserve,
    );
    if (reserve == 0) return padding;
    final isRtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return padding.copyWith(
      left: isRtl ? padding.left + reserve : null,
      right: isRtl ? null : padding.right + reserve,
    );
  }

  /// Whether a list in this style fills a split view's detail pane.
  ///
  /// iPad and Android Settings pages use the whole detail pane. The content
  /// panes of macOS System Settings, Windows Settings and GNOME Settings are
  /// what these styles' own columns and margins model, so they keep them
  /// there; the web style keeps Chrome's 680px column.
  static bool _fillsDetailPane(DevicePlatform platform) {
    switch (platform) {
      case DevicePlatform.iOS:
      case DevicePlatform.android:
      case DevicePlatform.fuchsia:
      // The pure style is a card list like these three, with no column of its
      // own to preserve in a detail pane.
      case DevicePlatform.pure:
        return true;
      case DevicePlatform.macOS:
      case DevicePlatform.windows:
      case DevicePlatform.linux:
      case DevicePlatform.web:
      case DevicePlatform.device:
        return false;
    }
  }

  /// The list padding used when [contentPadding] is null.
  ///
  /// When [width] (the list's width, the screen width by default) is wider
  /// than the content column, the spare width becomes side padding. It is
  /// split evenly, or all put at the end with [CrossAxisAlignment.start].
  EdgeInsets calculateDefaultPadding(
    DevicePlatform platform,
    BuildContext context, {
    double? width,
  }) {
    final availableWidth = width ?? MediaQuery.sizeOf(context).width;
    final double contentWidth;
    final double minSidePadding;
    final double topPadding;
    final double bottomPadding;
    switch (platform) {
      case DevicePlatform.android:
      case DevicePlatform.fuchsia:
      case DevicePlatform.iOS:
        contentWidth = math.min(availableWidth, 810);
        minSidePadding = 0;
        topPadding = 0;
        bottomPadding = 0;
      case DevicePlatform.macOS:
        // System Settings has a fixed-width window, so its cards are never
        // wider than about 470pt. A 640pt column (600pt cards) keeps each
        // label close to its control in wide windows.
        contentWidth = math.min(availableWidth, 640);
        minSidePadding = 0;
        // The first card starts 12pt down, and a first header 20pt down
        // (its section's own top margin), like in System Settings.
        topPadding = _startsWithHeader ? 0 : 12;
        // With the last section's 10pt bottom margin: 20pt below the last
        // card, like System Settings.
        bottomPadding = 10;
      case DevicePlatform.linux:
        // A GNOME preferences page clamps its content like AdwClamp: at most
        // 600sp wide, easing in from 400sp. sp grow as much as body text
        // does (see adwaitaSpScale). The groups keep their own 12px side
        // margins and 24px gap below; the page adds 24px on top.
        final sp = adwaitaSpScale(MediaQuery.textScalerOf(context));
        contentWidth = adwaitaClampWidth(
          availableWidth,
          maximumSize: 600 * sp,
          tighteningThreshold: 400 * sp,
        );
        minSidePadding = 0;
        topPadding = kAdwaitaPageTopMargin;
        bottomPadding = 0;
      case DevicePlatform.windows:
        // Windows 11 Settings pages: 24 margins, down to 16 below the
        // NavigationView's minimal-mode width (641), a column of at most
        // 1000, and 36 at the bottom (the last section adds 3). Section
        // headers bring their own 30 at the top.
        contentWidth = math.min(availableWidth, 1000);
        minSidePadding = availableWidth < 641 ? 16 : 24;
        topPadding = 0;
        bottomPadding = 33;
      case DevicePlatform.web:
        // Chrome's settings page uses a 680px column and keeps the cards off
        // the edges of narrow browser windows.
        contentWidth = math.min(availableWidth, 680);
        minSidePadding = 16;
        topPadding = 20;
        bottomPadding = 20;
      case DevicePlatform.pure:
        // pure_uikit's own scale rather than a measured settings app: the
        // reading column the uikit hands its hosts, and the gutters the app's
        // pages already use.
        contentWidth = math.min(availableWidth, pureSettingsContentWidth);
        minSidePadding = pureSettingsSidePadding;
        topPadding = pureSettingsTopPadding;
        bottomPadding = pureSettingsBottomPadding;
      case DevicePlatform.device:
        throwUnresolvedPlatform('SettingsList.calculateDefaultPadding');
    }

    final centeredSidePadding = (availableWidth - contentWidth) / 2;
    final sidePadding = centeredSidePadding > minSidePadding
        ? centeredSidePadding
        : minSidePadding;

    if (crossAxisAlignment == CrossAxisAlignment.start) {
      // Same column width as when centered, at the start edge.
      return EdgeInsetsDirectional.only(
        start: minSidePadding,
        end: 2 * sidePadding - minSidePadding,
        top: topPadding,
        bottom: bottomPadding,
      ).resolve(Directionality.maybeOf(context) ?? TextDirection.ltr);
    }
    return EdgeInsets.only(
      left: sidePadding,
      right: sidePadding,
      top: topPadding,
      bottom: bottomPadding,
    );
  }

  /// Whether the last section shown before [index] ends with a footer.
  /// Sections without tiles show nothing, so they are skipped.
  bool _previousEndsWithFooter(int index) {
    for (var i = index - 1; i >= 0; i--) {
      if (_isShown(sections[i])) return macosSectionEndsWithFooter(sections[i]);
    }
    return false;
  }

  /// Whether [section] shows anything: a [SettingsSection] without tiles
  /// doesn't.
  static bool _isShown(AbstractSettingsSection section) =>
      !(section is SettingsSection && section.tiles.isEmpty);

  /// The index of the first section that shows anything.
  int get _firstShownIndex {
    final index = sections.indexWhere(_isShown);
    return index < 0 ? 0 : index;
  }

  /// Whether the first section that shows anything is a [SettingsSection]
  /// with a title.
  bool get _startsWithHeader {
    final first = sections.where(_isShown).firstOrNull;
    return first is SettingsSection && first.title != null;
  }

  /// The brightness this list uses: [brightness], or the app theme's as
  /// chosen by [applicationType].
  Brightness calculateBrightness(BuildContext context) {
    return SettingsStyleConfig(
      brightness: brightness,
      applicationType: applicationType,
    ).resolveBrightness(context);
  }
}
