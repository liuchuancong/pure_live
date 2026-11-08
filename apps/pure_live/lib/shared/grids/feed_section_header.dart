import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// A feed section's identity row: the section's name leading, a quiet caption
/// beside it (a count, say) and the page's own verb at the end. Lighter than
/// the pane chrome — no divider and no height of its own — so the scrolling
/// grid below reads as one section under its name rather than under another
/// bar. The caller gives it the page's horizontal inset.
final class FeedSectionHeader extends StatelessWidget {
  /// Names the section [title]; [caption] rides beside it and [trailing]
  /// closes the row.
  const FeedSectionHeader({required this.title, this.caption, this.trailing, super.key});

  /// What the section is called; one line.
  final String title;

  /// A quiet line beside the name — the number of rooms, say. Null leaves
  /// the name alone with the trailing verb at the row's end.
  final String? caption;

  /// The page's verb at the row's end.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = theme.colors;
    return Semantics(
      header: true,
      child: Row(
        spacing: DsSpace.s8,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.heading.copyWith(color: colors.text),
          ),
          // The caption takes the room the name does not need, so the count
          // ellipsizes before the name ever does; without one the spacer
          // still carries the trailing verb to the row's end.
          if (caption != null)
            Expanded(
              child: Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            )
          else
            const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
