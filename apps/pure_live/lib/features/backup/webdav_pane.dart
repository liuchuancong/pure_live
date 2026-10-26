import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/backup/backup_actions.dart';
import 'package:pure_live/features/backup/backup_document.dart';
import 'package:pure_live/features/backup/backup_repository.dart';
import 'package:pure_live/features/backup/webdav_browser.dart' show showWebDavBrowser;
import 'package:pure_live/features/backup/webdav_client.dart';
import 'package:pure_live/features/backup/webdav_settings.dart';
import 'package:pure_live/l10n/translations.dart';

/// The WebDAV transport's own subpage under Backup & restore: the server
/// editor, the connection test, the browser and the upload / download
/// actions. The local folder and its file list stay on the backup page;
/// this page owns only the sync side, so the fifteen local rows and the
/// seven remote ones no longer share one page.
final class WebDavSyncPane extends ConsumerStatefulWidget {
  /// The WebDAV sync page's content.
  const WebDavSyncPane({super.key});

  @override
  ConsumerState<WebDavSyncPane> createState() => _WebDavSyncPaneState();
}

/// The sync action running: the other rows grey out and the running row
/// spins until it settles.
enum _WebDavAction { test, upload, download }

final class _WebDavSyncPaneState extends ConsumerState<WebDavSyncPane> {
  _WebDavAction? _busy;

  void _toast(String message) => showDsToast(context: context, title: message);

  /// Runs one action at a time: the running row spins, the rest grey out,
  /// and every failure becomes the one message the page keeps for it.
  Future<void> _run(_WebDavAction action, Future<void> Function() work) async {
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
      if (mounted) _toast(t.backup.webdavFailed);
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
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

  /// One line on what a restore would change, shown in the confirm.
  /// A follows-only document only brings follows and areas.
  String _summaryLine(BackupDocument document) {
    final counts = document.counts;
    final t = context.t;
    if (document.followsOnly) {
      return t.backup.summaryFollows(follows: counts.follows, areas: counts.areas);
    }
    return t.backup.summary(
      follows: counts.follows,
      history: counts.history,
      areas: counts.areas,
      settings: counts.settings,
    );
  }

  Future<bool> _confirm(String title, {required String description}) => showDsConfirm(
    context: context,
    title: title,
    description: description,
    confirmLabel: context.t.common.confirm,
    cancelLabel: context.t.common.cancel,
    destructive: true,
  );

  // -- Actions --------------------------------------------------------------

  Future<void> _test() => _run(_WebDavAction.test, () async {
    final t = context.t;
    await testWebDav(ref);
    if (!mounted) return;
    _toast(t.backup.webdavTestOk);
  });

  Future<void> _upload() => _run(_WebDavAction.upload, () async {
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

  Future<void> _download() => _run(_WebDavAction.download, () async {
    final t = context.t;
    final document = await downloadBackupFromWebDav(ref);
    if (!mounted) return;
    if (document == null) {
      _toast(t.backup.importBadData);
      return;
    }
    final confirmed = await _confirm(
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
    final busy = _busy;
    bool free(_WebDavAction action) => busy == null || busy == action;
    Widget? spinner(_WebDavAction action) => busy == action ? const DsSpinner() : null;

    return DsListSection(
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
          leading: const DsIcon(DsIcons.folderOpen),
          title: Text(t.backup.webdavBrowse),
          description: Text(t.backup.webdavDescription(file: BackupDocument.backupFileName)),
          onPressed: settings.url.isEmpty ? null : () => unawaited(showWebDavBrowser(context)),
          showChevron: true,
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.plugZap),
          title: Text(t.backup.webdavTest),
          onPressed: free(_WebDavAction.test) ? () => unawaited(_test()) : null,
          trailing: spinner(_WebDavAction.test),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.cloudUpload),
          title: Text(t.backup.webdavUpload),
          onPressed: free(_WebDavAction.upload) ? () => unawaited(_upload()) : null,
          trailing: spinner(_WebDavAction.upload),
        ),
        DsListRow(
          leading: const DsIcon(DsIcons.cloudDownload),
          title: Text(t.backup.webdavDownload),
          onPressed: free(_WebDavAction.download) ? () => unawaited(_download()) : null,
          trailing: spinner(_WebDavAction.download),
        ),
      ],
    );
  }
}
