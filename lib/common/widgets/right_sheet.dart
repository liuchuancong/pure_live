import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<T?> showModalRightSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool clickEmptyPop = false,
  RouteSettings? routeSettings,
  bool useRootNavigator = false,
  bool enableDrag = true,
  double elevation = 0.0,
  Color? dragHandleColor,
  Size? dragHandleSize,
  Color? backgroundColor,
  Color? shadowColor,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
}) {
  assert(debugCheckHasMediaQuery(context));
  assert(debugCheckHasMaterialLocalizations(context));

  final NavigatorState navigator =
      Navigator.of(context, rootNavigator: useRootNavigator);
  // final MaterialLocalizations localizations = MaterialLocalizations.of(context);
  return navigator.push(_ModalRightSheetRoute<T>(
    builder: builder,
    clickEmptyPop: clickEmptyPop,
    theme: Theme.of(context),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    settings: routeSettings,
    enableDrag: enableDrag,
    elevation: elevation,
    dragHandleColor: dragHandleColor,
    dragHandleSize: dragHandleSize,
    backgroundColor: backgroundColor,
    shape: shape,
    clipBehavior: clipBehavior,
    constraints: constraints,
  ));
}

const Duration _kRightSheetDuration = Duration(milliseconds: 200);
const double _kMinFlingVelocity = 700.0;
const double _kCloseProgressThreshold = 0.5;

class _ModalRightSheetRoute<T> extends PopupRoute<T> {
  _ModalRightSheetRoute({
    required this.builder,
    required this.theme,
    required this.barrierLabel,
    required this.clickEmptyPop,
    required super.settings,
    required this.enableDrag,
    required this.elevation,
    this.dragHandleColor,
    this.dragHandleSize,
    this.backgroundColor,
    this.shadowColor,
    this.shape,
    this.clipBehavior,
    this.constraints,
  });

  final WidgetBuilder builder;
  final ThemeData theme;
  final bool clickEmptyPop;
  final bool enableDrag;
  final double elevation;
  final Color? dragHandleColor;
  final Size? dragHandleSize;
  final Color? backgroundColor;
  final Color? shadowColor;
  final ShapeBorder? shape;
  final Clip? clipBehavior;
  final BoxConstraints? constraints;

  @override
  Duration get transitionDuration => _kRightSheetDuration;

  @override
  bool get barrierDismissible => true;

  @override
  final String barrierLabel;

  @override
  Color get barrierColor => Colors.black54;

  AnimationController? _animationController;

  @override
  AnimationController createAnimationController() {
    assert(_animationController == null);
    _animationController = RightSheet.createAnimationController(navigator!);
    return _animationController!;
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    // By definition, the right sheet is aligned to the right of the page
    // and isn't exposed to the top padding of the MediaQuery.
    Widget rightSheet = MediaQuery.removePadding(
      context: context,
      removeTop: false,
      child: _ModalRightSheet<T>(
        route: this,
        clickEmptyPop: clickEmptyPop,
        enableDrag: enableDrag,
        elevation: elevation,
        dragHandleColor: dragHandleColor,
        dragHandleSize: dragHandleSize,
        backgroundColor: backgroundColor,
        shape: shape,
        clipBehavior: clipBehavior,
        constraints: constraints,
      ),
    );
    rightSheet = Theme(data: theme, child: rightSheet);
    return rightSheet;
  }
}

class _ModalRightSheet<T> extends StatefulWidget {
  const _ModalRightSheet(
      {super.key,
      required this.route,
      this.clickEmptyPop = true,
      required this.enableDrag,
      required this.elevation,
      this.dragHandleColor,
      this.dragHandleSize,
      this.backgroundColor,
      this.shadowColor,
      this.shape,
      this.clipBehavior,
      this.constraints});

  final _ModalRightSheetRoute<T> route;
  final bool clickEmptyPop;

