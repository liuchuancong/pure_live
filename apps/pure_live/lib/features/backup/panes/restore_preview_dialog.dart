import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_repository.dart';
import 'package:pure_live/features/backup/document/restore_preview.dart';
import 'package:pure_live/features/backup/panes/backup_actions.dart' show includeSecretsAllowed;
import 'package:pure_live/features/backup/panes/backup_section_picker.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/widgets/app_dialog.dart';

/// Whether a restore is running on this device right now. Every restore
/// entry asks before it reads or downloads anything, so a second restore is
/// turned away at once rather than after the user picked and confirmed it.
bool restoreInProgress(WidgetRef ref) => ref.read(backupRestoreLockProvider).busy;

/// The steps every restore takes once it holds a decoded backup, wherever
/// the backup came from: which of its sections to take, then what taking
/// them changes on this device. Answers [document] narrowed to the chosen
/// sections once the user agreed, or null when they backed out of either.
///
/// [name] is what the preview calls the backup (a file's name, the cloud);
/// [title] heads the picker and [note] replaces its default note.
Future<BackupDocument?> pickAndPreviewRestore(
  BuildContext context,
  WidgetRef ref, {
  required BackupDocument document,
  required String name,
  required String title,
  String? note,
}) async {
  final t = context.t;
  final sections = await showBackupSectionPicker(
    context,
    title: title,
    confirmLabel: t.backup.webdavRestore,
    available: document.presentSections,
    initial: document.presentSections,
    counts: {for (final section in document.presentSections) section: document.countOf(section)},
    secretsAllowed: includeSecretsAllowed(),
    note: note ?? t.backup.pickRestoreNote,
  );
  if (sections == null || !context.mounted) return null;
  final chosen = document.only(sections);
  final repository = await ref.read(backupRepositoryProvider.future);
  if (!context.mounted) return null;
  // Whether the file is follows-only is the file's, not the narrowed
  // document's, to say.
  final preview = repository.preview(chosen, followsOnlyFile: document.restoresFollowsOnly);
  final confirmed = await showRestorePreview(context, name: name, preview: preview);
  return confirmed ? chosen : null;
}

/// Shows what restoring [name] changes on this device ([preview]) and asks
/// to go on; true to restore. The safe choice comes first and holds the
/// focus, so a remote's OK never restores by accident; Escape, a tap on
/// the scrim and back all answer no.
Future<bool> showRestorePreview(BuildContext context, {required String name, required RestorePreview preview}) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (context) => _RestorePreviewDialog(name: name, preview: preview),
    ) ??
    false;

/// The restore's confirm: the backup by name, one line per section it
/// writes — the entries now and after, what it adds and removes — then what
/// stays, what could not be read, and that it cannot be undone.
final class _RestorePreviewDialog extends StatelessWidget {
  const new({required this.name, required this.preview});

  final String name;
  final RestorePreview preview;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final p = t.backup.preview;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final quiet = theme.typography.caption.copyWith(color: colors.textMuted);
    final parts = {for (final part in preview.parts) part.section: part};
    return AppDialog(
      alert: true,
      title: Text(t.backup.restoreConfirmTitle),
      style: const DsDialogStyle(width: 440),
      description: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s4,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.bodyStrong.copyWith(color: colors.text),
              ),
              if (preview.followsOnlyFile)
                Text(p.followsOnlyFile, style: theme.typography.caption.copyWith(color: colors.accentText)),
            ],
          ),
          Text(p.changes, style: theme.typography.labelStrong.copyWith(color: colors.text)),
          // One line per section the restore writes, in the picker's order.
          for (final section in BackupSection.values)
            if (parts[section] case final part?)
              _ChangeRow(
                icon: backupSectionIcon(section),
                label: backupSectionLabel(t, section),
                figures: p.figures(current: part.current, incoming: part.incoming),
                detail: _movement(context, part),
              )
            else if (section == BackupSection.settings && preview.settingsInFile > 0)
              _ChangeRow(
                icon: backupSectionIcon(section),
                label: backupSectionLabel(t, section),
                figures: p.items(count: preview.settingsInFile),
                detail: preview.settingsChanged > 0
                    ? Text(
                        p.settingsChanged(count: preview.settingsChanged),
                        style: TextStyle(color: colors.text),
                      )
                    : Text(p.settingsSame),
              )
            else if (section == BackupSection.secrets && preview.accounts > 0)
              _ChangeRow(
                icon: backupSectionIcon(section),
                label: backupSectionLabel(t, section),
                figures: p.items(count: preview.accounts),
                detail: Text(p.accounts),
              ),
          if (preview.kept.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s8,
              children: [
                DsIcon(DsIcons.circleCheck, size: theme.sizes.iconXs, color: colors.textSubtle),
                Expanded(
                  child: Text(
                    p.kept(
                      sections: [for (final section in preview.kept) backupSectionLabel(t, section)].join(p.separator),
                    ),
                    style: quiet,
                  ),
                ),
              ],
            ),
          if (preview.skipped > 0)
            DsAlert(
              status: DsStatus.warning,
              title: Text(p.skipped(count: preview.skipped)),
            ),
          if (!preview.changesSomething) Text(p.nothing, style: quiet),
          Text(p.warning, style: quiet),
        ],
      ),
      actions: [
        DsButton(
          variant: DsButtonVariant.secondary,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.common.cancel),
        ),
        DsButton(
          variant: DsButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(p.confirm),
        ),
      ],
    );
  }

  /// "新增 4 · 移除 1": the additions in the success ink and the removals —
  /// the data this device loses — in the danger ink, each said in words
  /// as well; a side with nothing to say is left out.
  Widget _movement(BuildContext context, RestorePart part) {
    final p = context.t.backup.preview;
    final colors = DsTheme.colorsOf(context);
    final moves = <InlineSpan>[
      if (part.added > 0)
        TextSpan(
          text: p.added(count: part.added),
          style: TextStyle(color: colors.success.text),
        ),
      if (part.added > 0 && part.removed > 0) const TextSpan(text: ' · '),
      if (part.removed > 0)
        TextSpan(
          text: p.removed(count: part.removed),
          style: TextStyle(color: colors.danger.text),
        ),
    ];
    return moves.isEmpty ? Text(p.same) : Text.rich(TextSpan(children: moves));
  }
}

/// One line of the preview: the section's icon and name with its entries
/// now → after at the far end, and under the name what moves.
final class _ChangeRow extends StatelessWidget {
  const new({required this.icon, required this.label, required this.figures, required this.detail});

  final DsIconData icon;
  final String label;
  final String figures;
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final body = theme.typography.body;
    final iconSize = theme.sizes.iconSm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s4,
      children: [
        Row(
          spacing: DsSpace.s12,
          children: [
            DsIcon(icon, size: iconSize, color: colors.textMuted),
            Expanded(
              child: Text(label, style: body.copyWith(color: colors.text)),
            ),
            Text(figures, style: theme.typography.numeric(body).copyWith(color: colors.textMuted)),
          ],
        ),
        // Under the name, clear of the icon column.
        Padding(
          padding: EdgeInsetsDirectional.only(start: iconSize + DsSpace.s12),
          child: DefaultTextStyle.merge(
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
            child: detail,
          ),
        ),
      ],
    );
  }
}
