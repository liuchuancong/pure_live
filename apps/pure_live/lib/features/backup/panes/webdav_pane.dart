import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_repository.dart';
import 'package:pure_live/features/backup/panes/backup_actions.dart';
import 'package:pure_live/features/backup/webdav/webdav_accounts.dart';
import 'package:pure_live/features/backup/webdav/webdav_browser_page.dart' show showWebDavFolders;
import 'package:pure_live/features/backup/webdav/webdav_client.dart';
import 'package:pure_live/features/backup/webdav/webdav_settings.dart' show webDavVault;
import 'package:pure_live/l10n/translations.dart';

/// The WebDAV page under Backup & restore: the saved accounts and the three
/// sync actions that run against the current one.
///
/// More than one server is the ordinary case — a cloud drive, a home NAS, a
/// work share — so the accounts are the page's subject and the address bar
/// that adds one sits at its top right, the way a file manager's new-folder
/// button does. Opening an account selects it and walks its folders.
final class WebDavSyncPane extends ConsumerStatefulWidget {
  /// The WebDAV page's content.
  const WebDavSyncPane({super.key});

  @override
  ConsumerState<WebDavSyncPane> createState() => _WebDavSyncPaneState();
}

/// The sync action running: the other rows grey out and the running row
/// spins until it settles.
enum _WebDavAction { test, upload, download }

final class _WebDavSyncPaneState extends ConsumerState<WebDavSyncPane> {
  _WebDavAction? _busy;

  void _toast(String message, {DsStatus status = DsStatus.neutral}) =>
      showDsToast(context: context, title: message, status: status);

