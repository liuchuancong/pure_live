import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';

import 'package:pure_live/features/favorites/follow_repository.dart' show followsProvider;
import 'package:pure_live/features/favorites/follow_tags.dart';
import 'package:pure_live/l10n/translations.dart';

/// Opens the tags of one followed [room]: the tags it belongs to, a tap to
/// join or leave one, an inline field for a new tag, and a remove action per
/// tag that also strips it from every follow. Everything writes through the
/// follows store at once, so the page behind the panel is already right
/// when it closes.
Future<void> showFollowTagPicker(BuildContext context, LiveRoom room) => showDsPanel<void>(
  context: context,
  builder: (context) => DsPanel(
    title: Text(context.t.favorites.setTags),
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
    final tags = ref.watch(followTagsProvider);
    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        if (tags.isEmpty)
          DsEmptyState(icon: const DsIcon(DsIcons.tag), title: Text(t.favorites.tagsEmpty))
        else
          DsListSection(
            header: Text(t.favorites.tagsTitle),
            children: [
              for (final tag in tags)
                DsListRow(
                  leading: DsIcon(selected.contains(tag.id) ? DsIcons.circleCheck : DsIcons.circle),
                  title: Text(tag.name),
                  selected: selected.contains(tag.id),
                  onPressed: () => unawaited(_toggle(tag.id)),
                  trailing: DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: t.favorites.deleteTagTitle(name: tag.name),
                    onPressed: () => unawaited(_removeTag(tag)),
                    icon: const DsIcon(DsIcons.trash2, size: 16),
                  ),
                ),
            ],
          ),
        Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: DsTextField(
                controller: _field,
                clearable: true,
                placeholder: t.favorites.tagFieldHint,
                onSubmitted: (_) => unawaited(_add()),
              ),
            ),
            DsButton(onPressed: () => unawaited(_add()), child: Text(t.favorites.addTag)),
          ],
        ),
      ],
    );
  }
}
