import 'package:flutter/material.dart';
import 'package:pure_live/common/widgets/pure_live_scroll_physics.dart';

/// A fixed, adaptive status selector.
///
/// Recorder state is selected explicitly instead of being nested in two
/// horizontal scrollables (a scrollable [TabBar] and a swipable [TabBarView]).
/// This keeps every status within the viewport and removes the impression that
/// the selector can be dragged beyond either edge.
class RecorderStatusSelector extends StatelessWidget {
  const RecorderStatusSelector({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? labels.length
            : constraints.maxWidth >= 600
            ? 5
            : 3;
        final rows = <Widget>[];
        for (var start = 0; start < labels.length; start += columns) {
          final children = <Widget>[];
          for (var column = 0; column < columns; column++) {
            final index = start + column;
            if (index >= labels.length) {
              children.add(const Expanded(child: SizedBox.shrink()));
              continue;
            }
            children.add(
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      final selected = controller.index == index;
                      return Material(
                        color: selected
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.46),
                        borderRadius: BorderRadius.circular(11),
                        clipBehavior: Clip.hardEdge,
                        child: InkWell(
                          key: ValueKey('recorder-status-$index'),
                          onTap: () => controller.animateTo(index),
                          child: SizedBox(
                            height: 36,
                            child: Center(
                              child: Text(
                                labels[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: selected
                                      ? theme.colorScheme.onPrimaryContainer
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          }
          rows.add(Row(children: children));
        }
        return ColoredBox(
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: rows),
          ),
        );
      },
    );
  }
}

class RecorderBoundedTaskList extends StatefulWidget {
  const RecorderBoundedTaskList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;

  @override
  State<RecorderBoundedTaskList> createState() => _RecorderBoundedTaskListState();
}

class _RecorderBoundedTaskListState extends State<RecorderBoundedTaskList> {
  final ScrollController _controller = ScrollController();

  @override
  void didUpdateWidget(covariant RecorderBoundedTaskList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) _scheduleBoundaryClamp();
  }

  void _scheduleBoundaryClamp() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final position = _controller.position;
      final bounded = position.pixels
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((bounded - position.pixels).abs() > 0.01) _controller.jumpTo(bounded);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _scheduleBoundaryClamp();
        return false;
      },
      child: ScrollConfiguration(
        behavior: const _RecorderScrollBehavior(),
        child: ListView.builder(
          controller: _controller,
          primary: false,
          physics: const PureLiveBoundedScrollPhysics(),
          clipBehavior: Clip.hardEdge,
          padding: widget.padding,
          itemCount: widget.itemCount,
          itemBuilder: widget.itemBuilder,
        ),
      ),
    );
  }
}

class _RecorderScrollBehavior extends MaterialScrollBehavior {
  const _RecorderScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const PureLiveBoundedScrollPhysics();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}