  final bool enableDrag;
  final double elevation;
  final Color? dragHandleColor;
  final Size? dragHandleSize;
  final Color? backgroundColor;
  final Color? shadowColor;
  final ShapeBorder? shape;
  final Clip? clipBehavior;
  final BoxConstraints? constraints;

  @override
  _ModalRightSheetState<T> createState() => _ModalRightSheetState<T>();
}

class _ModalRightSheetState<T> extends State<_ModalRightSheet<T>> {
  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final MaterialLocalizations localizations =
        MaterialLocalizations.of(context);
    String? routeLabel= '';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        routeLabel = '';
        break;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        routeLabel = localizations.dialogLabel;
        break;
      }

    return GestureDetector(
        excludeFromSemantics: true,
        onTap: widget.clickEmptyPop ? () => Navigator.pop(context) : null,
        child: AnimatedBuilder(
            animation: widget.route.animation!,
            builder: (context, child) {
              // Disable the initial animation when accessible navigation is on so
              // that the semantics are added to the tree at the correct time.
              final double animationValue = mediaQuery.accessibleNavigation
                  ? 1.0
                  : widget.route.animation!.value;
              return Semantics(
                scopesRoute: true,
                namesRoute: true,
                label: routeLabel,
                explicitChildNodes: true,
                child: ClipRect(
                  child: CustomSingleChildLayout(
                    delegate: _ModalRightSheetLayout(animationValue),
                    child: RightSheet(
                      animationController: widget.route._animationController,
                      onClosing: () => Navigator.pop(context),
                      builder: widget.route.builder,
                      enableDrag: widget.enableDrag,
                      backgroundColor: widget.backgroundColor,
                      elevation: widget.elevation,
                      shape: widget.shape,
                      clipBehavior: widget.clipBehavior,
                      constraints: widget.constraints,
                    ),
                  ),
                ),
              );
            }));
  }
}

class _ModalRightSheetLayout extends SingleChildLayoutDelegate {
  _ModalRightSheetLayout(this.progress);

