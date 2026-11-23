import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/modules/live/shield/shield_entry_wall.dart';

/// One managed list — a keyword list or a blocked-user list — as the one
/// section every surface that edits it draws: the section header over the
/// shared wall (the add field, the removable entries, the clear), and the
/// empty word when the list has nothing in it yet. The wall carries the
/// entries, the head-of-a-long-list rule and the removal words; this shell
/// only names the list.
///
/// Sharing the widget keeps the two editors honest: a keyword added in the
/// room's shield panel reads exactly like one added on the settings page,
/// because the rows, the confirm and the toasts are the same code.
final class ShieldEntryList extends ConsumerStatefulWidget {
  /// The list's section.
  const ShieldEntryList({
    required this.icon,
    required this.title,
    required this.entries,
    required this.fieldHint,
    required this.emptyText,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
    this.hasRoom,
    this.acceptsPatterns = false,
    super.key,
  });

  /// The list's icon (a keyword's funnel, a user's person).
  final DsIconData icon;

  /// The section header's words.
  final String title;

  /// The entries, in stored order.
  final List<String> entries;

  /// The add field's placeholder.
  final String fieldHint;

  /// Whether a word written `/…/` means a regular expression here. It is the
  /// keyword list's property, not the user list's, and the guard that decides
  /// whether a pattern is safe to run belongs to the site package — which also
  /// owns the format the room's filter and the recording's sidecar read.
  final bool acceptsPatterns;

  /// What an empty list says.
  final String emptyText;

  /// Adds an entry; answers false when it is empty or a duplicate.
  final Future<bool> Function(String value) onAdd;

  /// Whether the list still takes an entry, read at the moment of the press;
  /// the field says "full" instead of "already here" when it answers false.
  final Future<bool> Function()? hasRoom;

  /// Removes one entry.
  final Future<void> Function(String value) onRemove;

  /// Drops every entry.
  final Future<void> Function() onClear;

  @override
  ConsumerState<ShieldEntryList> createState() => _ShieldEntryListState();
}

final class _ShieldEntryListState extends ConsumerState<ShieldEntryList> {
  @override
  Widget build(BuildContext context) {
    return DsListSection(
      header: Text(widget.title),
      children: [
        ShieldEntryWall(
          entries: widget.entries,
          fieldHint: widget.fieldHint,
          acceptsPatterns: widget.acceptsPatterns,
          onAdd: widget.onAdd,
          hasRoom: widget.hasRoom,
          onRemove: widget.onRemove,
          onClear: widget.onClear,
        ),
        // The empty word stands where the wall's entries would.
        if (widget.entries.isEmpty) DsListRow(leading: DsIcon(widget.icon), title: Text(widget.emptyText)),
      ],
    );
  }
}
