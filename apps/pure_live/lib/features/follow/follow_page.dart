import 'package:flutter/material.dart';
import 'package:live_uikit/styling.dart';

import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';

/// The follow domain's shell page: the followed anchors with their groups
/// and tags. A placeholder until the user-data wave lands.
final class FollowPage extends StatelessWidget {
  /// The follow page.
  const new({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t.tabs.follow), actions: const [SettingsEntryButton()]),
    body: LiveEmpty(title: context.t.common.empty),
  );
}
