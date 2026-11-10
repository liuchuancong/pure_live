import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// The app's one in-place page head: the 44px line a module page opens
/// with — the title, a muted description beside it, and the page's verbs at
/// the end. The live module's screens draw this row in their own file; this
/// is the shared contract for every module that wants the same line without
/// importing another module's views.
///
/// A page applies its own inset padding around it and draws its own control
/// lines under it; the row never folds the verbs — the title and description
/// give way first, so the verbs stay visible to the width the page already
/// supports — and a page whose verbs ride the shell's head instead passes
/// none.
final class ModulePageHead extends StatelessWidget {
  const ModulePageHead({required this.title, this.description, this.actions = const <Widget>[], super.key});

  /// The page's name, in the head's strong label.
  final String title;

  /// The muted facts beside the name — the counts, a refresh's stamp. Null
  /// leaves the title alone on the line.
  final String? description;

  /// The page's verbs, laid out at the row's end.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return SizedBox(
      height: 44,
      child: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: title,
                    style: theme.typography.labelStrong.copyWith(color: colors.text),
                  ),
                  if (description != null) ...[
                    TextSpan(
                      text: '  ·  ',
                      style: theme.typography.small.copyWith(color: colors.textSubtle),
                    ),
                    TextSpan(
                      text: description,
                      style: theme.typography.small.copyWith(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
