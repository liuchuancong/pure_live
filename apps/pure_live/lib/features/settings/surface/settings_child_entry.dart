import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/settings/surface/settings_navigation.dart' show openSettingsChild;
import 'package:pure_live/features/settings/surface/settings_sections.dart' show SettingsSection;
import 'package:pure_live/l10n/translations.dart';

/// The entry row a parent pane offers for its subpage: the subpage's own
/// name and description, opening in place on desktop and as its own route
/// on a touch shell — the way the background page already lists its five
/// sources.
final class SettingsChildEntry extends ConsumerWidget {
  /// The entry to [child].
  const SettingsChildEntry({required this.child, this.detail, super.key});

  /// The subpage this row opens.
  final SettingsSection child;

  /// The subpage's current value, shown on the row.
  final Widget? detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return DsListRow(
      leading: DsIcon(child.icon),
      title: Text(child.label(t)),
      description: Text(child.description(t)),
      detail: detail,
      showChevron: true,
      onPressed: () => openSettingsChild(context, ref, child),
    );
  }
}
