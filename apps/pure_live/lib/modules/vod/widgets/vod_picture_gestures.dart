import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/widgets.dart';

/// Which side of the picture a double tap landed on.
///
/// The side is the answer, not the coordinate: a video is stepped backwards
/// from where its start was and forwards from where its end is, and a viewer
/// who taps the left edge expects that edge to go backwards without being the
/// one who decided so.
enum VodTapSide { left, middle, right }

/// The pointer's vocabulary over a video picture.
///
/// A video is watched with these gestures and no other: a tap raises or puts
/// away the chrome, a double tap on either side steps the part and on the
/// middle plays or pauses, a drag along the picture scrubs it, a drag down it
/// takes the sound (or the screen's brightness on the half that owns it), a
/// hold runs it faster until the finger lifts, and a wheel steps the sound.
/// The widget knows nothing about what those mean: it measures the picture and
/// reports where and how far the pointer went, and the page decides whether a
/// drag is a seek of four seconds or forty. That is why the archive and the
/// cinema answer the same gestures with the same hands rather than each
/// inventing a shape for the same finger.
///
/// A callback left out leaves that gesture unanswered rather than half-acting:
/// a picture with no sound to set should swallow a vertical drag, not pretend.
final class VodPictureGestures extends StatefulWidget {
  /// Wraps [child]. [enabled] is false for a part that has not opened yet —
  /// there is no timeline to move.
  const VodPictureGestures({
    required this.child,
    this.enabled = true,
    this.onTap,
    this.onDoubleTap,
    this.onScrub,
    this.onScrubEnd,
    this.onAdjustStart,
    this.onAdjust,
    this.onHold,
    this.onWheel,
    super.key,
  });

  /// The picture, and whatever floats under it.
  final Widget child;

  /// Whether the surface answers at all.
  final bool enabled;

  /// A single press: the chrome's own switch.
  final VoidCallback? onTap;

  /// The second press of a double tap, with the side it landed on.
  final ValueChanged<VodTapSide>? onDoubleTap;

  /// A frame of a horizontal drag: the pixels it moved and the width the
  /// picture is being drawn at.
  final void Function(double delta, double width)? onScrub;

  /// The horizontal drag let go; the flag says whether it ended where it was
  /// heading or was taken away by something else, which is the difference
  /// between seeking to the frame under the finger and leaving the picture be.
  final ValueChanged<bool>? onScrubEnd;

  /// The start of a vertical drag, with the pointer's place across the picture
  /// as a fraction — which half owns the sound and which the brightness is the
  /// page's business, not the pointer's.
  final ValueChanged<double>? onAdjustStart;

  /// A frame of that vertical drag, in pixels down the picture.
  final ValueChanged<double>? onAdjust;

  /// A hold: true while the finger stays down past the hold's own patience,
  /// false when it lifts or turns out to have been something else.
  final ValueChanged<bool>? onHold;

  /// A wheel step over the picture, in the direction the system reports it.
  final ValueChanged<double>? onWheel;

  @override
  State<VodPictureGestures> createState() => _VodPictureGesturesState();
}

final class _VodPictureGesturesState extends State<VodPictureGestures> {
  /// Where the first press of a pair landed. The pair's answer comes two
  /// callbacks later, and the picture's own width is not known at the first.
  double? _firstPressX;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        VodTapSide sideOf(double x) {
          if (width <= 0) return VodTapSide.middle;
          if (x < width / 3) return VodTapSide.left;
          if (x > width - width / 3) return VodTapSide.right;
          return VodTapSide.middle;
        }

        final answers = widget.enabled;
        return Listener(
          onPointerSignal: !answers || widget.onWheel == null
              ? null
              : (signal) {
                  if (signal is PointerScrollEvent) widget.onWheel!(signal.scrollDelta.dy);
                },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: answers ? widget.onTap : null,
            onDoubleTapDown: !answers || widget.onDoubleTap == null
                ? null
                : (tap) => _firstPressX = tap.localPosition.dx,
            onDoubleTap: !answers || widget.onDoubleTap == null
                ? null
                : () {
                    final x = _firstPressX;
                    _firstPressX = null;
                    widget.onDoubleTap!(sideOf(x ?? width / 2));
                  },
            onHorizontalDragUpdate: !answers || widget.onScrub == null
                ? null
                : (move) => widget.onScrub!(move.delta.dx, width),
            onHorizontalDragEnd: !answers || widget.onScrubEnd == null ? null : (_) => widget.onScrubEnd!(true),
            onHorizontalDragCancel: !answers || widget.onScrubEnd == null ? null : () => widget.onScrubEnd!(false),
            onVerticalDragStart: !answers || widget.onAdjustStart == null
                ? null
                : (start) => widget.onAdjustStart!(width <= 0 ? 0.5 : start.localPosition.dx / width),
            onVerticalDragUpdate: !answers || widget.onAdjust == null
                ? null
                : (move) => widget.onAdjust!(move.delta.dy),
            onLongPressStart: !answers || widget.onHold == null ? null : (_) => widget.onHold!(true),
            onLongPressEnd: !answers || widget.onHold == null ? null : (_) => widget.onHold!(false),
            onLongPressCancel: !answers || widget.onHold == null ? null : () => widget.onHold!(false),
          ),
        );
      },
    );
  }
}
