import 'package:flutter/material.dart';
import 'package:pure_live/app/routing/routes/backup/backup_routes.dart';
import 'package:pure_live/app/routing/routes/settings/settings_routes.dart';
import 'package:pure_live/app/routing/routes/settings/shield_routes.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The settings cluster's index page: one row per shipped settings page.
///
/// A row appears with its feature wave — the cluster grows without this
/// page changing shape.
final class SettingsPage extends StatelessWidget {
  /// The settings index.
  const new({super.key});

  @override
  Widget build(BuildContext context) => PureScaffold(
    appBar: PureAppBar(title: context.t.tabs.settings, actions: const [SettingsEntryButton()]),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PureCard(
            padding: EdgeInsets.zero,
            child: PureListRow(
              leading: const Icon(Icons.palette_outlined),
              title: context.t.settings.appearance,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => const AppearanceRoute().push<void>(context),
              divided: false,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PureCard(
            padding: EdgeInsets.zero,
            child: PureListRow(
              leading: const Icon(Icons.shield_outlined),
              title: context.t.shield.title,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => const ShieldRoute().push<void>(context),
              divided: false,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PureCard(
            padding: EdgeInsets.zero,
            child: PureListRow(
              leading: const Icon(Icons.backup_outlined),
              title: context.t.backup.title,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => const BackupRoute().push<void>(context),
              divided: false,
            ),
          ),
        ),
      ],
    ),
  );
}
