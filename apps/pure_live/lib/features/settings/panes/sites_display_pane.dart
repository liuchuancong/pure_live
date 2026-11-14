import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/browse/sites_display_provider.dart'
    show sitesDisplayProvider, sitesOrderProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// The platform display page: every platform the build carries, one row
/// each, in the order the browse surfaces read and filtered by the visibility
/// the switches set.
///
/// A table because the list is long and every row says the same three things
/// — which platform, what it is called in the build, whether it shows. The
/// three actions above it do the whole list at once: 全部打开, 全部关闭 (which
/// keeps one platform, since a browse page with none is not a choice) and
/// 重置, which asks first and then puts the visibility, the order and the
/// preferred platform back to what this build ships.
final class SitesDisplayPane extends ConsumerStatefulWidget {
  const SitesDisplayPane({super.key});

  @override
  ConsumerState<SitesDisplayPane> createState() => SitesDisplayPaneState();
}

final class SitesDisplayPaneState extends ConsumerState<SitesDisplayPane> {
  /// While a bulk action is in flight its buttons wait; a row's own switch
  /// never blocks, it is one write.
  bool _busy = false;

  /// The draft behind the 编辑 button: the reordered ids and the hidden set
  /// they will leave behind, shown by the rows and written as one save. Null
  /// while the page only reads the stored state.
  ({List<String> order, Set<String> hidden})? _draft;

  void _startEdit() {
    final order = ref.read(sitesOrderProvider).order;
    final hidden = ref.read(sitesDisplayProvider);
    setState(() => _draft = (order: List.of(order), hidden: Set.of(hidden)));
  }

  void _cancelEdit() {
    setState(() => _draft = null);
  }

