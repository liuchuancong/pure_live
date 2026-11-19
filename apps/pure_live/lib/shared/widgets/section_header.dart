import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// A detail page's section header: the section's name in one voice, its
/// count in a quieter one, and the section's own actions at the far end.
///
/// Every detail page (the stations' video, season, episode and uploader
/// pages) speaks through this one row, so a screen never carries two
/// competing section-header styles.
final class SectionHeader extends StatelessWidget {
  /// Creates the header.
  const SectionHeader({required this.title, this.count, this.hint, this.trailing = const [], this.leading, super.key});

  /// The section's name (`分P`, `评论`, `相关推荐`).
  final String title;

  /// A small mark before the name, when the section carries one (the live
  /// shelf's station square).
  final Widget? leading;

  /// The section's size, said beside the name in the quieter voice.
  final int? count;

  /// A short muted note after the count (a range like `1–20 / 127`).
  final String? hint;

  /// The section's own actions (a shuffle button, a jump field), aligned to
  /// the row's far end.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final typography = DsTheme.of(context).typography;
    return Row(
      spacing: DsSpace.s8,
      children: [
        ?leading,
        Text(title, style: typography.heading.copyWith(color: colors.text)),
        if (count != null)
          Text(count!.toString(), style: typography.numeric(typography.caption).copyWith(color: colors.textMuted)),
        if (hint case final hint?)
          Flexible(
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.caption.copyWith(color: colors.textMuted),
            ),
          ),
        const Spacer(),
        ...trailing,
      ],
    );
  }
}
