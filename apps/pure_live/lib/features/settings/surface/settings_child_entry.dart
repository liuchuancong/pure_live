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
///
/// [title] and [description] replace the section's own words where a parent
/// opens a page that carries more than that page shows it: the shared picture
/// and sound pages are named for the live room's full set, and a module that
/// only obeys some of those rows must not promise the rest.
final class SettingsChildEntry extends ConsumerWidget {
  /// The entry to [child], titled [title] rather than the section's own name
  /// when one is given.
  const SettingsChildEntry({required this.child, this.title, this.description, this.detail, super.key});

  /// The subpage this row opens.
  final SettingsSection child;

  /// What the row is called, or null for the section's own label.
  final String? title;

  /// The line under the row, or null for the section's own description.
  final String? description;

  /// The subpage's current value, shown on the row.
  final Widget? detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return DsListRow(
      leading: DsIcon(child.icon),
      title: Text(title ?? child.label(t)),
      description: Text(description ?? child.description(t)),
      detail: detail,
      showChevron: true,
      onPressed: () => openSettingsChild(context, ref, child),
    );
  }
}
