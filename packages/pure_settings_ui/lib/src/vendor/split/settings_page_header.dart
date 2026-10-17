import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/pure/pure_page_bar.dart';
import 'package:pure_settings_ui/src/vendor/split/adwaita_split.dart';
import 'package:pure_settings_ui/src/vendor/split/fluent_split.dart';
import 'package:pure_settings_ui/src/vendor/split/macos_split.dart';
import 'package:pure_settings_ui/src/vendor/split/settings_page_trail.dart';
import 'package:pure_settings_ui/src/vendor/split/split_geometry.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_press.dart';
import 'package:pure_settings_ui/src/vendor/utils/content_column.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

/// "Back", from the app's localizations when it has them.
String settingsBackLabel(BuildContext context) =>
    Localizations.of<MaterialLocalizations>(
      context,
      MaterialLocalizations,
    )?.backButtonTooltip ??
    'Back';

/// "Open navigation menu", from the app's localizations when it has them
/// (a `CupertinoApp` or a `WidgetsApp` has no [MaterialLocalizations]).
String settingsMenuLabel(BuildContext context) =>
    Localizations.of<MaterialLocalizations>(
      context,
      MaterialLocalizations,
    )?.openAppDrawerTooltip ??
    'Open navigation menu';

/// Whether the device is an iPad-size tablet or a desktop, where the
/// Cupertino bars are taller and their buttons sit closer to the edge.
bool _isRegularWidthDevice(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= 600 ||
    isDesktopPlatform(Theme.of(context).platform);

/// The bar at the top of a settings page: back button, title and actions,
/// drawn in the style of [platform]. Internal.
///
/// - Cupertino: iOS 26+ navigation bar, inline 17pt semibold title centered
///   on the page, 44pt round glass back button.
/// - Material: 64dp top app bar with an arrow back button and a 22sp title.
/// - Web: the page title as a heading over the content column, with an arrow
///   back button before it when there is somewhere to go back to.
/// - macOS: the 52pt System Settings toolbar ([MacosToolbar]).
/// - Windows: the Windows Settings page title, a breadcrumb on pages opened
///   from another page ([FluentPageHeader]).
/// - GNOME: a flat 46px header bar with the title in the middle
///   ([AdwaitaHeaderBar]).
class SettingsPageBar extends StatelessWidget {
  const SettingsPageBar({
    super.key,
    required this.platform,
    required this.title,
    this.actions,
    this.onBack,
    this.showTitle = true,
    this.parents = const <SettingsPageTrailEntry>[],
  });

  final DevicePlatform platform;
  final Widget? title;
  final List<Widget>? actions;

  /// The pages above this one, for the Windows style's breadcrumb.
  final List<SettingsPageTrailEntry> parents;

  /// Shows a back button that calls this.
  final VoidCallback? onBack;

  /// False hides the title but keeps the bar (a list page whose large title
  /// is still on screen). Only the iOS style has such a page; the other
  /// styles don't read it.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    switch (settingsStyleFamily(platform)) {
      case SettingsStyleFamily.cupertino:
        return _buildCupertino(context, theme);
      case SettingsStyleFamily.material:
        return _buildMaterial(theme);
      case SettingsStyleFamily.web:
        return _buildWeb(theme);
      case SettingsStyleFamily.macos:
        return MacosToolbar(title: title, onBack: onBack, actions: actions);
      case SettingsStyleFamily.fluent:
        return FluentPageHeader(
          title: title,
          parents: parents,
          onBack: onBack,
          actions: actions,
        );
      case SettingsStyleFamily.adwaita:
        return AdwaitaHeaderBar(title: title, onBack: onBack, actions: actions);
      case SettingsStyleFamily.pure:
        return PurePageBar(title: title, onBack: onBack, actions: actions);
    }
  }

  Widget _buildCupertino(BuildContext context, SettingsThemeData theme) {
    final regular = _isRegularWidthDevice(context);
    final edge = regular ? 10.0 : 16.0;
    final title = this.title;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: regular ? 60 : 44,
        child: NavigationToolbar(
          leading: onBack == null
              ? null
              : Padding(
                  padding: EdgeInsetsDirectional.only(start: edge),
                  child: SettingsGlassBackButton(onPressed: onBack!),
                ),
          middle: title == null
              ? null
              : AnimatedOpacity(
                  opacity: showTitle ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: theme.settingsTileTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: Semantics(header: true, child: title),
                  ),
                ),
          trailing: _actionsRow(actions, end: edge),
          middleSpacing: 8,
        ),
      ),
    );
  }

  Widget _buildMaterial(SettingsThemeData theme) {
    final title = this.title;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 64,
        child: _MaterialToolbarRow(
          onBack: onBack,
          color: theme.settingsTileTextColor,
          title: title == null
              ? const SizedBox.shrink()
              : SettingsHeaderTitle(title: title),
          actions: actions,
        ),
      ),
    );
  }

  Widget _buildWeb(SettingsThemeData theme) {
    final title = this.title;
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = webContentColumn(context, constraints.maxWidth);
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        return SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: isRtl ? column.right : column.left,
              end: isRtl ? column.left : column.right,
            ),
            // Chrome's 56px toolbar row, level with the menu's "Settings".
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  if (onBack != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: Transform.translate(
                        // Line the arrow up with the column edge.
                        offset: Offset(isRtl ? 8 : -8, 0),
                        child: SettingsArrowBackButton(
                          onPressed: onBack,
                          iconSize: 20,
                          color: theme.leadingIconsColor,
                        ),
                      ),
                    ),
                  Expanded(
                    child: title == null
                        ? const SizedBox.shrink()
                        : SettingsHeaderTitle(title: title),
                  ),
                  ?_actionsRow(actions, end: 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// [actions] in a row that ends [end] before the header's end edge. Null
/// when there are none.
Widget? _actionsRow(List<Widget>? actions, {required double end}) {
  if (actions == null || actions.isEmpty) return null;
  return Padding(
    padding: EdgeInsetsDirectional.only(end: end),
    child: Row(mainAxisSize: MainAxisSize.min, children: actions),
  );
}

/// A page: [header] over [body], which fills the rest of it. The header
/// covers the top safe area, so the body gets the `MediaQuery` at [context]
/// without the top padding.
Widget settingsHeaderOverBody(
  BuildContext context, {
  required Widget header,
  required Widget body,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    header,
    Expanded(
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: body,
      ),
    ),
  ],
);

