import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A [TabBar] that desktop users can also scroll with the mouse wheel and by
/// dragging with the mouse (from liuchuancong/pure_live). Touch behaviour and
/// the given scroll physics are unchanged.
class ScrollableTabBar extends StatefulWidget {
  final List<Widget> tabs;
  final TabController? controller;

  final bool isScrollable;
  final EdgeInsetsGeometry? padding;

  final Color? indicatorColor;
  final Color? dividerColor;
  final double indicatorWeight;
  final TabBarIndicatorSize? indicatorSize;
  final Decoration? indicator;
  final EdgeInsetsGeometry indicatorPadding;

  final Color? labelColor;
  final Color? unselectedLabelColor;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final EdgeInsetsGeometry labelPadding;

  final double? dividerHeight;
  final TabAlignment? tabAlignment;
  final ScrollPhysics? physics;

  final void Function(int)? onTap;
  final TabValueChanged<bool>? onHover;
  final TabValueChanged<bool>? onFocusChange;

  final WidgetStateProperty<Color?>? overlayColor;
  final MouseCursor? mouseCursor;

  final DragStartBehavior dragStartBehavior;
  final bool enableFeedback;

  final BorderRadius? splashBorderRadius;
  final InteractiveInkFeatureFactory? splashFactory;

  final bool enableMouseWheel;
  final double mouseWheelScrollFactor;
  final Duration mouseWheelDuration;
  final Curve mouseWheelCurve;

  const ScrollableTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.isScrollable = false,
    this.padding,
    this.indicatorColor,
    this.dividerColor,
    this.indicatorWeight = 2.0,
    this.indicatorSize,
    this.indicator,
    this.indicatorPadding = EdgeInsets.zero,
    this.labelColor,
    this.unselectedLabelColor,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.labelPadding = const EdgeInsets.symmetric(horizontal: 16.0),
    this.dividerHeight,
    this.tabAlignment,
    this.physics,
    this.onTap,
    this.onHover,
    this.onFocusChange,
    this.overlayColor,
    this.mouseCursor,
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableFeedback = true,
    this.splashBorderRadius,
    this.splashFactory,
    this.enableMouseWheel = true,
    this.mouseWheelScrollFactor = 1.0,
    this.mouseWheelDuration = const Duration(milliseconds: 100),
    this.mouseWheelCurve = Curves.easeOut,
  });

  @override
  State<ScrollableTabBar> createState() => _ScrollableTabBarState();
}

class _ScrollableTabBarState extends State<ScrollableTabBar> {
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: widget.enableMouseWheel ? _handlePointerSignal : null,
      child: ScrollConfiguration(
        behavior: const _CrossPlatformTabBarScrollBehavior(),
        child: TabBar(
          controller: widget.controller,
          tabs: widget.tabs,
          isScrollable: widget.isScrollable,
          padding: widget.padding,
          indicatorColor: widget.indicatorColor,
          dividerColor: widget.dividerColor,
          indicatorWeight: widget.indicatorWeight,
          indicatorSize: widget.indicatorSize,
          indicator: widget.indicator,
          indicatorPadding: widget.indicatorPadding,
          labelColor: widget.labelColor,
          unselectedLabelColor: widget.unselectedLabelColor,
          labelStyle: widget.labelStyle,
          unselectedLabelStyle: widget.unselectedLabelStyle,
          labelPadding: widget.labelPadding,
          dividerHeight: widget.dividerHeight,
          tabAlignment: widget.tabAlignment,
          physics: widget.physics,
          onTap: widget.onTap,
          onHover: widget.onHover,
          onFocusChange: widget.onFocusChange,
          overlayColor: widget.overlayColor,
          mouseCursor: widget.mouseCursor,
          dragStartBehavior: widget.dragStartBehavior,
          enableFeedback: widget.enableFeedback,
          splashBorderRadius: widget.splashBorderRadius,
          splashFactory: widget.splashFactory,
        ),
      ),
    );
  }

  /// The tab strip's own horizontal scroll position, looked up on demand so
  /// the very first wheel turn works (upstream waited for a scroll notification).
  ScrollPosition? _tabPosition() {
    ScrollPosition? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        if (position.axis == Axis.horizontal) {
          found = position;
          return;
        }
      }
      element.visitChildren(visit);
    }

    if (mounted) (context as Element).visitChildren(visit);
    return found;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final position = _tabPosition();
    if (position == null || !position.hasContentDimensions || position.maxScrollExtent <= 0) return;
    var delta = event.scrollDelta.dx;
    if (delta.abs() < 0.01) delta = event.scrollDelta.dy;
    if (delta.abs() < 0.01) return;
    // Claim the event so the page behind the tabs does not scroll as well.
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final target = (position.pixels + delta * widget.mouseWheelScrollFactor).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((target - position.pixels).abs() < 0.01) return;
      position.animateTo(target.toDouble(), duration: widget.mouseWheelDuration, curve: widget.mouseWheelCurve);
    });
  }
}

class _CrossPlatformTabBarScrollBehavior extends MaterialScrollBehavior {
  const _CrossPlatformTabBarScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}