  /// Writes the draft as one save — the order first, then the hidden set —
  /// and leaves the edit. A draft that hides every row is refused here: the
  /// browsing pages never lead with no platform at all, and the reason stays
  /// on screen.
  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    final t = context.t;
    if (!draft.order.any((id) => !draft.hidden.contains(id))) {
      showDsToast(context: context, title: t.settings.sitesKeepOne);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(sitesOrderProvider.notifier).setOrder(draft.order);
      await ref.read(sitesDisplayProvider.notifier).setHidden(draft.hidden);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) setState(() => _draft = null);
  }

  /// Moves [id] to [target] in the draft order — the row's
  /// 置顶/上移/下移/置底 buttons; the stored order changes at the save.
  void _moveDraft(String id, int target) {
    final draft = _draft;
    if (draft == null) return;
    final from = draft.order.indexOf(id);
    if (from < 0) return;
    final to = target.clamp(0, draft.order.length - 1);
    if (to == from) return;
    final order = [...draft.order];
    order.insert(to, order.removeAt(from));
    setState(() => _draft = (order: order, hidden: draft.hidden));
  }

  /// The drag list's move — the same draft edit the row's order buttons
  /// make: the item at [from] lands at [to], counted after the move, and
  /// nothing is written until the save.
  void _reorderDraft(int from, int to) {
    final draft = _draft;
    if (draft == null) return;
    final order = [...draft.order];
    order.insert(to, order.removeAt(from));
    setState(() => _draft = (order: order, hidden: draft.hidden));
  }

  /// Flips [id] in the draft's hidden set; the stored set changes at the
  /// save, which alone keeps at least one platform shown.
  void _toggleDraft(String id, bool value) {
    final draft = _draft;
    if (draft == null) return;
    final hidden = Set.of(draft.hidden);
    if (value) {
      hidden.remove(id);
    } else {
      hidden.add(id);
    }
    setState(() => _draft = (order: draft.order, hidden: hidden));
  }

  /// The switch's write-through outside the edit: one flip, one write, with
  /// the keep-one rule answered on screen when it holds the flip back.
  Future<void> _toggleShown(BuildContext context, String id) async {
    final changed = await ref.read(sitesDisplayProvider.notifier).toggle(id);
    if (!changed && context.mounted) {
      showDsToast(context: context, title: context.t.settings.sitesKeepOne);
    }
  }

  Future<void> _setAllShown(bool value) async {
    if (_busy) return;
    final t = context.t;
    setState(() => _busy = true);
    try {
      final changed = await ref.read(sitesDisplayProvider.notifier).setAllShown(value: value);
      // Turning all off with one platform left shown changes nothing, and the
      // reason belongs on screen.
      if (!changed && !value && mounted) {
        showDsToast(context: context, title: t.settings.sitesKeepOne);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final t = context.t;
    final confirmed = await showAppConfirm(
      context: context,
      title: t.settings.sitesReset,
      description: t.settings.sitesResetDesc,
      confirmLabel: t.common.confirm,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(sitesDisplayProvider.notifier).setAllShown(value: true);
      await ref.read(sitesOrderProvider.notifier).reset();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final sites = ref.watch(sitesProvider).all;
    final hidden = ref.watch(sitesDisplayProvider);
    final order = ref.watch(sitesOrderProvider);
    final names = {for (final site in sites) site.manifest.id: localizedSiteName(site)};
    final sitesById = {for (final site in sites) site.manifest.id: site};
    // While the edit is open the rows read the draft; otherwise the stored
    // state — the hidden set stores the platforms switched off, and an empty
    // set shows everything.
    final editing = _draft != null;
    final ids = _draft?.order ?? order.order;
    final draftHidden = _draft?.hidden;
    bool shown(String id) => draftHidden != null ? !draftHidden.contains(id) : hidden.isEmpty || !hidden.contains(id);

    // The pushed page is already named 平台显示, so the first section
    // carries the list itself: one row per platform, icon and name on
    // the line, the id under it, and the trailing switch. In the edit
    // the rows sit in a reorderable list — the end-side grip drags a
    // platform to its place, Alt+Up/Down moves it from the keyboard,
    // and the four buttons stay for the one-click 置顶/置底 — and every
    // move edits the draft; the stored order follows at the save.
    Widget platformRow(String id, int index) => DsListRow(
      key: ValueKey(id),
      // In the edit the grip leads the row — drag from the left edge, the
      // way a sortable column reads — with the platform's icon beside it.
      leading: editing
          ? Row(
              mainAxisSize: MainAxisSize.min,
              spacing: DsSpace.s8,
              children: [
                const DsReorderableHandle(),
                localizedSiteIcon(sitesById[id], size: 20) ?? const DsIcon(DsIcons.antenna),
              ],
            )
          : localizedSiteIcon(sitesById[id], size: 20) ?? const DsIcon(DsIcons.antenna),
      title: Text(names[id] ?? id),
      description: Text(id),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          if (editing) ...[
            _orderButton(context, DsIcons.arrowUpToLine, t.settings.moveToTop, index > 0, () => _moveDraft(id, 0)),
            _orderButton(context, DsIcons.arrowUp, t.settings.moveUp, index > 0, () => _moveDraft(id, index - 1)),
            _orderButton(
              context,
              DsIcons.arrowDown,
              t.settings.moveDown,
              index < ids.length - 1,
              () => _moveDraft(id, index + 1),
            ),
            _orderButton(
              context,
              DsIcons.arrowDownToLine,
              t.settings.moveToBottom,
              index < ids.length - 1,
              () => _moveDraft(id, ids.length - 1),
            ),
            const SizedBox(width: DsSpace.s4),
          ],
          DsSwitch(
            value: shown(id),
            semanticLabel: names[id] ?? id,
            onChanged: (value) => editing ? _toggleDraft(id, value) : unawaited(_toggleShown(context, id)),
          ),
        ],
      ),
      semanticLabel: names[id] ?? id,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        // The page's actions sit at the very top as buttons, not as rows to
        // scroll past — the danmaku style page keeps its reset the same way.
        // The bulk actions stand beside the edit; while a draft is open they
        // stand down, the draft's save being then the page's only writer.
        // Save is the page's one primary action.
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Wrap(
            spacing: DsSpace.s8,
            children: [
              if (editing) ...[
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: _busy ? null : _cancelEdit,
                  child: Text(t.common.cancel),
                ),
                DsButton(
                  variant: DsButtonVariant.primary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.check, size: 16),
                  onPressed: _busy ? null : () => unawaited(_save()),
                  child: Text(t.settings.saveOrder),
                ),
              ] else ...[
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.eye, size: 16),
                  onPressed: _busy ? null : () => unawaited(_setAllShown(true)),
                  child: Text(t.settings.sitesShowAll),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.eyeOff, size: 16),
                  onPressed: _busy ? null : () => unawaited(_setAllShown(false)),
                  child: Text(t.settings.sitesHideAll),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.rotateCcw, size: 16),
                  onPressed: _busy ? null : () => unawaited(_reset()),
                  child: Text(t.settings.sitesReset),
                ),
                DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  leading: const DsIcon(DsIcons.edit, size: 16),
                  onPressed: _busy ? null : _startEdit,
                  child: Text(t.settings.editOrder),
                ),
              ],
            ],
          ),
        ),
        // The pushed page is already named 平台显示, so the first section
        // carries the list itself (see platformRow above). In the edit the
        // rows sit in a reorderable list; outside it the list is plain.
        if (editing)
          DsListSection(
            header: Text(t.settings.sitesGroupList),
            children: [
              DsReorderableList(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: ids.length,
                // The grip rides in each row's leading, so no end handle.
                defaultHandles: false,
                onReorder: _reorderDraft,
                itemBuilder: (context, index) => platformRow(ids[index], index),
              ),
            ],
          )
        else
          DsListSection(
            header: Text(t.settings.sitesGroupList),
            children: [for (final (index, id) in ids.indexed) platformRow(id, index)],
          ),
      ],
    );
  }

  /// One of the four order buttons at a row's end: a small square glyph that
  /// greys out when the row already sits where it would move.
  Widget _orderButton(BuildContext context, DsIconData icon, String label, bool enabled, VoidCallback onPressed) {
    return DsButton.icon(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      semanticLabel: label,
      onPressed: enabled ? onPressed : null,
      icon: DsIcon(icon, size: 14),
    );
  }
}