/// The arrow back button of the Android and web headers.
class SettingsArrowBackButton extends StatelessWidget {
  const SettingsArrowBackButton({
    super.key,
    required this.onPressed,
    required this.color,
    this.iconSize,
  });

  final VoidCallback? onPressed;
  final Color? color;

  /// Defaults to the icon button's own size.
  final double? iconSize;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    iconSize: iconSize,
    icon: Icon(Icons.arrow_back, semanticLabel: settingsBackLabel(context)),
    color: color,
  );
}

/// The title of the Android and web headers: 22px on one line, a header to
/// screen readers.
class SettingsHeaderTitle extends StatelessWidget {
  const SettingsHeaderTitle({super.key, required this.title});

  final Widget title;

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
    style: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w400,
      color: SettingsTheme.of(context).themeData.settingsTileTextColor,
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    child: Semantics(header: true, child: title),
  );
}

/// The row of Android's 64dp action bar: an arrow back button (further in
/// on tablets), the title and the actions.
class _MaterialToolbarRow extends StatelessWidget {
  const _MaterialToolbarRow({
    required this.onBack,
    required this.color,
    required this.title,
    required this.actions,
  });

  final VoidCallback? onBack;
  final Color? color;

  /// The title as the bar draws it. It gets the space between the back
  /// button and the actions.
  final Widget title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return Row(
      children: [
        if (onBack != null)
          Padding(
            padding: EdgeInsetsDirectional.only(start: tablet ? 12 : 4, end: 8),
            child: SettingsArrowBackButton(onPressed: onBack, color: color),
          )
        else
          const SizedBox(width: 24),
        Expanded(child: title),
        ?_actionsRow(actions, end: 4),
      ],
    );
  }
}

/// The horizontal extent of the web content column in a pane [width] wide:
/// Chrome's 680px column, centered, with 16px margins in narrow windows. In
/// a split view's web detail pane, the column moves toward the menu like
/// Chrome's (see [SettingsContentColumnHint]).
({double left, double right}) webContentColumn(
  BuildContext context,
  double width,
) {
  final reserve = SettingsContentColumnHint.endReserveFor(context, width);
  final available = width - reserve;
  final side = math.max(16.0, (available - 680) / 2);
  final isRtl = Directionality.of(context) == TextDirection.rtl;
  return isRtl
      ? (left: side + reserve, right: side)
      : (left: side, right: side + reserve);
}

/// The keyboard focus ring of a Cupertino control, as `CupertinoButton`
/// makes it from the system blue.
final Color _cupertinoFocusColor =
    HSLColor.fromColor(
          CupertinoColors.activeBlue.withValues(
            alpha: kCupertinoFocusColorOpacity,
          ),
        )
        .withLightness(kCupertinoFocusColorBrightness)
        .withSaturation(kCupertinoFocusColorSaturation)
        .toColor();

/// The iOS 26+ round back button: a 44pt glass circle with a chevron. Tab
/// reaches it, and Enter or Space press it.
class SettingsGlassBackButton extends StatefulWidget {
  const SettingsGlassBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<SettingsGlassBackButton> createState() =>
      _SettingsGlassBackButtonState();
}

class _SettingsGlassBackButtonState extends State<SettingsGlassBackButton> {
  bool _pressed = false;
  bool _focusHighlight = false;

