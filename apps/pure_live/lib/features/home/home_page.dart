import 'package:flutter/material.dart';
import 'package:live_uikit/styling.dart';

import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/app/shell/app_shell.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';

/// The home domain's shell page: the section menu plus the recommendation
/// stream.
///
/// The menu entries open as full pages above the shell, exactly as the
/// directory architecture routes them; the recommendation stream itself is
/// the next content wave.
final class HomePage extends StatelessWidget {
  /// The home page.
  const new({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t.tabs.home), actions: const [SettingsEntryButton()]),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: Text(context.t.tabs.popular),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => const PopularRoute().push<void>(context),
          ),
        ),
        const SizedBox(height: 24),
        Text(context.t.home.recommended, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        LiveEmpty(title: context.t.common.empty),
      ],
    ),
  );
}
