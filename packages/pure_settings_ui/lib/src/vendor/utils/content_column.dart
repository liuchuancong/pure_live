import 'package:flutter/widgets.dart';

/// How a [SettingsList] that fills a split view's detail pane lays out its
/// content column. Internal.
///
/// It only applies to a list exactly [paneWidth] wide (the page body), so
/// lists nested deeper in the page are not affected.
///
/// - [fillWidth]: iPad and Android Settings use the whole detail pane, so
///   an iOS, Android or Fuchsia style list drops its 810 column there. The
///   macOS, Windows and GNOME styles keep their columns and margins, which
///   model the content panes of those platforms' settings apps.
/// - [endReserve]: Chrome's settings page doesn't center the 680px column in
///   the space next to its menu: a spacer at the end grows as fast as the
///   content area, so the column sits closer to the menu. The web detail
///   pane keeps that much space free at the end.
class SettingsContentColumnHint extends InheritedWidget {
  const SettingsContentColumnHint({
    super.key,
    required this.paneWidth,
    this.endReserve = 0,
    this.fillWidth = false,
    required super.child,
  });

  final double paneWidth;
  final double endReserve;
  final bool fillWidth;

  /// The hint for a list [width] wide at [context], if it's the pane's body.
  static SettingsContentColumnHint? of(BuildContext context, double width) {
    final hint = context
        .dependOnInheritedWidgetOfExactType<SettingsContentColumnHint>();
    if (hint == null || (hint.paneWidth - width).abs() > 0.5) return null;
    return hint;
  }

  /// The width to reserve for a list [width] wide at [context].
  static double endReserveFor(BuildContext context, double width) =>
      of(context, width)?.endReserve ?? 0;

  @override
  bool updateShouldNotify(SettingsContentColumnHint oldWidget) =>
      paneWidth != oldWidget.paneWidth ||
      endReserve != oldWidget.endReserve ||
      fillWidth != oldWidget.fillWidth;
}
