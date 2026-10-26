import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/features/settings/room/local_interaction_settings.dart';
import 'package:pure_live/l10n/translations.dart';

/// Opens the quick-phrase manager: the saved phrases in their order, with
/// add, edit, move and delete, capped and de-duplicated as the local
/// composer counts them.
Future<void> showLocalPhrasesDialog(BuildContext context) =>
    showDsDialog<void>(context: context, builder: (context) => const _LocalPhrasesDialog());

final class _LocalPhrasesDialog extends ConsumerStatefulWidget {
  const _LocalPhrasesDialog();

  @override
  ConsumerState<_LocalPhrasesDialog> createState() => _LocalPhrasesDialogState();
}

final class _LocalPhrasesDialogState extends ConsumerState<_LocalPhrasesDialog> {
  final TextEditingController _input = TextEditingController();
  int? _editing;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String _problemText(LocalPhraseProblem problem) => switch (problem) {
    LocalPhraseProblem.empty => context.t.settings.localPhraseEmptyError,
    LocalPhraseProblem.duplicate => context.t.settings.localPhraseDuplicate,
    LocalPhraseProblem.full => context.t.settings.localPhraseFull(count: kLocalPhraseLimit),
  };

  Future<void> _save() async {
    final controller = ref.read(localInteractionProvider.notifier);
    final editing = _editing;
    final problem = controller.phraseProblem(_input.text, replacing: editing);
    if (problem != null) {
      setState(() => _error = _problemText(problem));
      return;
    }
    final ok = editing == null
        ? await controller.addPhrase(_input.text)
        : await controller.editPhrase(editing, _input.text);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = context.t.settings.localPhraseDuplicate);
      return;
    }
    _input.clear();
    setState(() {
      _editing = null;
      _error = null;
    });
  }

  void _edit(int index, String phrase) {
    setState(() {
      _editing = index;
      _error = null;
    });
    _input.text = phrase;
    _input.selection = TextSelection.collapsed(offset: phrase.length);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final local = ref.watch(localInteractionProvider);
    final controller = ref.read(localInteractionProvider.notifier);
    final phrases = local.phrases;
    final full = phrases.length >= kLocalPhraseLimit;
    return DsDialog(
      title: Text(t.settings.localPhrases),
      description: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 430),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s12,
            children: [
              Text(
                t.settings.localPhrasesDesc,
                style: theme.typography.small.copyWith(color: colors.textMuted),
              ),
              if (phrases.isEmpty)
                Text(
                  t.settings.localPhrasesEmpty(limit: kLocalPhraseLimit),
                  style: theme.typography.small.copyWith(color: colors.textSubtle),
                )
              else
                DsListSection(
                  children: [
                    for (final (index, phrase) in phrases.indexed)
                      DsListRow(
                        title: Text(phrase),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: DsSpace.s3,
                          children: [
                            DsButton.icon(
                              variant: DsButtonVariant.ghost,
                              size: DsSize.sm,
                              onPressed: index == 0 ? null : () => unawaited(controller.movePhrase(index, index - 1)),
                              semanticLabel: t.settings.localPhraseMoveUp,
                              icon: const DsIcon(DsIcons.arrowUp, size: 14),
                            ),
                            DsButton.icon(
                              variant: DsButtonVariant.ghost,
                              size: DsSize.sm,
                              onPressed: index == phrases.length - 1
                                  ? null
                                  : () => unawaited(controller.movePhrase(index, index + 1)),
                              semanticLabel: t.settings.localPhraseMoveDown,
                              icon: const DsIcon(DsIcons.arrowDown, size: 14),
                            ),
                            DsButton.icon(
                              variant: DsButtonVariant.ghost,
                              size: DsSize.sm,
                              onPressed: () => _edit(index, phrase),
                              semanticLabel: t.settings.localPhraseEdit,
                              icon: const DsIcon(DsIcons.pencil, size: 14),
                            ),
                            DsButton.icon(
                              variant: DsButtonVariant.ghost,
                              size: DsSize.sm,
                              onPressed: () {
                                if (_editing == index) {
                                  _editing = null;
                                  _input.clear();
                                }
                                unawaited(controller.removePhrase(index));
                              },
                              semanticLabel: t.settings.localPhraseDelete,
                              icon: const DsIcon(DsIcons.trash2, size: 14),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s8,
                children: [
                  Expanded(
                    child: DsTextField(
                      controller: _input,
                      maxLength: kLocalPhraseLength,
                      placeholder: t.settings.localPhraseHint(limit: kLocalPhraseLength),
                      semanticLabel: t.settings.localPhraseHint(limit: kLocalPhraseLength),
                      error: _error != null,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => unawaited(_save()),
                    ),
                  ),
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    onPressed: full && _editing == null ? null : () => unawaited(_save()),
                    child: Text(_editing == null ? t.settings.localPhraseAdd : t.common.save),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _error ?? t.settings.localPhraseCount(count: phrases.length, limit: kLocalPhraseLimit),
                      style: theme.typography.small.copyWith(
                        color: _error != null ? colors.danger.text : colors.textMuted,
                      ),
                    ),
                  ),
                  if (_editing != null)
                    DsButton(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      onPressed: () {
                        _input.clear();
                        setState(() {
                          _editing = null;
                          _error = null;
                        });
                      },
                      child: Text(t.common.cancel),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      style: const DsDialogStyle(width: 560),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.close),
        ),
      ],
    );
  }
}
