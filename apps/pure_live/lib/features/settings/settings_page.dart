import 'package:flutter/material.dart';

import 'package:pure_live/app/routing/routes/settings/settings_routes.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';

/// The settings cluster's index page: one row per shipped settings page.
///
/// A row appears with its feature wave — the cluster grows without this
/// page changing shape.
final class SettingsPage extends StatelessWidget {
  /// The settings index.
  const new({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t.tabs.settings), actions: const [SettingsEntryButton()]),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(context.t.settings.appearance),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => const AppearanceRoute().push<void>(context),
          ),
        ),
      ],
    ),
  );
}
