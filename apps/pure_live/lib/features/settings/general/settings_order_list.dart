import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

import 'package:pure_live/features/settings/surface/settings_page_action.dart';
import 'package:pure_live/l10n/translations.dart';

/// One orderable list on a settings page.
///
/// Out of editing it shows the saved order read-only, with a pencil at the
/// header's end. That action opens a draft the viewer keeps: every row gains a
/// drag grip at its start and 置顶/上移/下移/置底 at its end, and the same
/// corner turns into 取消 and the save tick. Nothing reaches storage until the
/// draft is saved, so an abandoned edit leaves the shell's order exactly as it
/// was — and leaving the page with a changed draft asks first.
///
/// [trailingOf] puts a live control on a view-mode row (a home entry's
/// visibility switch); those controls step out while the draft is open, since
/// the row's end now carries the order buttons. [extraRows] renders under the
/// list in view mode only — the home menu lists its hidden entries there,
/// which have no order to edit. [removableInDraft] lets a draft drop rows
/// too: the shield's word lists are content the viewer edits, so their save
/// receives whatever the draft holds.
final class SettingsOrderList<T> extends StatefulWidget {
  /// The list of [items] in their saved order.
  const SettingsOrderList({
    required this.header,
    required this.items,
    required this.identityOf,
    required this.labelOf,
    required this.leadingOf,
    required this.onSave,
    this.trailingOf,
    this.descriptionOf,
    this.extraRows = const [],
    this.removableInDraft = false,
    super.key,
  });

  /// The section's own name, on the header line.
  final String header;

  /// The orderable entries, in the order storage holds.
  final List<T> items;

  /// The value that identifies an entry across a move — its list key.
  final Object Function(T item) identityOf;

  /// A row's name.
  final String Function(T item) labelOf;

  /// A row's glyph: a platform's own icon, a menu item's design-system one.
  final Widget Function(T item) leadingOf;

  /// Called with the draft once the viewer saves it.
  final void Function(List<T> draft) onSave;

  /// A live control on a view-mode row; none while editing.
  final Widget? Function(T item)? trailingOf;

  /// One line under a row's name, in both states — a platform's id, say.
  final String? Function(T item)? descriptionOf;

  /// Rows below the list that belong to the page but not to the order.
  final List<Widget> extraRows;

  /// Whether a draft row may be dropped, for a list whose content — not only
  /// its order — is the viewer's to edit (the shield's words and users). The
  /// save then receives the shorter list; the caller decides what it means.
  final bool removableInDraft;

  @override
  State<SettingsOrderList<T>> createState() => _SettingsOrderListState<T>();
}

class _SettingsOrderListState<T> extends State<SettingsOrderList<T>> {
  /// The draft while the viewer edits, null in the read-only state.
  List<T>? _draft;

  /// The pushed page's header slot, when the page has one.
  ValueNotifier<Widget?>? _slot;

  /// The edit state and whether an action was offered, as last handed to the
  /// slot: the corner is republished only when its meaning changes, not on
  /// every rebuild.
  (bool, bool)? _published;

  bool get _editing => _draft != null;

  /// Whether the draft differs from what storage holds: what the back
  /// gesture would throw away.
  bool get _dirty => _draft != null && !listEquals(_draft, widget.items);

  /// One row's move within the draft; the grip's drop and every button come
  /// through here, so the two ways of editing cannot disagree.
  void _move(int from, int to) {
    final draft = _draft;
    if (draft == null) return;
    final target = to.clamp(0, draft.length - 1);
    if (target == from) return;
    setState(() {
      final next = [...draft];
      next.insert(target, next.removeAt(from));
      _draft = next;
    });
  }

  void _start() => setState(() => _draft = [...widget.items]);

  /// Drops one row from the draft. Storage is untouched until the save, and
  /// the last entry cannot go: an empty list is the clear-all's business.
  void _removeAt(int index) {
    final draft = _draft;
    if (draft == null || draft.length <= 1) return;
    setState(() => _draft = [...draft]..removeAt(index));
  }

  void _cancel() => setState(() => _draft = null);

  void _save() {
    final draft = _draft;
    if (draft == null) return;
    widget.onSave(draft);
    _cancel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slot = SettingsPageActionScope.maybeOf(context);
  }

  @override
  void dispose() {
    // The page outlives this list only while this list is gone with it: a
    // header left holding a dead action would press nothing.
    final slot = _slot;
    if (slot != null && _published != null) slot.value = null;
    super.dispose();
  }

