import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// One collapsible chapter of a documentation page: the icon and the
/// chapter's name on the row, the chapter's content below it while it is
/// open — the reading shape the guide and the help pages share, so a long
/// reference folds into chapters a reader opens one at a time instead of
/// one flat scroll.
///
/// The open content is inset to the chapter's own measure; the children are
/// bare of horizontal padding of their own.
final class GuideChapter extends StatefulWidget {
  /// The chapter named [title], its [children] below the row while open.
  const GuideChapter({
    required this.icon,
    required this.title,
    required this.children,
    this.initiallyOpen = false,
    super.key,
  });

  /// The chapter's glyph.
  final DsIconData icon;

  /// What the chapter is called.
  final String title;

  /// The chapter's content, one block per line of the open column.
  final List<Widget> children;

  /// Whether the chapter starts open — the page's first reading step.
  final bool initiallyOpen;

  @override
  State<GuideChapter> createState() => _GuideChapterState();
}

final class _GuideChapterState extends State<GuideChapter> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DsListSection(
      children: [
        DsListRow(
          leading: DsIcon(widget.icon),
          title: Text(widget.title, style: theme.typography.bodyStrong),
          trailing: DsIcon(_open ? DsIcons.chevronUp : DsIcons.chevronDown, size: 16),
          onPressed: () => setState(() => _open = !_open),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s12,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}
