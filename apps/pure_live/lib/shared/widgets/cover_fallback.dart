import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// The stand-in a cover shows while its picture is missing or did not load:
/// the title over the control fill, bottom-aligned, so the card keeps its
/// shape and still says what it is.
final class CoverFallback extends StatelessWidget {
  /// The fallback naming [title].
  const CoverFallback({required this.title, this.padding = const EdgeInsets.all(10), super.key});

  /// The room, video or file the cover belongs to.
  final String title;

  /// Space between the cover's edge and the title.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    return ColoredBox(
      color: colors.control,
      child: Padding(
        padding: padding,
        child: Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(color: colors.textMuted),
          ),
        ),
      ),
    );
  }
}
