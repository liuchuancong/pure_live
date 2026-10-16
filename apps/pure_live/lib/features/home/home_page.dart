import 'package:flutter/material.dart';
import 'package:live_uikit/live_uikit.dart';
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
  Widget build(BuildContext context) => LiveScaffold(
    appBar: LiveAppBar(title: context.t.tabs.home, actions: const [SettingsEntryButton()]),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final entry in HomeMenuEntry.all(context))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LiveCard(
              padding: EdgeInsets.zero,
              child: LiveListRow(
                leading: Icon(entry.icon),
                title: entry.label,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => entry.onOpen(context),
                divided: false,
              ),
            ),
          ),
      ],
    ),
  );
}
