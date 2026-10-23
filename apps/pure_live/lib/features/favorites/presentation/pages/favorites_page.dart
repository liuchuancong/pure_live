import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/i18n/translations.g.dart';

/// The favorites branch: the rooms and streamers the viewer follows.
///
/// The follow repository arrives with the library wiring; until then the
/// page shows its empty state.
final class FavoritesPage extends ConsumerWidget {
  /// The favorites page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: DsEmptyState(title: Text(t.generic.empty), icon: const DsIcon(DsIcons.heart)),
    );
  }
}
