import 'package:flutter/material.dart';

const double searchPlatformStripHeight = 48;
const ScrollPhysics searchPlatformStripPhysics = ClampingScrollPhysics();

/// A bounded, independently controlled platform selector for the search page.
///
/// Flutter's scrollable [TabBar] owns a private scroll position and can move
/// the whole strip while it is also animating the selected tab. Search does not
/// have a matching TabBarView, so a small horizontal list is both simpler and
/// prevents the platform row from drifting beyond its first/last item.
class SearchPlatformStrip extends StatefulWidget {
  const SearchPlatformStrip({super.key, required this.labels, required this.selectedIndex, required this.onSelected});

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<SearchPlatformStrip> createState() => _SearchPlatformStripState();
}

class _SearchPlatformStripState extends State<SearchPlatformStrip> {
  late final ScrollController _scrollController;
  List<GlobalKey> _itemKeys = const [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(keepScrollOffset: false);
    _syncKeys();
  }

  @override
  void didUpdateWidget(covariant SearchPlatformStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labels.length != widget.labels.length) {
      _syncKeys();
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _revealSelectedAfterLayout();
    }
  }

  void _syncKeys() {
    _itemKeys = List<GlobalKey>.generate(widget.labels.length, (_) => GlobalKey());
  }

  void _revealSelectedAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.selectedIndex < 0 || widget.selectedIndex >= _itemKeys.length) return;
      final itemContext = _itemKeys[widget.selectedIndex].currentContext;
      if (itemContext == null) return;
      Scrollable.ensureVisible(
        itemContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: searchPlatformStripHeight,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false, scrollbars: false),
        child: ListView.separated(
          key: const ValueKey('search-platform-strip'),
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: searchPlatformStripPhysics,
          clipBehavior: Clip.hardEdge,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          itemCount: widget.labels.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, itemIndex) {
            final selected = itemIndex == widget.selectedIndex;
            return Center(
              key: _itemKeys[itemIndex],
              child: ChoiceChip(
                key: ValueKey('search-platform-$itemIndex'),
                label: Text(widget.labels[itemIndex]),
                selected: selected,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
                onSelected: (_) => widget.onSelected(itemIndex),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
