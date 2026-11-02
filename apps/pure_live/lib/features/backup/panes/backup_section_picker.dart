import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/l10n/translations.dart';

/// Asks which sections a backup, an upload, a restore or a sync should
/// carry: one check per section with how many entries it holds, select all
/// and clear beside the list, and the closing action in the footer.
///
/// [available] lists what may be offered at all — a restore offers only the
/// sections the file carries, a capture offers every section. The secrets
/// row appears only when [secretsAllowed] (the user's `backup.includeSecrets`
/// switch) and the section is available; it is never on by default.
/// Answers the chosen set, or null when the user backed out.
///
/// The panel is the kit's own sheet: a dialog on a wide window, a bottom
/// sheet on a narrow one, a focusable list on a TV.
Future<Set<BackupSection>?> showBackupSectionPicker(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required Set<BackupSection> available,
  Set<BackupSection>? initial,
  Map<BackupSection, int> counts = const {},
  bool secretsAllowed = false,
  String? note,
}) {
  final offered = [
    for (final section in BackupSection.values)
      if (available.contains(section) && (section != BackupSection.secrets || secretsAllowed)) section,
  ];
  final start = {
    for (final section in initial ?? BackupSection.all)
      if (offered.contains(section)) section,
  };
  return showDsPanel<Set<BackupSection>>(
    context: context,
    builder: (context) => _SectionPicker(
      title: title,
      confirmLabel: confirmLabel,
      offered: offered,
      initial: start,
      counts: counts,
      note: note,
    ),
  );
}

/// The section's name as the picker and the summaries show it.
String backupSectionLabel(Translations t, BackupSection section) => switch (section) {
  BackupSection.follows => t.backup.sectionFollows,
  BackupSection.areaFollows => t.backup.sectionAreaFollows,
  BackupSection.history => t.backup.sectionHistory,
  BackupSection.recordings => t.backup.sectionRecordings,
  BackupSection.settings => t.backup.sectionSettings,
  BackupSection.secrets => t.backup.sectionSecrets,
};

/// The section's one-line description under its name.
String backupSectionDescription(Translations t, BackupSection section) => switch (section) {
  BackupSection.follows => t.backup.sectionFollowsDesc,
  BackupSection.areaFollows => t.backup.sectionAreaFollowsDesc,
  BackupSection.history => t.backup.sectionHistoryDesc,
  BackupSection.recordings => t.backup.sectionRecordingsDesc,
  BackupSection.settings => t.backup.sectionSettingsDesc,
  BackupSection.secrets => t.backup.sectionSecretsDesc,
};

/// The section's icon.
DsIconData backupSectionIcon(BackupSection section) => switch (section) {
  BackupSection.follows => DsIcons.heart,
  BackupSection.areaFollows => DsIcons.layoutGrid,
  BackupSection.history => DsIcons.history,
  BackupSection.recordings => DsIcons.video,
  BackupSection.settings => DsIcons.settings,
  BackupSection.secrets => DsIcons.keyRound,
};

/// "关注 12 · 历史 30 · …" for the sections in [counts], in wire order.
String backupSectionsSummary(Translations t, Map<BackupSection, int> counts) => [
  for (final section in BackupSection.values)
    if (counts.containsKey(section))
      t.backup.sectionCount(name: backupSectionLabel(t, section), count: counts[section]!),
].join(' · ');

final class _SectionPicker extends StatefulWidget {
  const _SectionPicker({
    required this.title,
    required this.confirmLabel,
    required this.offered,
    required this.initial,
    required this.counts,
    required this.note,
  });

  final String title;
  final String confirmLabel;
  final List<BackupSection> offered;
  final Set<BackupSection> initial;
  final Map<BackupSection, int> counts;
  final String? note;

  @override
  State<_SectionPicker> createState() => _SectionPickerState();
}

final class _SectionPickerState extends State<_SectionPicker> {
  late Set<BackupSection> _selected = {...widget.initial};

  void _toggle(BackupSection section) => setState(() {
    if (!_selected.remove(section)) _selected.add(section);
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final muted = theme.typography.caption.copyWith(color: colors.textMuted);
    final note = widget.note;
    return DsPanel(
      title: Text(widget.title),
      footer: DsButton(
        onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected),
        child: Text(widget.confirmLabel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s12,
        children: [
          if (note != null) Text(note, style: theme.typography.body.copyWith(color: colors.textMuted)),
          // The two shortcuts sit above the list: every row on, or none.
          Row(
            spacing: DsSpace.s8,
            children: [
              DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                onPressed: () => setState(() => _selected = {...widget.offered}),
                child: Text(t.backup.pickAll),
              ),
              DsButton(
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                onPressed: _selected.isEmpty ? null : () => setState(() => _selected = {}),
                child: Text(t.backup.pickNone),
              ),
            ],
          ),
          for (final section in widget.offered)
            Row(
              spacing: DsSpace.s8,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DsCheckbox(
                    value: _selected.contains(section),
                    onChanged: (_) => _toggle(section),
                    label: Text(backupSectionLabel(t, section)),
                    description: Text(
                      backupSectionDescription(t, section),
                      style: section == BackupSection.secrets ? muted.copyWith(color: colors.danger.text) : muted,
                    ),
                  ),
                ),
                if (widget.counts.containsKey(section))
                  Padding(
                    padding: const EdgeInsets.only(top: DsSpace.s4),
                    child: Text(t.backup.pickCount(count: widget.counts[section]!), style: muted),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
