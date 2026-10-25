import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/browse_settings_providers.dart' show browseLayoutProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart' show CardLayout;

/// The card/list switch on the feed pages: two icon segments, the current
/// layout filled. The choice is one preference, so every feed the viewer
/// opens next agrees with the one they just set.
final class LayoutToggle extends ConsumerWidget {
  /// The layout switch.
  const LayoutToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final layout = ref.watch(browseLayoutProvider);
    return DsTooltip(
      message: t.common.layout,
      child: DsSegmentedControl<CardLayout>(
        value: layout,
        onChanged: (value) => unawaited(ref.read(browseLayoutProvider.notifier).set(value)),
        semanticLabel: t.common.layout,
        segments: [
          DsSegment(
            value: CardLayout.grid,
            icon: const DsIcon(DsIcons.layoutGrid, size: 16),
            semanticLabel: t.common.layoutGrid,
          ),
          DsSegment(
            value: CardLayout.list,
            icon: const DsIcon(DsIcons.rows3, size: 16),
            semanticLabel: t.common.layoutList,
          ),
        ],
      ),
    );
  }
}
