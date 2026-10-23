import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/i18n/translations.g.dart';

/// The playlist branch: the viewer's queues and the IPTV list they build.
///
/// The playlist models arrive with the IPTV phase; until then the page
/// shows its empty state.
final class PlaylistPage extends ConsumerWidget {
  /// The playlist page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: DsEmptyState(title: Text(t.generic.empty), icon: const DsIcon(DsIcons.list)),
    );
  }
}
