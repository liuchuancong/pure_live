import 'package:flutter/material.dart';

import 'package:pure_live/app/routing/routes/settings/settings_routes.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';

/// The chrome's and the pages' way into settings: a rail's trailing corner
/// on desktop, a page app bar's action under touch. A push, not a branch
/// switch — the route is a full page above the shell.
final class SettingsEntryButton extends StatelessWidget {
  /// The settings entry.
  const new({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.settings_outlined),
    tooltip: context.t.tabs.settings,
    onPressed: () => const SettingsRoute().push<void>(context),
  );
}
