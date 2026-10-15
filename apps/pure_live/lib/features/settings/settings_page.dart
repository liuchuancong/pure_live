import 'package:flutter/material.dart';
import 'package:live_uikit/styling.dart';

import 'package:pure_live/l10n/generated/strings.g.dart';

/// The settings domain's index page: the entry list of the settings cluster.
///
/// A placeholder — the cluster's pages (appearance, danmaku, font, logs,
/// backup, …) land with their own waves; the route is already where they
/// mount.
final class SettingsPage extends StatelessWidget {
  /// The settings index page.
  const new({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.t.tabs.settings)),
    body: LiveEmpty(title: context.t.common.empty),
  );
}
