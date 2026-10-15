import 'package:flutter/material.dart';

import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/app/routing/routes/search_routes.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';

/// A destination of the home menu: where it goes, and how it presents.
///
/// The recording centre joins when the recording wave lands; the menu
/// shows the destinations that exist, never placeholders.
final class HomeMenuEntry {
  /// A menu entry.
  const new({required this.label, required this.icon, required this.onOpen});

  /// The label.
  final String label;

  /// The icon.
  final IconData icon;

  /// Opens the destination (a push above the shell).
  final void Function(BuildContext context) onOpen;

  /// The home menu, in display order.
  static List<HomeMenuEntry> all(BuildContext context) => [
    HomeMenuEntry(
      label: context.t.tabs.popular,
      icon: Icons.local_fire_department_outlined,
      onOpen: (context) => const PopularRoute().push<void>(context),
    ),
    HomeMenuEntry(
      label: context.t.tabs.areas,
      icon: Icons.category_outlined,
      onOpen: (context) => const AreasRoute().push<void>(context),
    ),
    HomeMenuEntry(
      label: context.t.tabs.search,
      icon: Icons.search,
      onOpen: (context) => const SearchRoute().push<void>(context),
    ),
  ];
}
