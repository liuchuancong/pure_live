import 'package:flutter/material.dart';

import 'package:pure_live/features/home/home_menu.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';

/// The home domain's shell page: the section menu the user opens the app's
/// destinations from (3.x `HomeMenu`; the destinations open as full pages
/// above the shell, exactly as the routes plan them).
///
/// The menu shows what exists — a destination appears with its feature
/// wave, never as a placeholder.
final class HomePage extends StatelessWidget {
  /// The home page.
  const new({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t.tabs.home), actions: const [SettingsEntryButton()]),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final entry in HomeMenuEntry.all(context))
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Icon(entry.icon),
              title: Text(entry.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => entry.onOpen(context),
            ),
          ),
      ],
    ),
  );
}
