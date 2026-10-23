import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/i18n/translations.g.dart';

/// The live branch: rooms from the wired-in sites.
///
/// The site registry and the room wall arrive with the sites phase; until
/// then the page says what it is waiting for instead of showing nothing at
/// all.
final class LivePage extends ConsumerWidget {
  /// The live page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: DsEmptyState(title: Text(t.live.empty), icon: const DsIcon(DsIcons.tv)),
    );
  }
}
