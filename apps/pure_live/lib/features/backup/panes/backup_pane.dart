import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/backup/cloud/cloud_controller.dart' show cloudControllerProvider;
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_repository.dart' show backupSummaryProvider;
import 'package:pure_live/features/backup/panes/backup_actions.dart';
import 'package:pure_live/features/backup/panes/backup_section_picker.dart' show backupSectionsSummary;
import 'package:pure_live/features/settings/surface/settings_child_entry.dart' show SettingsChildEntry;
import 'package:pure_live/features/settings/surface/settings_sections.dart';
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsConfigRow;
import 'package:pure_live/l10n/translations.dart';

/// The backup hub: what this device holds, the four ways to back it up or
/// sync it — a local file, the cloud, a WebDAV server, the devices on this
/// network — each its own page, the help and the account management beside
/// them, and the one choice every way honours: whether the vault's secrets
/// may travel at all.
///
/// Public for the settings surface to embed; the page owns only the
/// secrets switch's state.
final class BackupPane extends ConsumerStatefulWidget {
  /// The backup hub.
  const BackupPane({super.key});

  @override
  ConsumerState<BackupPane> createState() => _BackupPaneState();
}

final class _BackupPaneState extends ConsumerState<BackupPane> {
  bool _includeSecrets = includeSecretsAllowed();

  Future<void> _setIncludeSecrets({required bool allowed}) async {
    setState(() => _includeSecrets = allowed);
    await storeIncludeSecrets(allowed: allowed);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final summary = ref.watch(backupSummaryProvider).value;
    final manages = ref.watch(cloudControllerProvider.select((s) => s.permissions.hasManagementPower));
    // The summary names the sections the user may back up; the secrets
    // count joins only once the switch allows them at all.
    final shown = summary == null
        ? null
        : {
            for (final entry in summary.entries)
              if (entry.key != BackupSection.secrets || _includeSecrets) entry.key: entry.value,
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.backup.summaryTitle),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.database),
              title: Text(t.backup.summaryTitle),
              description: Text(shown == null ? t.backup.summaryEmpty : backupSectionsSummary(t, shown)),
            ),
          ],
        ),
        // The ways, one row each; every one opens its own page.
        DsListSection(
          header: Text(t.backup.methodsSection),
          children: const [
            SettingsChildEntry(child: SettingsSection.localBackup),
            SettingsChildEntry(child: SettingsSection.cloudBackup),
            SettingsChildEntry(child: SettingsSection.webdavSync),
            SettingsChildEntry(child: SettingsSection.lanSync),
          ],
        ),
        DsListSection(
          header: Text(t.backup.moreSection),
          children: [
            const SettingsChildEntry(child: SettingsSection.webdavHelp),
            // The accounts page only for an account that may manage others;
            // the cloud page lists it too once signed in.
            if (manages) const SettingsChildEntry(child: SettingsSection.cloudAdmin),
          ],
        ),
        // The secrets are the user's call, made once here and honoured by
        // every way: off, and no picker even offers them.
        DsListSection(
          header: Text(t.backup.secretsSection),
          children: [
            SettingsConfigRow(
              leading: const DsIcon(DsIcons.keyRound),
              title: t.backup.secretsSwitchTitle,
              description: t.backup.secretsSwitchDescription,
              control: DsSwitch(
                value: _includeSecrets,
                onChanged: (value) => unawaited(_setIncludeSecrets(allowed: value)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