  /// Hands [action] to the page header, once per edit state.
  void _publish(Widget? action) {
    final slot = _slot;
    final signature = (_editing, action != null);
    if (slot == null || _published == signature) return;
    _published = signature;
    // A header is above this body: notifying it mid-build would rebuild an
    // ancestor while the tree is still being laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) slot.value = action;
    });
  }

  /// Leaving with a changed draft asks before the order is dropped.
  Future<void> _confirmDiscard(BuildContext context) async {
    final t = context.t;
    final discard = await showDsConfirm(
      context: context,
      title: t.settings.discardOrderTitle,
      description: t.settings.discardOrderBody,
      confirmLabel: t.settings.discardOrderAction,
      cancelLabel: t.settings.keepEditingOrder,
      destructive: true,
    );
    if (!discard || !mounted) return;
    setState(() => _draft = null);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  Widget _viewRow(T item) {
    return DsListRow(
      leading: widget.leadingOf(item),
      title: Text(widget.labelOf(item)),
      description: _description(item),
      trailing: widget.trailingOf?.call(item),
    );
  }

  Widget? _description(T item) {
    final text = widget.descriptionOf?.call(item);
    return text == null ? null : Text(text);
  }

  /// The rule between two rows. [DsListSection] draws one above every row it
  /// holds, but the draft is a single child — the reorderable list — so its
  /// rows would otherwise run together. The same indent, read from the same
  /// style layers, so the two agree wherever the row theme is overridden.
  Widget _rowDivider(BuildContext context) {
    final theme = DsTheme.of(context);
    final row = DsListRowStyle.resolveLayers([
      DsListRow.defaultStyle(theme),
      DsListRowTheme.of(context).style,
    ], const {});
    final direction = Directionality.of(context);
    final padding = row.padding?.resolve(direction);
    final rowStart = padding == null
        ? DsSpace.s12
        : direction == TextDirection.ltr
        ? padding.left
        : padding.right;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: rowStart + (row.iconSize ?? 0) + (row.gap ?? DsSpace.s12),
        // The section's own `dividerEndIndent`, which has no scale token.
        end: 10,
      ),
      child: DsLine(color: theme.colors.border),
    );
  }

  Widget _draftRow(T item, int index) {
    final t = context.t;
    final draft = _draft!;
    final count = draft.length;
    final row = DsListRow(
      // The grip leads, as the reference's editor puts it: the handle names
      // the row as draggable before its content does.
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s8,
        children: [const DsReorderableHandle(), widget.leadingOf(item)],
      ),
      title: Text(widget.labelOf(item)),
      description: _description(item),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          _OrderButton(
            icon: DsIcons.arrowUpToLine,
            label: t.settings.moveToTop,
            enabled: index > 0,
            onPressed: () => _move(index, 0),
          ),
          _OrderButton(
            icon: DsIcons.arrowUp,
            label: t.settings.moveUp,
            enabled: index > 0,
            onPressed: () => _move(index, index - 1),
          ),
          _OrderButton(
            icon: DsIcons.arrowDown,
            label: t.settings.moveDown,
            enabled: index < count - 1,
            onPressed: () => _move(index, index + 1),
          ),
          _OrderButton(
            icon: DsIcons.arrowDownToLine,
            label: t.settings.moveToBottom,
            enabled: index < count - 1,
            onPressed: () => _move(index, count - 1),
          ),
          // A list whose content is editable drops a row from the draft; the
          // last entry stays, so the save never writes an empty list.
          if (widget.removableInDraft)
            _OrderButton(
              icon: DsIcons.trash2,
              label: t.common.delete,
              enabled: count > 1,
              onPressed: () => _removeAt(index),
            ),
        ],
      ),
    );
    if (index == count - 1) return KeyedSubtree(key: ValueKey(widget.identityOf(item)), child: row);
    return Column(key: ValueKey(widget.identityOf(item)), children: [row, _rowDivider(context)]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final items = widget.items;
    final canEdit = items.length > 1;
    final draft = _draft;
    final colors = DsTheme.colorsOf(context);
    // The one corner action: a pencil that opens the draft, then the tick
    // that saves it, with 取消 beside the tick to back out. Words rather
    // than a bare glyph, so the corner says what pressing it does.
    final action = canEdit
        ? Row(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s4,
            children: [
              if (_editing)
                DsButton(
                  variant: DsButtonVariant.ghost,
                  size: DsSize.sm,
                  onPressed: _cancel,
                  child: Text(t.common.cancel),
                ),
              DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                leading: DsIcon(_editing ? DsIcons.check : DsIcons.edit, color: _editing ? colors.accent : null),
                onPressed: _editing ? _save : _start,
                child: Text(_editing ? t.settings.saveOrder : t.settings.editOrder),
              ),
            ],
          )
        : null;
    // The pushed page has a header, and the action rides at its end; a pane
    // without one keeps the action on the list's own header line. Nothing to
    // order, nothing offered.
    _publish(action);
    final header = _slot == null && action != null
        ? Row(
            children: [
              Expanded(child: Text(widget.header)),
              action,
            ],
          )
        : Text(widget.header);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        DsListSection(
          header: header,
          children: [
            if (draft == null)
              for (final item in items) _viewRow(item)
            else
              DsReorderableList(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                defaultHandles: false,
                padding: EdgeInsets.zero,
                itemCount: draft.length,
                onReorder: _move,
                itemBuilder: (context, index) => _draftRow(draft[index], index),
              ),
            if (draft == null) ...widget.extraRows,
          ],
        ),
      ],
    );
    // A changed draft is not written until the tick is pressed: the back
    // gesture asks before it throws the order away.
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_dirty) return;
        unawaited(_confirmDiscard(context));
      },
      child: body,
    );
  }
}

/// One of the four order buttons at a draft row's end: a small square glyph
/// that greys out when the row already sits where it would move.
final class _OrderButton extends StatelessWidget {
  const _OrderButton({required this.icon, required this.label, required this.enabled, required this.onPressed});

  final DsIconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DsButton.icon(
      variant: DsButtonVariant.ghost,
      size: DsSize.sm,
      semanticLabel: label,
      onPressed: enabled ? onPressed : null,
      icon: DsIcon(icon, size: 14),
    );
  }
}