  /// Runs one action at a time: the running row spins, the rest grey out, and
  /// every failure becomes the one message the page keeps for it.
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
      if (mounted) _toast(_webDavMessage(failure), status: DsStatus.danger);
    } on Object catch (error) {
      if (!mounted) return;
      _toast(
        error is StateError ? t.backup.webdavNoAccounts : t.backup.webdavFailed,
        status: DsStatus.danger,
      );
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

  /// One line on what a restore would change, shown in the confirm.
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

  // -- Accounts -----------------------------------------------------------

  /// Edits one account, or adds one when [account] is null.
  ///
  /// The password field keeps what the vault holds unless the viewer types:
  /// an edit of the address must not silently drop the secret beside it.
  Future<void> _editAccount({WebDavAccount? account}) async {
    final t = context.t;
    final adding = account == null;
    final hasPassword = !adding && await hasAccountPassword(await webDavVault(ref), account.id);
    if (!mounted) return;
    final nameField = TextEditingController(text: account?.name ?? '');
    final urlField = TextEditingController(text: account?.url ?? '');
    final userField = TextEditingController(text: account?.user ?? '');
    final passwordField = TextEditingController();
    await showDsDialog<void>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(adding ? t.backup.webdavAddAccount : t.backup.webdavEditAccount),
        icon: const DsIcon(DsIcons.server),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.backup.webdavConfigDescription),
            DsTextField(
              controller: nameField,
              clearable: true,
              placeholder: t.backup.webdavAccountNameHint,
              semanticLabel: t.backup.webdavAccountName,
            ),
            DsTextField(
              controller: urlField,
              autofocus: adding,
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
              placeholder: hasPassword ? t.backup.webdavPasswordKeep : t.backup.webdavPasswordHint,
              semanticLabel: t.backup.webdavPassword,
            ),
          ],
        ),
        actions: [
          if (!adding)
            DsButton(
              variant: DsButtonVariant.ghost,
              onPressed: () {
                Navigator.of(context).pop();
                unawaited(_removeAccount(account));
              },
              child: Text(t.common.delete),
            ),
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          DsButton(
            onPressed: () {
              final url = normalizeWebDavUrl(urlField.text);
              if (url.isEmpty) {
                Navigator.of(context).pop();
                _toast(t.backup.webdavUrlMissing, status: DsStatus.danger);
                return;
              }
              Navigator.of(context).pop();
              final name = nameField.text.trim();
              unawaited(
                ref
                    .read(webdavAccountsProvider.notifier)
                    .save(
                      account: (
                        id: account?.id ?? '',
                        // The host names an unnamed account, so the list never
                        // shows four entries called "WebDAV".
                        name: name.isEmpty ? webDavAccountNameFromUrl(url) : name,
                        url: url,
                        user: userField.text.trim(),
                      ),
                      // Empty keeps the stored password when there is one, and
                      // clears it when there is none to keep.
                      password: passwordField.text.isEmpty ? (hasPassword ? null : '') : passwordField.text,
                    )
                    .then((_) {
                      if (mounted) _toast(t.backup.webdavSaved, status: DsStatus.success);
                    }),
              );
            },
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
    nameField.dispose();
    urlField.dispose();
    userField.dispose();
    passwordField.dispose();
  }

  Future<void> _removeAccount(WebDavAccount account) async {
    final t = context.t;
    final confirmed = await _confirm(
      t.backup.webdavAccountDeleteTitle(name: account.name),
      description: t.backup.webdavAccountDeleteDesc,
    );
    if (!confirmed) return;
    await ref.read(webdavAccountsProvider.notifier).remove(account.id);
    if (mounted) _toast(t.backup.webdavAccountDeleted, status: DsStatus.success);
  }

  /// Selects [account] and opens its folders: the page's one gesture.
  Future<void> _openAccount(WebDavAccount account) async {
    await ref.read(webdavAccountsProvider.notifier).select(account.id);
    if (!mounted) return;
    await showWebDavFolders(context, account: account);
  }

  // -- Sync actions -------------------------------------------------------

  Future<void> _test() => _run(_WebDavAction.test, () async {
    final t = context.t;
    await testWebDav(ref);
    if (!mounted) return;
    _toast(t.backup.webdavTestOk, status: DsStatus.success);
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
    _toast(t.backup.webdavUploadDone(file: BackupDocument.backupFileName), status: DsStatus.success);
  });

  Future<void> _download() => _run(_WebDavAction.download, () async {
    final t = context.t;
    final document = await downloadBackupFromWebDav(ref);
    if (!mounted) return;
    if (document == null) {
      _toast(t.backup.importBadData, status: DsStatus.danger);
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
    if (mounted) _toast(t.backup.importDone, status: DsStatus.success);
  });

  // -- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final stored = ref.watch(webdavAccountsProvider);
    final accounts = stored.accounts;
    final current = accounts.isEmpty
        ? null
        : (accounts.where((account) => account.id == stored.selected).firstOrNull ?? accounts.first);
    final busy = _busy;
    bool free(_WebDavAction action) => busy == null || busy == action;
    Widget? spinner(_WebDavAction action) => busy == action ? const DsSpinner() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        DsListSection(
          // The account list's own header row carries its only global action,
          // top right, where a file manager puts "new".
          header: Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(child: Text(t.backup.webdavAccounts)),
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.plus, size: 16),
                onPressed: busy == null ? () => unawaited(_editAccount()) : null,
                child: Text(t.backup.webdavAddAccount),
              ),
            ],
          ),
          children: [
            if (accounts.isEmpty)
              DsListRow(
                leading: const DsIcon(DsIcons.cloudOff),
                title: Text(t.backup.webdavNoAccounts),
                description: Text(t.backup.webdavNoAccountsDesc),
              )
            else
              for (final account in accounts)
                DsListRow(
                  leading: const DsIcon(DsIcons.server),
                  title: Text(account.name.isEmpty ? account.url : account.name),
                  description: Text(account.url),
                  detail: Text(account.id == current?.id ? t.backup.webdavCurrent : account.user),
                  showChevron: true,
                  onPressed: busy == null ? () => unawaited(_openAccount(account)) : null,
                  trailing: DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: t.backup.webdavEditAccount,
                    onPressed: busy == null ? () => unawaited(_editAccount(account: account)) : null,
                    icon: const DsIcon(DsIcons.pencil, size: 16),
                  ),
                ),
            if (accounts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s4, DsSpace.s20, DsSpace.s12),
                child: Text(
                  t.backup.webdavAccountsHint,
                  style: theme.typography.caption.copyWith(color: colors.textSubtle),
                ),
              ),
          ],
        ),
        DsListSection(
          header: Text(t.backup.webdavSection),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.plugZap),
              title: Text(t.backup.webdavTest),
              description: Text(t.backup.webdavTestDesc),
              onPressed: current == null || !free(_WebDavAction.test) ? null : () => unawaited(_test()),
              trailing: spinner(_WebDavAction.test),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.cloudUpload),
              title: Text(t.backup.webdavUpload),
              description: Text(t.backup.webdavUploadDesc),
              onPressed: current == null || !free(_WebDavAction.upload) ? null : () => unawaited(_upload()),
              trailing: spinner(_WebDavAction.upload),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.cloudDownload),
              title: Text(t.backup.webdavDownload),
              description: Text(t.backup.webdavDownloadDesc),
              onPressed: current == null || !free(_WebDavAction.download) ? null : () => unawaited(_download()),
              trailing: spinner(_WebDavAction.download),
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.folderOpen),
              title: Text(t.backup.webdavBrowse),
              description: Text(t.backup.webdavBrowseDesc),
              showChevron: true,
              onPressed: current == null ? null : () => unawaited(_openAccount(current)),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s4),
          child: Text(
            t.backup.webdavDescription(file: BackupDocument.backupFileName),
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
        ),
      ],
    );
  }
}
