import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/shell/shell_controller.dart' show ShellController;
import 'package:pure_live/i18n/translations.g.dart';

/// The search field that lives in the title bar.
///
/// It reads as a field and acts as a button: activating it opens the search
/// branch, where the working input and the results live. The desktop's
/// global-search convention without a second focus target in the strip.
final class TitleBarSearch extends ConsumerWidget {
  /// The title-bar search.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DsPressable(
        semanticLabel: t.search.hint,
        onPressed: () => ShellController(ref: ref, context: context).openSearch(),
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Container(
            height: 28,
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: hovered ? colors.press : colors.hover,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                DsIcon(DsIcons.search, size: 14, color: colors.textMuted),
                const SizedBox(width: 6),
                Text(
                  t.search.hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
