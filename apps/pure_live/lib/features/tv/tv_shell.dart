import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/tv/tv_pages.dart' show TvPopularPage;
import 'package:pure_live/l10n/translations.dart';

/// The TV shell: a left rail of large destinations the remote walks down,
/// the chosen destination's page beside it, kept alive under an
/// [IndexedStack] so a page's scroll and focus survive the round trip.
///
/// The pages are the browsing controllers the phone and desktop shells
/// already use; only their surfaces are TV shapes (see [TvPopularPage]).
final class TvShell extends ConsumerStatefulWidget {
  /// The TV shell.
  const TvShell({super.key});

  @override
  ConsumerState<TvShell> createState() => _TvShellState();
}

/// The rail's destinations, top to bottom.
enum _TvSection { popular, areas, search, follows, settings }

final class _TvShellState extends ConsumerState<TvShell> {
  _TvSection _section = _TvSection.popular;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final t = context.t;
    return ColoredBox(
      color: colors.sidebar,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The rail: one large block per destination; the focused one
          // lifts and rings itself like the cards do.
          SizedBox(
            width: 180,
            child: ColoredBox(
              color: colors.sidebar,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s24, DsSpace.s20, DsSpace.s16),
                    child: Text(
                      t.common.appTitle,
                      style: theme.typography.display.copyWith(fontSize: 24, color: colors.text),
                    ),
                  ),
                  for (final (index, section) in _TvSection.values.indexed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s4),
                      child: _RailItem(
                        section: section,
                        selected: section == _section,
                        autofocus: index == 0,
                        onSelected: (value) => setState(() => _section = value),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            // Kept alive: each destination keeps its scroll and its focus.
            child: IndexedStack(
              index: _TvSection.values.indexOf(_section),
              children: const [
                TvPopularPage(),
                _TvComingPage(),
                _TvComingPage(),
                _TvComingPage(),
                _TvComingPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One rail destination: a large labelled block, focusable by the remote.
final class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.section,
    required this.selected,
    required this.autofocus,
    required this.onSelected,
  });

  final _TvSection section;
  final bool selected;
  final bool autofocus;
  final ValueChanged<_TvSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final t = context.t;
    final label = switch (section) {
      _TvSection.popular => t.navigation.hot,
      _TvSection.areas => t.navigation.zones,
      _TvSection.search => t.navigation.search,
      _TvSection.follows => t.navigation.favorites,
      _TvSection.settings => t.navigation.settings,
    };
    return DsPressable(
      autofocus: autofocus,
      semanticLabel: label,
      onPressed: () => onSelected(section),
      builder: (context, states, _) {
        final focused = states.contains(WidgetState.focused);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s16, vertical: DsSpace.s12),
          decoration: DsBoxDecoration(
            color: selected ? theme.selectedFill : focused ? colors.hover : null,
            borderRadius: BorderRadius.circular(theme.radii.control(56)),
          ),
          foregroundDecoration: focused
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(theme.radii.control(56)),
                  border: Border.all(color: theme.selectedFill, width: 2.5),
                )
              : null,
          child: Text(
            label,
            style: theme.typography.body.copyWith(
              fontSize: 20,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? theme.onSelectedFill : colors.text,
            ),
          ),
        );
      },
    );
  }
}

/// A destination whose TV page is not built yet: honest about the wait,
/// with the phone and desktop surfaces still one dart-define away.
final class _TvComingPage extends ConsumerWidget {
  const _TvComingPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return Center(child: DsEmptyState(icon: const DsIcon(DsIcons.tv), title: Text(t.common.comingSoon)));
  }
}
