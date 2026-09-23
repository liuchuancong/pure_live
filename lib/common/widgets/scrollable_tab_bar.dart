import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
  ScrollPosition? _position;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: widget.enableMouseWheel ? _handlePointerSignal : null,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
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
      ),
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.horizontal) {
      final scrollable = notification.context != null ? Scrollable.maybeOf(notification.context!) : null;

      if (scrollable != null) {
        _position = scrollable.position;
      }
    }

    return false;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    final position = _position;

    if (position == null || !position.hasContentDimensions) {
      return;
    }

    double delta = event.scrollDelta.dx;

    if (delta.abs() < 0.01) {
      delta = event.scrollDelta.dy;
    }

    if (delta.abs() < 0.01) {
      return;
    }

    final target = (position.pixels + delta * widget.mouseWheelScrollFactor).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if ((target - position.pixels).abs() < 0.01) {
      return;
    }

    position.animateTo(target.toDouble(), duration: widget.mouseWheelDuration, curve: widget.mouseWheelCurve);
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
