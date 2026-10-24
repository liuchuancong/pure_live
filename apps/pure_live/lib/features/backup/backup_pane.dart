import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/backup/backup_actions.dart';
import 'package:pure_live/features/backup/backup_document.dart';
import 'package:pure_live/features/backup/backup_repository.dart';
import 'package:pure_live/features/backup/webdav_client.dart';
import 'package:pure_live/features/backup/webdav_settings.dart';
import 'package:pure_live/l10n/translations.dart';

/// The one action running: the other rows grey out and the running row
/// spins until it settles.
enum _BackupAction { exportDoc, importDoc, webdavTest, webdavUpload, webdavDownload }

/// The backup and restore pane: one JSON document bundles the followed
/// rooms, the watch history, the followed areas and the settings subset.
/// The pane exports it through the system share panel, imports a pasted
/// one behind a confirm, and syncs the same document over WebDAV — test
/// the server, upload the backup, download and restore it.
///
/// Public for the settings surface to embed; the pane owns nothing beyond
/// its own busy state. Direct local file picking waits for the file
/// picker dependency, and the pane says so.
final class BackupPane extends ConsumerStatefulWidget {
  /// The backup pane.
  const BackupPane({super.key});

  @override
  ConsumerState<BackupPane> createState() => _BackupPaneState();
}

final class _BackupPaneState extends ConsumerState<BackupPane> {
  _BackupAction? _busy;

  void _toast(String message) => showDsToast(context: context, title: message);

