import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/favorites/data/follow_repository.dart' show followsProvider;
import 'package:pure_live/features/favorites/data/follow_tags.dart';
import 'package:pure_live/l10n/translations.dart';

/// Follow tags (the reference's `TagsPage`, reached from its platforms
/// group): the viewer's own groups for followed rooms. One row per tag —
/// drag its handle to reorder (the favorites' tag strip follows this
/// order), open the menu to pin, edit or delete it — an 添加 action in the
/// header, and the count of rooms that carry each tag.
///
/// The list is capped to the settings page's own width; deleting asks
/// first and says how many rooms lose the tag, exactly as the reference.
final class FollowTagsPane extends ConsumerStatefulWidget {
  /// The tags pane.
  const FollowTagsPane({super.key});

  @override
  ConsumerState<FollowTagsPane> createState() => _FollowTagsPaneState();
}

final class _FollowTagsPaneState extends ConsumerState<FollowTagsPane> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() change) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await change();
    } on Object {
      if (mounted) showDsToast(context: context, title: context.t.settings.tagSaveFailed, status: DsStatus.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([FollowTag? tag]) async {
    final saved = await showFollowTagEditor(context, tag: tag);
    if (saved == null || !mounted) return;
    showDsToast(
      context: context,
      title: tag == null
          ? context.t.settings.tagAddedToast(name: saved.name)
          : context.t.settings.tagSavedToast(name: saved.name),
    );
  }

  Future<void> _delete(FollowTag tag, int rooms) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.settings.tagDeleteTitle(name: tag.name),
      description: rooms > 0 ? t.settings.tagDeleteRoomsHint(count: rooms) : t.settings.tagDeleteBody,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.tag),
    );
    if (!confirmed) return;
    await _run(() => ref.read(followTagsProvider.notifier).remove(tag.id));
    if (mounted) showDsToast(context: context, title: t.settings.tagDeletedToast(name: tag.name));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final tags = ref.watch(followTagsProvider);
    final rooms = ref.watch(followsProvider).rooms;
    int countOf(String id) => rooms.where((room) => room.local.tagIds.contains(id)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s3,
                children: [
                  Text(t.settings.tagManagement, style: theme.typography.title.copyWith(color: colors.text)),
                  Text(t.settings.tagManagementDesc, style: theme.typography.caption.copyWith(color: colors.textMuted)),
                ],
              ),
            ),
            DsButton(
              variant: DsButtonVariant.tinted,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.plus, size: 16),
              onPressed: _busy ? null : () => unawaited(_edit()),
              child: Text(t.settings.tagAdd),
            ),
          ],
        ),
        if (_busy) const Center(child: DsSpinner(style: DsSpinnerStyle(size: 18))),
        if (tags.isEmpty)
          DsEmptyState(
            icon: const DsIcon(DsIcons.tag),
            title: Text(t.settings.tagEmptyTitle),
            description: Text(t.settings.tagEmptyHint),
            actions: [
              DsButton(
                onPressed: _busy ? null : () => unawaited(_edit()),
                child: Text(t.settings.tagAdd),
              ),
            ],
          )
        else ...[
          Text(t.settings.tagSortTip, style: theme.typography.caption.copyWith(color: colors.textMuted)),
          DsReorderableList(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            defaultHandles: false,
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              return DsListRow(
                key: ValueKey(tag.id),
                leading: const DsReorderableHandle(),
                title: Text(tag.name),
                description: Text(
                  [
                    tag.description,
                    t.settings.tagRooms(count: countOf(tag.id)),
                  ].where((line) => line.isNotEmpty).join(' · '),
                ),
                trailing: _TagMenu(
                  tag: tag,
                  rooms: countOf(tag.id),
                  onEdit: () => unawaited(_edit(tag)),
                  onDelete: () => unawaited(_delete(tag, countOf(tag.id))),
                  onPin: () => unawaited(_run(() => ref.read(followTagsProvider.notifier).pinToTop(tag.id))),
                ),
              );
            },
            onReorder: (from, to) => unawaited(_run(() => ref.read(followTagsProvider.notifier).move(from, to))),
          ),
        ],
      ],
    );
  }
}

/// One tag's menu: 置顶 (the reference's pin), 编辑 and the confirmed 删除.
final class _TagMenu extends StatelessWidget {
  const _TagMenu({
    required this.tag,
    required this.rooms,
    required this.onEdit,
    required this.onDelete,
    required this.onPin,
  });

