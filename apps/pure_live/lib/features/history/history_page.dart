import 'package:flutter/material.dart';
import 'package:live_uikit/styling.dart';

import 'package:pure_live/app/shell/app_shell.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';

/// The history domain's shell page: what the user watched, newest first.
/// A placeholder until the user-data wave lands.
final class HistoryPage extends StatelessWidget {
  /// The history page.
  const new({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t.tabs.history), actions: const [SettingsEntryButton()]),
    body: LiveEmpty(title: context.t.common.empty),
  );
}