  /// Runs one action at a time: the running row spins, the rest grey out,
  /// and every failure becomes the one message the pane keeps for it.
  Future<void> _run(_BackupAction action, Future<void> Function() work) async {
    final t = context.t;
    if (_busy != null) {
      _toast(t.backup.busy);
      return;
    }
    setState(() => _busy = action);
    try {
      await work();
    } on WebDavFailure catch (failure) {
      if (mounted) _toast(_webDavMessage(failure));
    } on Object {
      if (mounted) _toast(_failureMessage(action));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  String _webDavMessage(WebDavFailure failure) {
    final t = context.t;
    return switch (failure.problem) {
      WebDavProblem.auth => t.backup.webdavAuthFailed,
      WebDavProblem.notFound => t.backup.webdavNotFound,
      WebDavProblem.server => t.backup.webdavServerFailed(status: failure.status ?? 0),
      WebDavProblem.network => t.backup.webdavNetworkFailed,
    };
  }

  String _failureMessage(_BackupAction action) {
    final t = context.t;
    return switch (action) {
      _BackupAction.exportDoc => t.backup.exportFailed,
      _BackupAction.importDoc => t.backup.importFailed,
      _BackupAction.webdavTest ||
      _BackupAction.webdavUpload ||
      _BackupAction.webdavDownload => t.backup.webdavFailed,
    };
  }

  // -- Local backup -------------------------------------------------------

  Future<void> _export() => _run(_BackupAction.exportDoc, () async {
    final t = context.t;
    final exported = await exportBackup(ref);
    if (!mounted) return;
    _toast(exported ? t.backup.exportDone : t.backup.exportEmpty);
  });

  Future<void> _import() => _run(_BackupAction.importDoc, () async {
    final t = context.t;
    final raw = await _askPastedJson();
    if (raw == null || raw.trim().isEmpty) return;
    final document = BackupDocument.tryDecode(raw);
    if (document == null) {
      _toast(t.backup.importBadData);
      return;
    }
    final confirmed = await _confirmOverwrite(
      t.backup.importConfirmTitle,
      description: '${t.backup.importConfirmDesc}\n${_summaryLine(document)}',
    );
    if (!confirmed) return;
    await applyBackup(ref, document);
    ref.invalidate(backupSummaryProvider);
    if (mounted) _toast(t.backup.importDone);
  });

  // -- WebDAV sync --------------------------------------------------------

  Future<void> _test() => _run(_BackupAction.webdavTest, () async {
    final t = context.t;
    await testWebDav(ref);
    if (!mounted) return;
    _toast(t.backup.webdavTestOk);
  });

  Future<void> _upload() => _run(_BackupAction.webdavUpload, () async {
    final t = context.t;
    final document = await captureBackupDocument(ref);
    if (document.isEmpty) {
      _toast(t.backup.exportEmpty);
      return;
    }
    await uploadBackupToWebDav(ref);
    if (!mounted) return;
    _toast(t.backup.webdavUploadDone(file: BackupDocument.backupFileName));
  });

  Future<void> _download() => _run(_BackupAction.webdavDownload, () async {
    final t = context.t;
    final document = await downloadBackupFromWebDav(ref);
    if (document == null) {
      _toast(t.backup.importBadData);
      return;
    }
    final confirmed = await _confirmOverwrite(
      t.backup.webdavDownloadConfirmTitle,
      description:
          '${t.backup.webdavDownloadConfirmDesc(file: BackupDocument.backupFileName)}'
          '\n${_summaryLine(document)}',
    );
    if (!confirmed) return;
    await applyBackup(ref, document);
    ref.invalidate(backupSummaryProvider);
    if (mounted) _toast(t.backup.importDone);
  });

  // -- Dialogs ------------------------------------------------------------

  /// The one line on what an import would change, shown in the confirms.
  String _summaryLine(BackupDocument document) {
    final counts = document.counts;
    final t = context.t;
    return t.backup.summary(
      follows: counts.follows,
      history: counts.history,
      areas: counts.areas,
      settings: counts.settings,
    );
  }

  Future<bool> _confirmOverwrite(String title, {required String description}) => showDsConfirm(
    context: context,
    title: title,
    description: description,
    confirmLabel: context.t.common.confirm,
    cancelLabel: context.t.common.cancel,
    destructive: true,
  );

  /// Asks for the pasted backup JSON; answers the text, or null when the
  /// dialog was dismissed.
  Future<String?> _askPastedJson() async {
    final t = context.t;
    final field = TextEditingController();
    await showDsDialog<void>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(t.backup.importTitle),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.backup.importDescription),
            DsTextField.multiline(
              controller: field,
              autofocus: true,
              minLines: 6,
              maxLines: 12,
              placeholder: t.backup.importHint,
              semanticLabel: t.backup.importHint,
            ),
          ],
        ),
        actions: [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          DsButton(onPressed: () => Navigator.of(context).pop(field.text), child: Text(t.common.confirm)),
        ],
      ),
    );
    final text = field.text;
    field.dispose();
    return text;
  }

  /// Edits the WebDAV connection: server URL, username and password. An
  /// empty password field keeps the stored one when there is one; typing
  /// a new one replaces it in the vault.
  Future<void> _editWebDav() async {
    final t = context.t;
    final settings = ref.read(webdavSettingsProvider);
    final urlField = TextEditingController(text: settings.url);
    final userField = TextEditingController(text: settings.user);
    final passwordField = TextEditingController();
    await showDsDialog<void>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(t.backup.webdavConfigTitle),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.backup.webdavConfigDescription),
            DsTextField(
              controller: urlField,
              autofocus: true,
              clearable: true,
              placeholder: t.backup.webdavUrlHint,
              semanticLabel: t.backup.webdavUrl,
            ),
            DsTextField(
              controller: userField,
              clearable: true,
              placeholder: t.backup.webdavUserHint,
              semanticLabel: t.backup.webdavUser,
            ),
            DsTextField(
              controller: passwordField,
              obscureText: true,
              revealable: true,
              placeholder: settings.hasPassword ? t.backup.webdavPasswordKeep : t.backup.webdavPasswordHint,
              semanticLabel: t.backup.webdavPassword,
            ),
          ],
        ),
        actions: [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          DsButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref
                  .read(webdavSettingsProvider.notifier)
                  .save(
                    url: urlField.text,
                    user: userField.text,
                    // Empty keeps the stored password when there is one,
                    // and clears it when there is none to keep.
                    password: passwordField.text.isEmpty ? (settings.hasPassword ? null : '') : passwordField.text,
                  );
              if (mounted) _toast(t.backup.webdavSaved);
            },
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
    urlField.dispose();
    userField.dispose();
    passwordField.dispose();
  }

  // -- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final settings = ref.watch(webdavSettingsProvider);
    final summary = ref.watch(backupSummaryProvider).value;
    final busy = _busy;
    bool free(_BackupAction action) => busy == null || busy == action;
    Widget? spinner(_BackupAction action) => busy == action ? const DsSpinner() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          header: Text(t.backup.localSection),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.database),
              title: Text(t.backup.summaryTitle),
              detail: Text(
                summary == null
                    ? t.backup.summaryEmpty
                    : t.backup.summary(
                        follows: summary.follows,
                        history: summary.history,
                        areas: summary.areas,
                        settings: summary.settings,
                      ),
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.upload),
              title: Text(t.backup.exportTitle),
              description: Text(t.backup.exportDescription),
              onPressed: free(_BackupAction.exportDoc) ? () => unawaited(_export()) : null,
              trailing: spinner(_BackupAction.exportDoc),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.download),
              title: Text(t.backup.importTitle),
              description: Text(t.backup.importDescription),
              onPressed: free(_BackupAction.importDoc) ? () => unawaited(_import()) : null,
              trailing: spinner(_BackupAction.importDoc),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
              child: Text(
                t.backup.importFileNote,
                style: theme.typography.caption.copyWith(color: colors.textSubtle),
              ),
            ),
          ],
        ),
        DsListSection(
          header: Text(t.backup.webdavSection),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s8),
              child: Text(
                t.backup.webdavDescription(file: BackupDocument.backupFileName),
                style: theme.typography.caption.copyWith(color: colors.textSubtle),
              ),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.server),
              title: Text(t.backup.webdavConfigTitle),
              description: Text(t.backup.webdavConfigDescription),
              detail: Text(settings.url.isEmpty ? t.backup.webdavUrlMissing : settings.url),
              onPressed: () => unawaited(_editWebDav()),
              showChevron: true,
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.keyRound),
              title: Text(t.backup.webdavPassword),
              detail: Text(settings.hasPassword ? t.backup.webdavPasswordKeep : t.backup.webdavPasswordEmpty),
              onPressed: () => unawaited(_editWebDav()),
              showChevron: true,
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.plugZap),
              title: Text(t.backup.webdavTest),
              onPressed: free(_BackupAction.webdavTest) ? () => unawaited(_test()) : null,
              trailing: spinner(_BackupAction.webdavTest),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.cloudUpload),
              title: Text(t.backup.webdavUpload),
              onPressed: free(_BackupAction.webdavUpload) ? () => unawaited(_upload()) : null,
              trailing: spinner(_BackupAction.webdavUpload),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.cloudDownload),
              title: Text(t.backup.webdavDownload),
              onPressed: free(_BackupAction.webdavDownload) ? () => unawaited(_download()) : null,
              trailing: spinner(_BackupAction.webdavDownload),
            ),
          ],
        ),
      ],
    );
  }
}
