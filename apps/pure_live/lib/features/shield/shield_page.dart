import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/shield/shield_lists.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The danmaku shield page: the same lists the room's block tab edits, hosted
/// standalone for the settings and header entries. The reference keeps one
/// editable surface reached two ways; so does this.
final class ShieldPage extends ConsumerWidget {
  /// The shield page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PureScaffold(
      appBar: PureAppBar(title: context.t.shield.title, actions: const [SettingsEntryButton()]),
      body: const ShieldListsPanel(),
    );
  }
}
