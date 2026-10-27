import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/l10n/translations.dart';

/// One orderable list on a settings page.
///
/// Out of editing it shows the saved order read-only, with an 「编辑顺序」
/// action on the header line. That action opens a draft the viewer keeps:
/// every row gains a drag grip at its start and 置顶/上移/下移/置底 at its
/// end, and a footer offers 取消 and 保存顺序. Nothing reaches storage until
/// the draft is saved, so an abandoned edit leaves the shell's order exactly
/// as it was.
///
/// [trailingOf] puts a live control on a view-mode row (a home entry's
/// visibility switch); those controls step out while the draft is open, since
/// the row's end now carries the order buttons. [extraRows] renders under the
/// list in view mode only — the home menu lists its hidden entries there,
/// which have no order to edit.
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

  @override
  State<SettingsOrderList<T>> createState() => _SettingsOrderListState<T>();
}

class _SettingsOrderListState<T> extends State<SettingsOrderList<T>> {
  /// The draft while the viewer edits, null in the read-only state.
  List<T>? _draft;

  bool get _editing => _draft != null;

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

  void _cancel() => setState(() => _draft = null);

  void _save() {
    final draft = _draft;
    if (draft == null) return;
    widget.onSave(draft);
    _cancel();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        DsListSection(
          header: Row(
            children: [
              Expanded(child: Text(widget.header)),
              // Nothing to order with a single entry, so the action simply
              // is not offered.
              if (canEdit && !_editing)
                DsButton(
                  size: DsSize.sm,
                  variant: DsButtonVariant.secondary,
                  leading: const DsIcon(DsIcons.listOrdered),
                  onPressed: _start,
                  child: Text(t.settings.editOrder),
                ),
            ],
          ),
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
        if (draft != null)
          Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: DsSpace.s6,
                  children: [
                    DsIcon(DsIcons.circleDot, size: 14, color: DsTheme.colorsOf(context).warning.signal),
                    Text(
                      t.settings.unsavedOrderDraft,
                      style: DsTheme.of(context).typography.small.copyWith(color: DsTheme.colorsOf(context).textMuted),
                    ),
                  ],
                ),
              ),
              DsButton(variant: DsButtonVariant.secondary, onPressed: _cancel, child: Text(t.common.cancel)),
              DsButton(
                variant: DsButtonVariant.primary,
                leading: const DsIcon(DsIcons.check),
                onPressed: _save,
                child: Text(t.settings.saveOrder),
              ),
            ],
          ),
      ],
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
    final colors = DsTheme.colorsOf(context);
    return DsPressable(
      semanticLabel: label,
      onPressed: enabled ? onPressed : null,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          width: 26,
          height: 26,
          decoration: DsBoxDecoration(
            color: hovered && enabled ? colors.hover : colors.control,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(child: DsIcon(icon, size: 14, color: enabled ? colors.textMuted : colors.textSubtle)),
        );
      },
    );
  }
}
