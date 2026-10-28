import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart' show followsProvider;
import 'package:pure_live/modules/live/favorites/data/follow_tags.dart';

/// Opens the tags of one followed [room]: the tags it belongs to, a tap to
/// join or leave one, an inline field for a new tag, and a remove action per
/// tag that also strips it from every follow. Everything writes through the
/// follows store at once, so the page behind the panel is already right
/// when it closes.
///
/// The panel follows the kit's own sheet: a title and close in the header,
/// labelled sections for the tags and the new one, and the closing action in
/// the footer.
Future<void> showFollowTagPicker(BuildContext context, LiveRoom room) => showDsPanel<void>(
  context: context,
  builder: (context) => DsPanel(
    title: Text(context.t.favorites.setTags),
    footer: DsButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.t.common.save)),
    child: _FollowTagPicker(room: room),
  ),
);

final class _FollowTagPicker extends ConsumerStatefulWidget {
  const _FollowTagPicker({required this.room});

  final LiveRoom room;

  @override
  ConsumerState<_FollowTagPicker> createState() => _FollowTagPickerState();
}

final class _FollowTagPickerState extends ConsumerState<_FollowTagPicker> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Set<String> get _selected {
    final followed = ref
        .watch(followsProvider)
        .rooms
        .where((room) => room.ref.identityKey == widget.room.ref.identityKey)
        .firstOrNull;
    return {...(followed ?? widget.room).local.tagIds};
  }

  Future<void> _toggle(String tagId) async {
    final current = _selected;
    final next = current.contains(tagId) ? (current..remove(tagId)) : (current..add(tagId));
    await ref.read(followsProvider.notifier).setTags(widget.room.ref.identityKey, next.toList());
  }

  Future<void> _add() async {
    final t = context.t;
    final word = _field.text.trim();
    if (word.isEmpty) {
      showDsToast(context: context, title: t.favorites.tagInvalid);
      return;
    }
    final tag = await ref.read(followTagsProvider.notifier).add(word);
    if (!mounted) return;
    if (tag == null) {
      showDsToast(context: context, title: t.favorites.tagExists);
      return;
    }
    _field.clear();
    await _toggle(tag.id);
  }

  Future<void> _removeTag(FollowTag tag) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.favorites.deleteTagTitle(name: tag.name),
      description: t.favorites.deleteTagBody,
      confirmLabel: t.favorites.deleteTag,
      destructive: true,
      icon: const DsIcon(DsIcons.tag),
    );
    if (!confirmed) return;
    await ref.read(followTagsProvider.notifier).remove(tag.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final tags = ref.watch(followTagsProvider);
    final selected = _selected;
    final sectionLabel = theme.typography.fieldLabel.copyWith(color: colors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s20,
      children: [
        // The tags the room may carry: each one its own check, so several
        // can be on at once.
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.favorites.tagsTitle, style: sectionLabel),
            if (tags.isEmpty)
              Text(t.favorites.tagsEmpty, style: theme.typography.body.copyWith(color: colors.textMuted))
            else
              for (final tag in tags)
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    Expanded(
                      child: DsCheckbox(
                        value: selected.contains(tag.id),
                        onChanged: (_) => unawaited(_toggle(tag.id)),
                        label: Text(tag.name),
                      ),
                    ),
                    DsButton.icon(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      semanticLabel: t.favorites.deleteTagTitle(name: tag.name),
                      onPressed: () => unawaited(_removeTag(tag)),
                      icon: const DsIcon(DsIcons.trash2, size: 16),
                    ),
                  ],
                ),
          ],
        ),
        // A new tag, beside the list: naming it adds it and joins the room
        // to it in one step.
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.favorites.newTag, style: sectionLabel),
            Row(
              spacing: DsSpace.s8,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DsTextField(
                    controller: _field,
                    clearable: true,
                    maxLength: kFollowTagNameMaxLength,
                    placeholder: t.favorites.tagFieldHint,
                    onSubmitted: (_) => unawaited(_add()),
                  ),
                ),
                DsButton(
                  variant: DsButtonVariant.tinted,
                  leading: const DsIcon(DsIcons.plus, size: 16),
                  onPressed: () => unawaited(_add()),
                  child: Text(t.favorites.addTag),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
