import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/utils/fluent_tokens.dart';

/// Tells the items of a Windows pane whether it is the compact icon rail.
/// Internal.
class FluentPaneModeScope extends InheritedWidget {
  const FluentPaneModeScope({
    super.key,
    required this.compact,
    required super.child,
  });

  final bool compact;

  static bool compactOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FluentPaneModeScope>()
          ?.compact ??
      false;

  @override
  bool updateShouldNotify(FluentPaneModeScope oldWidget) =>
      compact != oldWidget.compact;
}

/// The two panes of a Windows style split view between 641 and 1007 wide:
/// the compact icon rail next to the content, which opens over the content
/// (the NavigationView "LeftCompact" mode). Internal.
///
/// While open, the pane is [openWidth] wide on the acrylic fallback color
/// with a shadow and rounded end corners; a click outside it or Escape
/// closes it ([onDismiss]).
class FluentCompactPaneLayout extends StatefulWidget {
  const FluentCompactPaneLayout({
    super.key,
    required this.open,
    required this.railWidth,
    required this.openWidth,
    required this.onDismiss,
    required this.pane,
    required this.detail,
  });

  final bool open;
  final double railWidth;
  final double openWidth;
  final VoidCallback onDismiss;
  final Widget pane;
  final Widget detail;

  @override
  State<FluentCompactPaneLayout> createState() =>
      _FluentCompactPaneLayoutState();
}

class _FluentCompactPaneLayoutState extends State<FluentCompactPaneLayout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: widget.open ? 1 : 0,
  )..addStatusListener((_) => setState(() {}));

  @override
  void didUpdateWidget(FluentCompactPaneLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      final reduceMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduceMotion) {
        _controller.value = widget.open ? 1 : 0;
      } else if (widget.open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = fluentTokensOf(context);
    final closed = _controller.status == AnimationStatus.dismissed;
    final openWidth = math.max(widget.railWidth, widget.openWidth);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final endCorner = BorderRadiusDirectional.horizontal(
      end: const Radius.circular(8),
    ).resolve(Directionality.of(context));

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (widget.open) widget.onDismiss();
        },
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              children: [
                SizedBox(width: widget.railWidth),
                Expanded(child: widget.detail),
              ],
            ),
          ),
          // A click outside the open pane closes it (light dismiss).
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !widget.open,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: widget.onDismiss,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = kFluentFastOutSlowIn.transform(_controller.value);
                final width =
                    widget.railWidth + (openWidth - widget.railWidth) * t;
                return Container(
                  width: width,
                  clipBehavior: closed ? Clip.none : Clip.antiAlias,
                  decoration: closed
                      ? null
                      : BoxDecoration(
                          color: tokens.overlayPane,
                          borderRadius: endCorner,
                          border: BorderDirectional(
                            end: BorderSide(color: tokens.overlayStroke),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(0, 0, 0, 0.14 * t),
                              blurRadius: 16,
                              offset: Offset(isRtl ? -2 : 2, 0),
                            ),
                          ],
                        ),
                  child: child,
                );
              },
              child: FluentPaneModeScope(
                compact: closed,
                child: OverflowBox(
                  alignment: AlignmentDirectional.topStart,
                  minWidth: closed ? widget.railWidth : openWidth,
                  maxWidth: closed ? widget.railWidth : openWidth,
                  child: widget.pane,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