  /// Enter and Space on the focused button go back.
  late final Map<Type, Action<Intent>> _actions = tileActivateActions(
    () => widget.onPressed(),
  );

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final isDark =
        (theme.settingsListBackground?.computeLuminance() ?? 1) < 0.2;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    // Measured on iPadOS 27: #F4F4F8 over #F2F2F7 with a faint rim.
    final fill = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF7F7FA);
    final rim = isDark ? const Color(0x33FFFFFF) : const Color(0x14000000);

    return Semantics(
      container: true,
      button: true,
      label: settingsBackLabel(context),
      child: FocusableActionDetector(
        actions: _actions,
        // The node stays as it is: a button with a tap action.
        includeFocusSemantics: false,
        onShowFocusHighlight: (value) {
          if (value != _focusHighlight) {
            setState(() => _focusHighlight = value);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _pressed ? 1.08 : 1,
            duration: const Duration(milliseconds: 120),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(color: rim, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Color(isDark ? 0x40000000 : 0x0F000000),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              // The keyboard focus ring of a Cupertino button, inside the
              // circle: the 44pt bar of a phone has no room around it.
              foregroundDecoration: _focusHighlight
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _cupertinoFocusColor,
                        width: 3.5,
                      ),
                    )
                  : null,
              alignment: Alignment.center,
              child: Padding(
                // The chevron's ink sits left of the glyph center.
                padding: EdgeInsetsDirectional.only(end: isRtl ? 0 : 2),
                child: Icon(
                  isRtl
                      ? CupertinoIcons.chevron_forward
                      : CupertinoIcons.chevron_back,
                  size: 22,
                  color: theme.settingsTileTextColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The large title at the top of an iOS list's scroll content: 34pt bold,
/// like the Settings root on iPhone and the sidebar title on iPadOS 18. The
/// bar above shows the inline title once it scrolls away.
class SettingsLargeTitle extends StatelessWidget {
  const SettingsLargeTitle({super.key, required this.title});

  final Widget title;

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: 20,
          end: 20,
          top: 3,
          bottom: 8,
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            height: 41 / 34,
            color: theme.settingsTileTextColor,
          ),
          child: title,
        ),
      ),
    );
  }
}

/// Android 16 Settings pages: a 64dp action bar with a 36sp title under it
/// that collapses into the bar as the page scrolls. The [body] should be a
/// scroll view that uses the [PrimaryScrollController], as a [SettingsList]
/// without a scrollController does.
class SettingsCollapsingTitleView extends StatelessWidget {
  const SettingsCollapsingTitleView({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.onBack,
    this.background,
  });

  final Widget title;
  final Widget body;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  /// Defaults to the page background.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = SettingsTheme.of(context).themeData;
    final delegate = _CollapsingTitleDelegate(
      topPadding: MediaQuery.paddingOf(context).top,
      title: title,
      actions: actions,
      onBack: onBack,
      background:
          background ?? theme.settingsListBackground ?? const Color(0x00000000),
      foreground: theme.settingsTileTextColor,
    );
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverPersistentHeader(pinned: true, delegate: delegate),
      ],
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: body,
      ),
    );
  }
}

class _CollapsingTitleDelegate extends SliverPersistentHeaderDelegate {
  _CollapsingTitleDelegate({
    required this.topPadding,
    required this.title,
    required this.actions,
    required this.onBack,
    required this.background,
    required this.foreground,
  });

  // Measured on Android 16: a 64dp action bar and a 179dp app bar.
  static const double _toolbarHeight = 64;
  static const double _titleAreaHeight = 115;

  final double topPadding;
  final Widget title;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final Color background;
  final Color? foreground;

  @override
  double get minExtent => topPadding + _toolbarHeight;

  @override
  double get maxExtent => minExtent + _titleAreaHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = (shrinkOffset / _titleAreaHeight).clamp(0.0, 1.0);
    return ColoredBox(
      color: background,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PositionedDirectional(
              start: 24,
              end: 24,
              bottom: 22,
              child: Opacity(
                opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                child: Semantics(
                  header: true,
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w400,
                      height: 44 / 36,
                      color: foreground,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    child: title,
                  ),
                ),
              ),
            ),
            Positioned(
              top: topPadding,
              left: 0,
              right: 0,
              height: _toolbarHeight,
              child: _MaterialToolbarRow(
                onBack: onBack,
                color: foreground,
                title: ExcludeSemantics(
                  child: Opacity(
                    opacity: ((t - 0.7) / 0.3).clamp(0.0, 1.0),
                    child: DefaultTextStyle(
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                        color: foreground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: title,
                    ),
                  ),
                ),
                actions: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_CollapsingTitleDelegate oldDelegate) =>
      topPadding != oldDelegate.topPadding ||
      title != oldDelegate.title ||
      actions != oldDelegate.actions ||
      onBack != oldDelegate.onBack ||
      background != oldDelegate.background ||
      foreground != oldDelegate.foreground;
}
