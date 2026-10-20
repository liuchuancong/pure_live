import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The tag manager (the reference's `TagsPage`, 3.x `SettingTagsPage`):
/// create, rename, pin and delete the follow groups, in one column capped at
/// a readable width.
///
/// Tags are the follow library's groups — the same store the follow page's
/// group sheet edits; this is the whole list where the sheet is the quick
/// editor. Pin-to-top is the reference's own gesture: it reorders the group
/// to the head of the position order the follow page lists by.
final class TagsPage extends ConsumerStatefulWidget {
  /// The tag manager page.
  const new({super.key});

  @override
  ConsumerState<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends ConsumerState<TagsPage> {
  StreamSubscription<void>? _changes;

  @override
  void initState() {
    super.initState();
    _changes = ref.read(followRepositoryProvider).changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final groups = ref.watch(followRepositoryProvider).groups;

    return PureScaffold(
      appBar: PureAppBar(
        title: t.tags.title,
        actions: [PureIconButton(icon: Icons.add_rounded, tooltip: t.tags.add, onPressed: () => unawaited(_create()))],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: groups.isEmpty
              ? PureEmpty(
                  icon: Icons.sell_outlined,
                  title: t.tags.empty,
                  message: t.tags.emptyHint,
                  action: PureButton(label: t.tags.add, onPressed: () => unawaited(_create())),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        t.tags.countValue(count: groups.length),
                        style: theme.text.caption.copyWith(color: theme.colors.textTertiary),
                      ),
                    ),
                    for (final (index, group) in groups.indexed)
                      PureListRow(
                        leading: const Icon(Icons.sell_outlined),
                        title: group.name,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (index > 0)
                              PureIconButton(
                                tooltip: t.tags.pin,
                                icon: Icons.vertical_align_top_outlined,
                                onPressed: () =>
                                    unawaited(ref.read(followRepositoryProvider).reorderGroup(group.id, 0)),
                              ),
                            PureIconButton(
                              tooltip: t.tags.rename,
                              icon: Icons.edit_outlined,
                              onPressed: () => unawaited(_rename(group.id, group.name)),
                            ),
                            PureIconButton(
                              tooltip: t.tags.delete,
                              icon: Icons.delete_outline_rounded,
                              onPressed: () => unawaited(_delete(group.id, group.name)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    final name = await _askName(initial: '');
    if (name != null && name.isNotEmpty) {
      await ref.read(followRepositoryProvider).createGroup(name);
    }
  }

  Future<void> _rename(String id, String current) async {
    final name = await _askName(initial: current);
    if (name != null && name.isNotEmpty && name != current) {
      await ref.read(followRepositoryProvider).renameGroup(id, name);
    }
  }

  Future<String?> _askName({required String initial}) {
    final field = TextEditingController(text: initial);
    return showPureDialog<String>(
      context: context,
      title: context.t.tags.name,
      child: Builder(
        builder: (dialogContext) => Focus(
          autofocus: true,
          child: PureTextField(
            controller: field,
            placeholder: context.t.tags.name,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
          ),
        ),
      ),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        PureButton(
          label: dialogContext.t.common.confirm,
          onPressed: () => Navigator.of(dialogContext).pop(field.text.trim()),
        ),
      ],
    ).whenComplete(field.dispose);
  }

  Future<void> _delete(String id, String name) async {
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: context.t.tags.delete,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(context.t.tags.deleteConfirm(name: name)),
      ),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(label: dialogContext.t.common.confirm, onPressed: () => Navigator.of(dialogContext).pop(true)),
      ],
    );
    if (confirmed == true) {
      await ref.read(followRepositoryProvider).deleteGroup(id);
    }
  }
}