  final FollowTag tag;
  final int rooms;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsMenuAnchor(
      semanticLabel: t.recorder.menuMore,
      align: DsAlign.end,
      builder: (context, controller, child) => DsPressable(
        semanticLabel: t.recorder.menuMore,
        onPressed: controller.toggle,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Padding(
            padding: const EdgeInsets.all(DsSpace.s4),
            child: DsIcon(DsIcons.ellipsisVertical, size: theme.sizes.iconSm, color: hovered ? colors.text : colors.textSubtle),
          );
        },
      ),
      items: [
        DsMenuItem(leading: const DsIcon(DsIcons.pin), label: Text(t.settings.tagPin), onPressed: onPin),
        DsMenuItem(leading: const DsIcon(DsIcons.pencil), label: Text(t.settings.tagEdit), onPressed: onEdit),
        const DsMenuDivider(),
        DsMenuItem(
          leading: const DsIcon(DsIcons.trash2),
          label: Text(t.common.delete),
          destructive: true,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

/// The add or edit dialog (the reference's `TagEditorDialog`): the name and
/// its note, checked on save — a blank name, a duplicate of another tag, or
/// a tag that was removed elsewhere while the dialog was open all refuse
/// with a message instead of writing.
Future<FollowTag?> showFollowTagEditor(BuildContext context, {FollowTag? tag}) => showDsDialog<FollowTag>(
  context: context,
  builder: (dialogContext) => _FollowTagEditorDialog(tag: tag),
);

final class _FollowTagEditorDialog extends ConsumerStatefulWidget {
  const _FollowTagEditorDialog({this.tag});

  final FollowTag? tag;

  @override
  ConsumerState<_FollowTagEditorDialog> createState() => _FollowTagEditorDialogState();
}

final class _FollowTagEditorDialogState extends ConsumerState<_FollowTagEditorDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.tag?.name ?? '');
  late final TextEditingController _description = TextEditingController(text: widget.tag?.description ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _refuse(Translations t, String message) {
    setState(() {
      _saving = false;
      _error = message;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    final t = context.t;
    final controller = ref.read(followTagsProvider.notifier);
    final name = _name.text.trim();
    if (name.isEmpty) {
      _refuse(t, t.settings.tagNameEmpty);
      return;
    }
    if (widget.tag != null && controller.byId(widget.tag!.id) == null) {
      // The tag went away in another window while this dialog was open.
      _refuse(t, t.settings.tagStale);
      return;
    }
    if (!controller.nameUsable(name, excludingId: widget.tag?.id)) {
      _refuse(t, t.settings.tagNameDuplicate);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final original = widget.tag;
    final FollowTag? saved;
    if (original == null) {
      saved = await controller.add(name, description: _description.text);
    } else {
      saved = await controller.rename(original.id, name: name, description: _description.text)
          ? controller.byId(original.id)
          : null;
    }
    if (!mounted) return;
    if (saved == null) {
      _refuse(t, t.settings.tagSaveFailed);
      return;
    }
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsDialog(
      title: Text(widget.tag == null ? t.settings.tagAdd : t.settings.tagEdit),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s6,
        children: [
          Text(t.settings.tagNameLabel, style: theme.typography.caption.copyWith(color: colors.textMuted)),
          DsTextField(
            controller: _name,
            autofocus: widget.tag == null,
            clearable: true,
            maxLength: kFollowTagNameMaxLength,
            placeholder: t.settings.tagNameHint,
            semanticLabel: t.settings.tagNameLabel,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => unawaited(_submit()),
          ),
          const SizedBox(height: DsSpace.s6),
          Text(t.settings.tagNoteLabel, style: theme.typography.caption.copyWith(color: colors.textMuted)),
          DsTextField.multiline(
            controller: _description,
            minLines: 2,
            maxLines: 3,
            maxLength: kFollowTagDescriptionMaxLength,
            placeholder: t.settings.tagNoteHint,
            semanticLabel: t.settings.tagNoteLabel,
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null) DsAlert(title: Text(_error!), status: DsStatus.danger, announce: true),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        DsButton(
          onPressed: _saving ? null : () => unawaited(_submit()),
          child: Text(t.settings.tagSaveAction),
        ),
      ],
    );
  }
}