  final double progress;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
        minWidth: 0.0,
        maxWidth: constraints.maxWidth,
        minHeight: constraints.maxHeight,
        maxHeight: constraints.maxHeight);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    return Offset(size.width - childSize.width * progress, 0.0);
  }

  @override
  bool shouldRelayout(_ModalRightSheetLayout oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

class RightSheet extends StatefulWidget {
  /// Creates a right sheet.
  ///
  /// Typically, right sheets are created implicitly by
  /// [ScaffoldState.showRightSheet], for persistent right sheets, or by
  /// [showModalRightSheet], for modal right sheets.
  const RightSheet({
    super.key,
    this.animationController,
    this.enableDrag = true,
    this.showDragHandle,
    this.dragHandleColor,
    this.dragHandleSize,
    this.onDragStart,
    this.onDragEnd,
    this.backgroundColor,
    this.shadowColor,
    this.elevation = 0.0,
    this.shape,
    this.clipBehavior,
    this.constraints,
    required this.onClosing,
    required this.builder,
  });

  /// The animation that controls the right sheet's position.
  ///
  /// The RightSheet widget will manipulate the position of this animation, it
  /// is not just a passive observer.
  final AnimationController? animationController;

  /// Called when the right sheet begins to close.
  ///
  /// A right sheet might be prevented from closing (e.g., by user
  /// interaction) even after this callback is called. For this reason, this
  /// callback might be call multiple times for a given right sheet.
  final VoidCallback onClosing;

  /// A builder for the contents of the sheet.
  ///
  /// The right sheet will wrap the widget produced by this builder in a
  /// [Material] widget.
  final WidgetBuilder builder;

  /// If true, the right sheet can dragged up and down and dismissed by swiping
  ///
  /// Default is true.
  final bool enableDrag;

  /// The z-coordinate at which to place this material. This controls the size
  /// of the shadow below the material.
  ///
  /// Defaults to 0.
  final double elevation;

  /// Specifies whether a drag handle is shown.
  ///
  /// The drag handle appears at the top of the bottom sheet. The default color is
  /// [ColorScheme.onSurfaceVariant] with an opacity of 0.4 and can be customized
  /// using [dragHandleColor]. The default size is `Size(32,4)` and can be customized
  /// with [dragHandleSize].
  ///
  /// If null, then the value of [BottomSheetThemeData.showDragHandle] is used. If
  /// that is also null, defaults to false.
  ///
  /// If this is true, the [animationController] must not be null.
  /// Use [BottomSheet.createAnimationController] to create one, or provide
  /// another AnimationController.
  final bool? showDragHandle;

  /// The bottom sheet drag handle's color.
  ///
  /// Defaults to [BottomSheetThemeData.dragHandleColor].
  /// If that is also null, defaults to [ColorScheme.onSurfaceVariant].
  final Color? dragHandleColor;

  /// Defaults to [BottomSheetThemeData.dragHandleSize].
  /// If that is also null, defaults to Size(32, 4).
  final Size? dragHandleSize;

  /// Called when the user begins dragging the bottom sheet vertically, if
  /// [enableDrag] is true.
  ///
  /// Would typically be used to change the bottom sheet animation curve so
  /// that it tracks the user's finger accurately.
  final BottomSheetDragStartHandler? onDragStart;

  /// Called when the user stops dragging the bottom sheet, if [enableDrag]
  /// is true.
  ///
  /// Would typically be used to reset the bottom sheet animation curve, so
  /// that it animates non-linearly. Called before [onClosing] if the bottom
  /// sheet is closing.
  final BottomSheetDragEndHandler? onDragEnd;

  /// The bottom sheet's background color.
  ///
  /// Defines the bottom sheet's [Material.color].
  ///
  /// Defaults to null and falls back to [Material]'s default.
  final Color? backgroundColor;

  /// The color of the shadow below the sheet.
  ///
  /// If this property is null, then [BottomSheetThemeData.shadowColor] of
  /// [ThemeData.bottomSheetTheme] is used. If that is also null, the default value
  /// is transparent.
  ///
  /// See also:
  ///
  ///  * [elevation], which defines the size of the shadow below the sheet.
  ///  * [shape], which defines the shape of the sheet and its shadow.
  final Color? shadowColor;

  /// The shape of the bottom sheet.
  ///
  /// Defines the bottom sheet's [Material.shape].
  ///
  /// Defaults to null and falls back to [Material]'s default.
  final ShapeBorder? shape;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defines the bottom sheet's [Material.clipBehavior].
  ///
  /// Use this property to enable clipping of content when the bottom sheet has
  /// a custom [shape] and the content can extend past this shape. For example,
  /// a bottom sheet with rounded corners and an edge-to-edge [Image] at the
  /// top.
  ///
  /// If this property is null then [BottomSheetThemeData.clipBehavior] of
  /// [ThemeData.bottomSheetTheme] is used. If that's null then the behavior
  /// will be [Clip.none].
  final Clip? clipBehavior;

  /// Defines minimum and maximum sizes for a [BottomSheet].
  ///
  /// If null, then the ambient [ThemeData.bottomSheetTheme]'s
  /// [BottomSheetThemeData.constraints] will be used. If that
  /// is null and [ThemeData.useMaterial3] is true, then the bottom sheet
  /// will have a max width of 640dp. If [ThemeData.useMaterial3] is false, then
  /// the bottom sheet's size will be constrained by its parent
  /// (usually a [Scaffold]). In this case, consider limiting the width by
  /// setting smaller constraints for large screens.
  ///
  /// If constraints are specified (either in this property or in the
  /// theme), the bottom sheet will be aligned to the bottom-center of
  /// the available space. Otherwise, no alignment is applied.
  final BoxConstraints? constraints;

  @override
  RightSheetState createState() => RightSheetState();

  /// Creates an animation controller suitable for controlling a [RightSheet].
  static AnimationController createAnimationController(TickerProvider vsync) {
    return AnimationController(
      duration: _kRightSheetDuration,
      debugLabel: 'RightSheet',
      vsync: vsync,
    );
  }
}

class RightSheetState extends State<RightSheet> {
  final GlobalKey _childKey = GlobalKey(debugLabel: 'RightSheet child');

  double get _childWidth {
    final RenderBox renderBox =
        _childKey.currentContext!.findRenderObject()! as RenderBox;
    return renderBox.size.width;
  }

  bool get _dismissUnderway =>
      widget.animationController?.status == AnimationStatus.reverse;

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_dismissUnderway) return;
    widget.animationController?.value -= details.primaryDelta! / (_childWidth);
  }

  void _handleDragEnd(DragEndDetails details) {
    // CoreLog.d("${widget.animationController!.value} ${_childWidth} ${_kMinFlingVelocity} ${details.primaryVelocity} ${details.globalPosition}");
    // CoreLog.d("${details.globalPosition.dx} ${details.localPosition.dx} ${details.velocity.pixelsPerSecond.dx}");
    // CoreLog.d("${details.globalPosition.dy} ${details.localPosition.dy} ${details.velocity.pixelsPerSecond.dy}");
    // CoreLog.d("_dismissUnderway ${_dismissUnderway} ${_kMinFlingVelocity}");
    if (_dismissUnderway) return;
    if (details.velocity.pixelsPerSecond.dx > _kMinFlingVelocity) {
      final double flingVelocity =
          -details.velocity.pixelsPerSecond.dx / _childWidth;
      if (widget.animationController!.value > 0.0) {
        widget.animationController!.fling(velocity: flingVelocity);
      }
      // CoreLog.d("flingVelocity ${flingVelocity}");

      if (flingVelocity < 0.0) widget.onClosing();
    } else if (widget.animationController!.value < _kCloseProgressThreshold) {
      if (widget.animationController!.value > 0.0) {
        widget.animationController!.fling(velocity: -1.0);
      }
      widget.onClosing();
    } else {
      widget.animationController!.forward();
    }
    // CoreLog.d("${widget.animationController!.value} ${_childWidth} ${details.primaryVelocity} ${details.globalPosition} ${details.localPosition} ${details}");
  }

  @override
  Widget build(BuildContext context) {
    final BottomSheetThemeData bottomSheetTheme =
        Theme.of(context).bottomSheetTheme;
    // final bool useMaterial3 = Theme.of(context).useMaterial3;
    final BottomSheetThemeData defaults = const BottomSheetThemeData();
    final BoxConstraints? constraints = widget.constraints ??
        bottomSheetTheme.constraints ??
        defaults.constraints;
    final Color? color = widget.backgroundColor ??
        bottomSheetTheme.backgroundColor ??
        defaults.backgroundColor;
    // final Color? surfaceTintColor =
    //     bottomSheetTheme.surfaceTintColor ?? defaults.surfaceTintColor;
    // final Color? shadowColor = widget.shadowColor ??
    //     bottomSheetTheme.shadowColor ??
    //     defaults.shadowColor;
    // final double elevation = widget.elevation ??
    //     bottomSheetTheme.elevation ??
    //     defaults.elevation ??
    //     0;
    final ShapeBorder? shape =
        widget.shape ?? bottomSheetTheme.shape ?? defaults.shape;
    final Clip clipBehavior =
        widget.clipBehavior ?? bottomSheetTheme.clipBehavior ?? Clip.none;
    // final bool showDragHandle = widget.showDragHandle ??
    //     (widget.enableDrag && (bottomSheetTheme.showDragHandle ?? false));

    Widget sheet = Material(
      key: _childKey,
      elevation: widget.elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      color: color,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: widget.builder(context),
      ),
    );

    if (constraints != null) {
      sheet = Align(
        alignment: Alignment.topRight,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: constraints,
          child: sheet,
        ),
      );
    }

    return !widget.enableDrag
        ? sheet
        : GestureDetector(
            onHorizontalDragUpdate: _handleDragUpdate,
            onHorizontalDragEnd: _handleDragEnd,
            excludeFromSemantics: true,
            child: sheet,
          );
  }
}
