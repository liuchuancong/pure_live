import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/enums/navigation_item.dart';

/// The word a page's toolbar search handed to the list on screen: the page
/// filters its own loaded content by it, the live module's list pages'
/// way. One slot per page, keyed by the page's navigation item.
final NotifierProviderFamily<InlineFilterController, String?, NavigationItem> inlineFilterProvider =
    NotifierProvider.family<InlineFilterController, String?, NavigationItem>(InlineFilterController.new);

final class InlineFilterController extends Notifier<String?> {
  InlineFilterController(this.page);

  /// The page whose list this slot filters.
  final NavigationItem page;

  @override
  String? build() => null;

  /// Filters by [word] (null or empty returns to the whole list).
  void search(String? word) => state = (word == null || word.trim().isEmpty) ? null : word.trim();

  /// Returns to the whole list.
  void clear() => state = null;
}

/// Whether [word] (the inline filter's) keeps an item whose [haystack] is
/// the item's searchable fields: a substring test that forgives case, so
/// 'ABC' finds 'abc'. A null or empty word keeps everything.
bool inlineFilterKeeps(String? word, Iterable<String> haystack) {
  if (word == null || word.isEmpty) return true;
  final needle = word.toLowerCase();
  return haystack.any((field) => field.toLowerCase().contains(needle));
}

/// The one-line bar a filtered page shows above its list: the word the
/// toolbar's search handed over, and the way back to the whole list. The
/// list under it answers the word; clearing it returns the page to browsing.
final class InlineFilterBar extends StatelessWidget {
  /// Draws the bar for [word].
  const InlineFilterBar({required this.word, required this.onClear, super.key});

  /// The word the page is filtered by.
  final String word;

  /// Returns the page to its whole list.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s16, 0, DsSpace.s16, DsSpace.s8),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          Expanded(
            child: Text(
              t.common.inlineFilterShowing(word: word),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DsTheme.of(context).typography.caption.copyWith(color: colors.textMuted),
            ),
          ),
          DsButton.icon(
            variant: DsButtonVariant.ghost,
            size: DsSize.sm,
            semanticLabel: t.common.cancel,
            onPressed: onClear,
            icon: const DsIcon(DsIcons.x, size: 14),
          ),
        ],
      ),
    );
  }
}
