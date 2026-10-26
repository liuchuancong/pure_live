import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/favorites/favorites.dart';
import 'package:pure_live/features/settings/browse/live_alert_settings.dart' show liveAlertSettingsProvider;
import 'package:pure_live/l10n/translations.dart';

/// Opens the live-alert tag filter: every follow, or only the follows that
/// carry one of the ticked tags. No tick means every follow, which is also
/// what the refresh row shows.
Future<void> showLiveAlertTagsDialog(BuildContext context) =>
    showDsDialog<void>(context: context, builder: (context) => const _LiveAlertTagsDialog());

final class _LiveAlertTagsDialog extends ConsumerWidget {
  const _LiveAlertTagsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final tags = ref.watch(followTagsProvider);
    final chosen = ref.watch(liveAlertSettingsProvider).tagIds.toSet();
    final controller = ref.read(liveAlertSettingsProvider.notifier);
    return DsDialog(
      title: Text(t.settings.liveAlertTags),
      description: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s12,
            children: [
              Text(
                t.settings.liveAlertTagsDesc,
                style: theme.typography.small.copyWith(color: colors.textMuted),
              ),
              if (tags.isEmpty)
                Text(
                  t.settings.liveAlertTagsNone,
                  style: theme.typography.small.copyWith(color: colors.textSubtle),
                )
              else
                DsListSection(
                  children: [
                    for (final tag in tags)
                      DsListRow(
                        title: Text(tag.name),
                        description: tag.description.isEmpty ? null : Text(tag.description),
                        trailing: DsCheckbox(
                          value: chosen.contains(tag.id),
                          semanticLabel: tag.name,
                          onChanged: (value) => unawaited(
                            controller.setTags(
                              value == true
                                  ? [...chosen, tag.id]
                                  : [
                                      for (final id in chosen)
                                        if (id != tag.id) id,
                                    ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DsButton(
                  variant: DsButtonVariant.secondary,
                  size: DsSize.sm,
                  onPressed: chosen.isEmpty ? null : () => unawaited(controller.setTags(const [])),
                  child: Text(t.settings.liveAlertTagsAll),
                ),
              ),
            ],
          ),
        ),
      ),
      style: const DsDialogStyle(width: 520),
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
