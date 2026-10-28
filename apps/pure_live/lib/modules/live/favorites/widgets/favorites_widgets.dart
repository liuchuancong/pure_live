import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/l10n/translations.dart';

/// The follows' bottom pager: a refresh and the kit's pagination — the page
/// numbers with their arrows, nothing else.
///
/// The workspace has no shared pager, so the favorites page carries this
/// one; it pages the already-loaded follows locally.
final class FavoritesPager extends StatefulWidget {
  /// Creates the pager over [pageCount] pages.
  const FavoritesPager({
    required this.page,
    required this.pageCount,
    required this.busy,
    required this.onPage,
    required this.onRefresh,
    super.key,
  });

  /// The page shown, from 1.
  final int page;

  /// How many pages the follows fill.
  final int pageCount;

  /// A refresh is running: the buttons are inert.
  final bool busy;

  /// Shows another page.
  final ValueChanged<int> onPage;

  /// Refreshes the visible slice.
  final VoidCallback onRefresh;

  @override
  State<FavoritesPager> createState() => _FavoritesPagerState();
}

final class _FavoritesPagerState extends State<FavoritesPager> {
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final busy = widget.busy;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s8,
      children: [
        DsButton(
          variant: DsButtonVariant.secondary,
          size: DsSize.sm,
          leading: busy
              ? const SizedBox(width: 12, height: 12, child: DsSpinner())
              : const DsIcon(DsIcons.refreshCw, size: 14),
          onPressed: busy ? null : widget.onRefresh,
          child: Text(t.favorites.refresh),
        ),
        DsPagination(
          page: widget.page,
          pageCount: widget.pageCount,
          onChanged: busy ? null : widget.onPage,
          previousLabel: t.popular.prevPage,
          nextLabel: t.popular.nextPage,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s20, vertical: DsSpace.s8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth - DsSpace.s20 * 2),
            child: Align(alignment: AlignmentDirectional.center, child: row),
          ),
        ),
      ),
    );
  }
}
