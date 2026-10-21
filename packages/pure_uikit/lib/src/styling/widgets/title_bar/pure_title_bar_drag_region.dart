import 'package:flutter/material.dart';

/// Provides a draggable title region with a title and double-click behavior.
///
/// This widget handles title dragging and double-clicking independently
/// of the platform-specific window management implementation.
class PureTitleBarDragRegion extends StatelessWidget {
  /// Creates a draggable title region.
  const new({
    required this.title,
    required this.startDragging,
    required this.titleStyle,
    required this.onDoubleTap,
    this.alignment = Alignment.center,
    this.padding = EdgeInsets.zero,
    this.expand = true,
    this.leading,
    super.key,
  });

  /// The title displayed inside the draggable region.
  final String title;

  /// The mark drawn before the title — the app's own brand. It sits inside
  /// the drag region, so a drag begun on it still moves the window.
  final Widget? leading;

  /// Starts dragging the current window.
  final Future<void> Function() startDragging;

  /// The text style applied to the title.
  final TextStyle? titleStyle;

  /// Toggles the window between maximized and restored states.
  final VoidCallback onDoubleTap;

  /// The alignment of the title within the available space.
  final AlignmentGeometry alignment;

  /// Padding around the title.
  final EdgeInsetsGeometry padding;

  /// Whether the drag region expands to fill the available space.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle);

    final content = Padding(
      padding: padding,
      child: Align(
        alignment: alignment,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?leading,
            Flexible(child: titleWidget),
          ],
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) async {
        await startDragging();
      },
      onDoubleTap: onDoubleTap,
      child: expand ? SizedBox.expand(child: content) : content,
    );
  }
}
