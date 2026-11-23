import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/shield/shield_add_field.dart';
import 'package:pure_live/shared/widgets/app_dialog.dart';

/// How many entries the wall draws before the count line takes over.
const int kShieldEntryListPreview = 100;

/// One managed list's body — the inline add field under a wrap of removable
/// entries, with the destructive clear beside the add button — the piece both
/// the settings pane's section and the room panel's accordion group draw. A
/// head of the wall instead of all of it: the lists take 5000 entries, and one
/// wrap of 5000 buttons is a frame no pane should pay for; the count line
/// names the rest and unfolds on a press.
///
/// The wall owns the words of removing (the confirm, the toasts) so every
/// surface that edits a list answers the same way. What it does not own is
/// the shell: the section header and the empty-state line belong to the
/// caller, which knows the container it sits in.
final class ShieldEntryWall extends ConsumerStatefulWidget {
  /// The list's body.
  const ShieldEntryWall({
    required this.entries,
    required this.fieldHint,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
    this.hasRoom,
    this.acceptsPatterns = false,
    super.key,
  });

  /// The entries, in stored order.
  final List<String> entries;

  /// The add field's placeholder.
  final String fieldHint;

  /// Whether a word written `/…/` means a regular expression here. It is the
  /// keyword list's property, not the user list's, and the guard that decides
  /// whether a pattern is safe to run belongs to the site package — which also
  /// owns the format the room's filter and the recording's sidecar read.
  final bool acceptsPatterns;

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
  ConsumerState<ShieldEntryWall> createState() => _ShieldEntryWallState();
}

final class _ShieldEntryWallState extends ConsumerState<ShieldEntryWall> {
  /// Whether the viewer asked for the whole wall instead of its head.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final entries = widget.entries;
    final visible = _expanded ? entries.length : kShieldEntryListPreview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShieldAddField(
          fieldHint: widget.fieldHint,
          acceptsPatterns: widget.acceptsPatterns,
          onAdd: widget.onAdd,
          hasRoom: widget.hasRoom,
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s8, DsSpace.s20, DsSpace.s8),
          // Clearing the whole list sits beside the add button: both are
          // actions on the list.
          trailing: entries.isEmpty
              ? null
              : DsButton(
                  variant: DsButtonVariant.dangerSoft,
                  size: DsSize.sm,
                  onPressed: () => unawaited(_clear(context)),
                  child: Text(t.shield.clear),
                ),
        ),
        if (entries.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s16, DsSpace.s12, DsSpace.s16, DsSpace.s12),
            child: Wrap(
              spacing: DsSpace.s8,
              runSpacing: DsSpace.s6,
              children: [
                for (final entry in entries.take(visible))
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.xs,
                    trailing: const DsIcon(DsIcons.trash2, size: 14),
                    semanticLabel: '${t.shield.removeEntry} $entry',
                    onPressed: () => unawaited(_remove(context, entry)),
                    child: Text(entry),
                  ),
                if (entries.length > visible)
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.xs,
                    onPressed: () => setState(() => _expanded = true),
                    child: Text(t.shield.moreNotShown(count: entries.length - visible)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _remove(BuildContext context, String value) async {
    await widget.onRemove(value);
    if (!context.mounted) return;
    showDsToast(context: context, title: context.t.shield.removed);
  }

  Future<void> _clear(BuildContext context) async {
    final t = context.t;
    final confirmed = await showAppConfirm(
      context: context,
      title: t.shield.clear,
      description: t.shield.clearConfirmDesc,
      confirmLabel: t.common.confirm,
      destructive: true,
    );
    if (!confirmed) return;
    await widget.onClear();
    if (!context.mounted) return;
    showDsToast(context: context, title: t.shield.cleared);
  }
}
