import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// The room a sheet's content keeps even when it is a few rows: below it a
/// short sheet reads as a sliver, not a panel.
const double kAppPanelContentFloor = 280;

/// The app's panel: the kit's [DsPanel] with a floor under the content. A
/// bottom sheet that hugs its content never drops below [minChildHeight]
/// (pass 0 to keep the kit's hug); content taller than the floor grows the
/// sheet as before, up to the sheet's share of the window. Side panels
/// ignore the floor — they are the window's height already.
class AppPanel extends StatelessWidget {
  /// Creates a panel.
  const AppPanel({
    required this.title,
    required this.child,
    super.key,
    this.footer,
    this.showClose,
    this.scrollable = true,
    this.minChildHeight = kAppPanelContentFloor,
    this.semanticLabel,
    this.style,
  });

  /// The panel's name, shown in the header.
  final Widget title;

  /// The content; scrolls when it does not fit, unless [scrollable] is
  /// false.
  final Widget child;

  /// Actions along the bottom, e.g. a full-width primary button.
  final Widget? footer;

  /// Shows a close button in the header. Defaults to whether the panel can
  /// be dismissed.
  final bool? showClose;

  /// Whether the panel scrolls [child] when it does not fit.
  final bool scrollable;

  /// The least height the content keeps, in pixels; 0 keeps the kit's hug.
  final double minChildHeight;

  /// Names the panel for screen readers. Defaults to the [title]'s text.
  final String? semanticLabel;

  /// Style laid over the theme and defaults.
  final DsPanelStyle? style;

  @override
  Widget build(BuildContext context) {
    final floored = minChildHeight > 0
        ? ConstrainedBox(
            constraints: BoxConstraints(minHeight: minChildHeight),
            child: child,
          )
        : child;
    return DsPanel(
      title: title,
      footer: footer,
      showClose: showClose,
      scrollable: scrollable,
      semanticLabel: semanticLabel,
      style: style,
      child: floored,
    );
  }
}

/// Shows a panel built by [builder] (usually an [AppPanel]): from the end
/// edge on wide screens and from the bottom on narrow ones. Escape, the
/// close button, a tap on the scrim, system back and dragging a bottom
/// sheet down close it when [dismissible].
Future<T?> showAppPanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  DsPanelPresentation presentation = DsPanelPresentation.auto,
  bool dismissible = true,
  List<double>? detents,
  double? initialDetent,
  DsScrim scrim = DsScrim.dim,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) => showDsPanel<T>(
  context: context,
  builder: builder,
  presentation: presentation,
  dismissible: dismissible,
  detents: detents,
  initialDetent: initialDetent,
  scrim: scrim,
  useRootNavigator: useRootNavigator,
  routeSettings: routeSettings,
);
