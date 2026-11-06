import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/l10n/translations.dart';

import 'package:pure_live/shared/widgets/chrome_icon_button.dart';

/// A pushed page's own head on a touch shell: the back verb on the start
/// side, the page's name beside it, the page's actions on the end — the pane
/// header's one-row shape, so a page opened over the shell reads like the
/// narrow shell's own head line (back and a one-line title). The shell keeps
/// drawing the heads of its branch pages; a page pushed as its own route
/// wears this one.
///
/// The top safe area is the header's own business: a page hosts it as the
/// first row of its body and keeps its scaffold bare of an app bar.
final class PageHeader extends StatelessWidget {
  /// The header for a page titled [title], its [actions] on the end side.
  const PageHeader({required this.title, this.actions = const [], super.key});

  /// What the page is called; one line, ellipsized.
  final String title;

  /// The page's own verbs, in the order they stand at the header's end.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return SafeArea(
      bottom: false,
      child: DsPaneHeader(
        title: Row(
          children: [
            ChromeIconButton(
              icon: DsIcons.arrowLeft,
              semanticLabel: t.common.back,
              tooltip: t.common.back,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: DsSpace.s8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: colors.text),
              ),
            ),
          ],
        ),
        actions: actions,
      ),
    );
  }
}
