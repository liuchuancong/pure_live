import 'dart:async' show unawaited;
import 'dart:convert' show utf8;
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;

import 'package:desen_ui/desen_ui.dart';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_repository.dart' show backupSummaryProvider;
import 'package:pure_live/features/backup/panes/backup_actions.dart'
    show applyBackup, captureBackupDocument, formatBackupSize, formatBackupTime, webDavClientFor;
import 'package:pure_live/features/backup/webdav/webdav_accounts.dart';
import 'package:pure_live/features/backup/webdav/webdav_client.dart';
import 'package:pure_live/features/backup/webdav/webdav_settings.dart' show webDavVault;
import 'package:pure_live/l10n/translations.dart';

/// The WebDAV page under Backup and restore: the saved drives as a file
/// manager.
///
/// The toolbar's account picker is the page's subject — a cloud drive, a home
/// NAS, a work share — and switching it swaps the root the rows below walk. A
/// breadcrumb underneath says where the rows are, the quota line says how
/// much room is left, and the toolbar's verbs write into that folder: upload
/// files, make a folder, or send this device's backup as a stamped file. A
/// row's menu downloads, restores, renames, moves or deletes it.
final class WebDavFileManager extends ConsumerStatefulWidget {
  /// The WebDAV page's content.
  const WebDavFileManager({super.key});

  @override
  ConsumerState<WebDavFileManager> createState() => _WebDavFileManagerState();
}

final class _WebDavFileManagerState extends ConsumerState<WebDavFileManager> {
  /// The clients built this run, one per account; an edited account's entry
  /// is dropped so the new address or password is the one used.
  final Map<String, WebDavBackupClient> _clients = {};

  WebDavBackupClient? _client;
  String? _accountId;

  /// The folder on screen, root-relative; `/` is the account's own root.
  String _path = WebDavBackupClient.root;
  List<WebDavEntry>? _rows;
  (int used, int available)? _quota;
  Object? _error;
  bool _loading = false;
  bool _busy = false;

  /// Bumped on every navigation, so a slow listing that lands after the
  /// viewer walked away is dropped instead of drawn.
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    final account = _currentOf(ref.read(webdavAccountsProvider));
    if (account != null) unawaited(_activate(account, persist: false));
  }

  // -- Accounts -----------------------------------------------------------

  /// The account the page should show: the one it already switched to while
  /// it is still saved, else the saved selection, else the first.
  WebDavAccount? _currentOf(WebDavAccounts stored) {
    for (final account in stored.accounts) {
      if (account.id == _accountId) return account;
    }
    for (final account in stored.accounts) {
      if (account.id == stored.selected) return account;
    }
    return stored.accounts.isEmpty ? null : stored.accounts.first;
  }

  /// Makes [account] the page's server, then lists its root.
  Future<void> _activate(WebDavAccount account, {bool persist = true}) async {
    if (persist) await ref.read(webdavAccountsProvider.notifier).select(account.id);
    if (!mounted) return;
    _epoch++;
    setState(() {
      _accountId = account.id;
      _path = WebDavBackupClient.root;
      _client = null;
      _rows = null;
      _quota = null;
      _error = null;
    });
    await _load();
  }

  Future<WebDavBackupClient?> _ensureClient() async {
    final cached = _client;
    if (cached != null) return cached;
    final stored = ref.read(webdavAccountsProvider);
    final account = _currentOf(stored);
    if (account == null) return null;
    final client = _clients[account.id] ??= await webDavClientFor(ref, account);
    // A switch during the vault read leaves this client to the listing it was
    // made for; the field belongs to whichever account is on screen now.
    if (mounted && _accountId == account.id) _client = client;
    return client;
  }

  /// Edits one account, or adds one when [account] is null.
  ///
  /// The form can test the address before saving: the test signs in with the
  /// typed password (or the stored one) and lists the root once, which is the
  /// same round trip the page's first load makes.
  Future<void> _editAccount({WebDavAccount? account}) async {
    final t = context.t;
    final adding = account == null;
    final store = await webDavVault(ref);
    final hasPassword = !adding && await hasAccountPassword(store, account.id);
    if (!mounted) return;
    final nameField = TextEditingController(text: account?.name ?? '');
    final urlField = TextEditingController(text: account?.url ?? '');
    final userField = TextEditingController(text: account?.user ?? '');
    final passwordField = TextEditingController();
    var testing = false;
    await showDsDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => DsDialog(
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
            DsButton(
              variant: DsButtonVariant.ghost,
              loading: testing,
              onPressed: () => unawaited(() async {
                final url = normalizeWebDavUrl(urlField.text);
                if (url.isEmpty) {
                  showDsToast(context: context, title: t.backup.webdavUrlMissing, status: DsStatus.danger);
                  return;
                }
                setLocal(() => testing = true);
                final password = passwordField.text.isEmpty
                    ? (hasPassword ? await readAccountPassword(store, account.id) : '')
                    : passwordField.text;
                final client = WebDavBackupClient(url: url, username: userField.text.trim(), password: password);
                try {
                  await client.test();
                  if (context.mounted) {
                    showDsToast(context: context, title: t.backup.webdavTestOk, status: DsStatus.success);
                  }
                } on Object catch (error) {
                  if (context.mounted) {
                    showDsToast(context: context, title: _messageOf(error), status: DsStatus.danger);
                  }
                } finally {
                  if (context.mounted) setLocal(() => testing = false);
                }
              }()),
              child: Text(t.backup.webdavTest),
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
                // The controllers go away with the dialog; the save reads
                // only what was captured here.
                final typedName = nameField.text.trim();
                final user = userField.text.trim();
                final typedPassword = passwordField.text;
                Navigator.of(context).pop();
                unawaited(() async {
                  final id = await ref
                      .read(webdavAccountsProvider.notifier)
                      .save(
                        account: (
                          id: account?.id ?? '',
                          // The host names an unnamed account, so the list
                          // never shows four entries called "WebDAV".
                          name: typedName.isEmpty ? webDavAccountNameFromUrl(url) : typedName,
                          url: url,
                          user: user,
                        ),
                        // Empty keeps the stored password when there is one,
                        // and clears it when there is none to keep.
                        password: typedPassword.isEmpty ? (hasPassword ? null : '') : typedPassword,
                      );
                  if (account != null) _clients.remove(account.id);
                  final wasCurrent = account == null || account.id == _accountId;
                  if (!mounted) return;
                  _toast(t.backup.webdavSaved, status: DsStatus.success);
                  if (!wasCurrent) return;
                  final stored = ref.read(webdavAccountsProvider);
                  for (final saved in stored.accounts) {
                    if (saved.id == id) {
                      await _activate(saved, persist: false);
                      return;
                    }
                  }
                }());
              },
              child: Text(t.common.confirm),
            ),
          ],
        ),
      ),
    );
    nameField.dispose();
    urlField.dispose();
    userField.dispose();
    passwordField.dispose();
  }

  /// The saved accounts with their edit and delete verbs, plus "add".
  Future<void> _manageAccounts() async {
    final t = context.t;
    await showDsDialog<void>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final accounts = ref.watch(webdavAccountsProvider).accounts;
          return DsDialog(
            title: Text(t.backup.webdavAccounts),
            icon: const DsIcon(DsIcons.server),
            description: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (accounts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: DsSpace.s8),
                        child: Text(t.backup.webdavNoAccounts),
                      ),
                    for (final account in accounts)
                      DsListRow(
                        leading: const DsIcon(DsIcons.server),
                        title: Text(
                          account.name.isEmpty ? account.url : account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        description: Text(account.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DsButton.icon(
                              variant: DsButtonVariant.ghost,
                              size: DsSize.sm,
                              semanticLabel: t.backup.webdavEditAccount,
                              onPressed: () => unawaited(_editAccount(account: account)),
                              icon: const DsIcon(DsIcons.pencil, size: 16),
                            ),
                            DsButton.icon(
                              variant: DsButtonVariant.ghost,
                              size: DsSize.sm,
                              semanticLabel: t.common.delete,
                              onPressed: () => unawaited(_removeAccount(account)),
                              icon: const DsIcon(DsIcons.trash2, size: 16),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              DsButton(
                variant: DsButtonVariant.secondary,
                leading: const DsIcon(DsIcons.plus, size: 16),
                onPressed: () => unawaited(_editAccount()),
                child: Text(t.backup.webdavAddAccount),
              ),
              DsButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.common.close)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeAccount(WebDavAccount account) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.backup.webdavAccountDeleteTitle(name: account.name),
      description: t.backup.webdavAccountDeleteDesc,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    await ref.read(webdavAccountsProvider.notifier).remove(account.id);
    _clients.remove(account.id);
    if (!mounted) return;
    _toast(t.backup.webdavAccountDeleted, status: DsStatus.success);
    final stored = ref.read(webdavAccountsProvider);
    if (stored.accounts.isEmpty) {
      _epoch++;
      setState(() {
        _accountId = null;
        _client = null;
        _path = WebDavBackupClient.root;
        _rows = null;
        _quota = null;
        _error = null;
      });
      return;
    }
    final next = _currentOf(stored);
    if (next != null) await _activate(next, persist: false);
  }

  // -- Listing ------------------------------------------------------------

  Future<void> _load({bool keepRows = false}) async {
    final client = await _ensureClient();
    if (!mounted) return;
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _error = null;
      if (!keepRows) _rows = null;
    });
    if (client == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final rows = await client.list(path: _path);
      final quota = await client.quota();
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _rows = rows;
        _quota = quota;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _error = error;
        if (!keepRows) _rows = null;
        _loading = false;
      });
    }
  }

  void _openFolder(WebDavEntry entry) {
    if (!entry.isDirectory || _busy) return;
    _openPath(entry.path);
  }

  void _openPath(String path) {
    if (_busy) return;
    setState(() {
      _path = path;
      _rows = null;
      _error = null;
    });
    unawaited(_load());
  }

  // -- File verbs ---------------------------------------------------------

  /// Runs one server write with the rows greyed while it works.
  Future<void> _run(Future<void> Function(WebDavBackupClient client) work) async {
    if (_busy) return;
    final client = await _ensureClient();
    if (!mounted) return;
    if (client == null) {
      _toast(context.t.backup.webdavNoAccounts, status: DsStatus.danger);
      return;
    }
    setState(() => _busy = true);
    try {
      await work(client);
    } on Object catch (error) {
      if (mounted) _toast(_messageOf(error), status: DsStatus.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadFiles() async {
    if (_busy) return;
    final t = context.t;
    final picked = await FilePicker.pickFiles(dialogTitle: t.backup.webdavUploadFile);
    if (picked.isEmpty || !mounted) return;
    final files = [
      for (final file in picked)
        if ((file.path ?? '').isNotEmpty) file,
    ];
    if (files.isEmpty) return;
    await _run((client) async {
      final taken = {..._taken};
      var uploaded = 0;
      for (final pickedFile in files) {
        final bytes = await File(pickedFile.path!).readAsBytes();
        final name = _freeName(pickedFile.name, taken);
        taken.add(name);
        await client.writeFile(_join(_path, name), bytes);
        uploaded++;
      }
      if (!mounted) return;
      showDsToast(
        context: context,
        title: t.backup.webdavUploadFilesDone(count: uploaded),
        status: DsStatus.success,
      );
      unawaited(_load());
    });
  }

  /// Sends this device's data as a stamped backup file into the open folder.
  Future<void> _uploadBackup(BackupScope scope) => _run((client) async {
    final t = context.t;
    final document = await captureBackupDocument(ref, scope: scope);
    if (document.isEmpty) {
      if (mounted) showDsToast(context: context, title: t.backup.exportEmpty);
      return;
    }
    final name = _freeName(BackupDocument.exportFileName(DateTime.now(), scope: scope), _taken);
    await client.writeFile(_join(_path, name), utf8.encode(document.encode()));
    if (!mounted) return;
    showDsToast(
      context: context,
      title: t.backup.webdavUploadDone(file: name),
      status: DsStatus.success,
    );
    unawaited(_load());
  });

  /// Reads one remote file and hands it to the system's save dialog.
  Future<void> _download(WebDavEntry entry) => _run((client) async {
    final t = context.t;
    final bytes = await client.readFile(entry.path);
    final saved = await FilePicker.saveFile(
      dialogTitle: t.backup.webdavDownloadToLocal,
      fileName: entry.name,
      bytes: bytes,
    );
    if (!mounted || saved == null) return;
    _toast(t.backup.webdavSavedToDevice(file: entry.name), status: DsStatus.success);
  });

  Future<void> _restore(WebDavEntry entry) async {
    final t = context.t;
    final bytes = await _readBytes(entry);
    if (bytes == null || !mounted) return;
    final document = BackupDocument.tryDecode(utf8.decode(bytes, allowMalformed: true));
    if (document == null) {
      _toast(t.backup.importBadData, status: DsStatus.danger);
      return;
    }
    final counts = document.counts;
    final summary = document.followsOnly
        ? t.backup.summaryFollows(follows: counts.follows, areas: counts.areas)
        : t.backup.summary(
            follows: counts.follows,
            history: counts.history,
            areas: counts.areas,
            settings: counts.settings,
          );
    final confirmed = await showDsConfirm(
      context: context,
      title: t.backup.webdavRestoreTitle(name: entry.name),
      description: '${t.backup.webdavRestoreDesc}\n$summary',
      confirmLabel: t.common.confirm,
      cancelLabel: t.common.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await applyBackup(ref, document);
    ref.invalidate(backupSummaryProvider);
    if (mounted) _toast(t.backup.webdavRestored, status: DsStatus.success);
  }

  /// Reads one remote file with the same busy guard the writes use.
  Future<Uint8List?> _readBytes(WebDavEntry entry) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      return await (await _ensureClient())?.readFile(entry.path);
    } on Object catch (error) {
      if (mounted) _toast(_messageOf(error), status: DsStatus.danger);
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(WebDavEntry entry) async {
    if (_busy) return;
    final t = context.t;
    final name = await _askText(
      title: t.backup.webdavRenameTitle(name: entry.name),
      initial: entry.name,
    );
    if (name == null || !mounted) return;
    final next = name.trim().replaceAll('/', '');
    if (next.isEmpty || next == entry.name) return;
    await _run((client) async {
      await client.move(entry.path, _join(_parentOf(entry.path), next), isDirectory: entry.isDirectory);
      if (!mounted) return;
      _toast(t.backup.webdavRenamed, status: DsStatus.success);
      unawaited(_load());
    });
  }

  Future<void> _move(WebDavEntry entry) async {
    if (_busy) return;
    final t = context.t;
    final client = await _ensureClient();
    if (client == null || !mounted) return;
    final target = await _askFolder(
      title: t.backup.webdavMoveTitle(name: entry.name),
      client: client,
    );
    if (target == null || !mounted) return;
    final destination = _join(target, _baseName(entry.path));
    if (destination == entry.path) return;
    if (entry.isDirectory && (target == entry.path || target.startsWith('${entry.path}/'))) {
      _toast(t.backup.webdavMoveIntoItself, status: DsStatus.danger);
      return;
    }
    await _run((client) async {
      await client.move(entry.path, destination, isDirectory: entry.isDirectory);
      if (!mounted) return;
      _toast(t.backup.webdavMoved, status: DsStatus.success);
      unawaited(_load());
    });
  }

  Future<void> _delete(WebDavEntry entry) async {
    if (_busy) return;
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.backup.webdavDeleteTitle(name: entry.name),
      description: entry.isDirectory ? t.backup.webdavDeleteFolderDesc : t.backup.webdavDeleteDesc,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed || !mounted) return;
    await _run((client) async {
      await client.delete(entry);
      if (!mounted) return;
      _toast(t.backup.webdavDeleted, status: DsStatus.success);
      unawaited(_load());
    });
  }

  Future<void> _newFolder() async {
    if (_busy) return;
    final t = context.t;
    final name = await _askText(title: t.backup.webdavNewFolder, hint: t.backup.webdavNewFolderName);
    if (name == null || !mounted) return;
    final next = name.trim().replaceAll('/', '');
    if (next.isEmpty) {
      _toast(t.backup.webdavUploadInvalid, status: DsStatus.danger);
      return;
    }
    await _run((client) async {
      await client.createFolder(_join(_path, next));
      if (!mounted) return;
      _toast(t.backup.webdavFolderCreated, status: DsStatus.success);
      unawaited(_load());
    });
  }

  // -- Dialogs ------------------------------------------------------------

  /// Asks for one line of text; null means the viewer backed out.
  Future<String?> _askText({required String title, String initial = '', String? hint}) async {
    final t = context.t;
    final field = TextEditingController(text: initial);
    final answer = await showDsDialog<String>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(title),
        icon: const DsIcon(DsIcons.folderPlus),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            if (hint != null) Text(hint, style: DsTheme.of(context).typography.caption),
            DsTextField(
              controller: field,
              autofocus: true,
              clearable: true,
              placeholder: hint ?? title,
              semanticLabel: title,
            ),
          ],
        ),
        actions: [
          DsButton(
            variant: DsButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.cancel),
          ),
          DsButton(onPressed: () => Navigator.of(context).pop(field.text.trim()), child: Text(t.common.confirm)),
        ],
      ),
    );
    field.dispose();
    return answer;
  }

  /// Walks the server's folders and answers the one picked; null cancels.
  Future<String?> _askFolder({required String title, required WebDavBackupClient client}) {
    final t = context.t;
    var path = WebDavBackupClient.root;
    var folders = client.list(path: path);
    return showDsDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final segments = path.split('/').where((segment) => segment.isNotEmpty).toList();
          void open(String next) => setLocal(() {
            path = next;
            folders = client.list(path: next);
          });
          return DsDialog(
            title: Text(title),
            icon: const DsIcon(DsIcons.folderTree),
            description: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s8,
              children: [
                Row(
                  spacing: DsSpace.s4,
                  children: [
                    DsButton.icon(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      semanticLabel: t.backup.webdavUp,
                      onPressed: segments.isEmpty
                          ? null
                          : () => open(
                              segments.length <= 1
                                  ? WebDavBackupClient.root
                                  : '/${segments.take(segments.length - 1).join('/')}',
                            ),
                      icon: const DsIcon(DsIcons.chevronLeft, size: 16),
                    ),
                    Expanded(
                      child: Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsTheme.of(context).typography.caption,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 280,
                  child: FutureBuilder<List<WebDavEntry>>(
                    future: folders,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 20)));
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            _messageOf(snapshot.error!),
                            textAlign: TextAlign.center,
                            style: DsTheme.of(context).typography.caption,
                          ),
                        );
                      }
                      final rows = [
                        for (final entry in snapshot.data ?? const <WebDavEntry>[])
                          if (entry.isDirectory) entry,
                      ];
                      if (rows.isEmpty) {
                        return Center(child: Text(t.backup.webdavEmpty));
                      }
                      return ListView(
                        children: [
                          for (final entry in rows)
                            DsListRow(
                              leading: const DsIcon(DsIcons.folder),
                              title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              showChevron: true,
                              onPressed: () => open(entry.path),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            actions: [
              DsButton(
                variant: DsButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t.common.cancel),
              ),
              DsButton(onPressed: () => Navigator.of(context).pop(path), child: Text(t.backup.webdavMoveHere)),
            ],
          );
        },
      ),
    );
  }

  void _toast(String message, {DsStatus status = DsStatus.neutral}) =>
      showDsToast(context: context, title: message, status: status);

  /// One message per failure kind, the same words every WebDAV surface uses.
  String _messageOf(Object error) {
    if (!mounted) return error.toString();
    final t = context.t;
    return switch (error) {
      WebDavFailure(problem: WebDavProblem.auth) => t.backup.webdavAuthFailed,
      WebDavFailure(problem: WebDavProblem.notFound) => t.backup.webdavNotFound,
      WebDavFailure(:final status?) => t.backup.webdavServerFailed(status: status),
      WebDavFailure() => t.backup.webdavNetworkFailed,
      StateError() => t.backup.webdavUrlMissing,
      _ => t.backup.webdavFailed,
    };
  }

  // -- Paths --------------------------------------------------------------

  Set<String> get _taken => {for (final entry in _rows ?? const <WebDavEntry>[]) entry.name};

  /// `parent` plus one more segment; the root keeps its leading slash.
  static String _join(String parent, String name) {
    final clean = name.trim().replaceAll('/', '');
    if (parent == WebDavBackupClient.root) return '/$clean';
    return '$parent/$clean';
  }

  static String _parentOf(String path) {
    final cut = path.lastIndexOf('/');
    return cut <= 0 ? WebDavBackupClient.root : path.substring(0, cut);
  }

  static String _baseName(String path) => path.substring(path.lastIndexOf('/') + 1);

  static String _freeName(String name, Set<String> taken) {
    if (!taken.contains(name)) return name;
    final dot = name.lastIndexOf('.');
    final base = dot <= 0 ? name : name.substring(0, dot);
    final extension = dot <= 0 ? '' : name.substring(dot);
    for (var index = 2; ; index++) {
      final candidate = '${base}_$index$extension';
      if (!taken.contains(candidate)) return candidate;
    }
  }

  // -- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final stored = ref.watch(webdavAccountsProvider);
    final accounts = stored.accounts;
    if (accounts.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.backup.webdavNoAccounts),
          description: Text(t.backup.webdavNoAccountsDesc),
          actions: [DsButton(onPressed: () => unawaited(_editAccount()), child: Text(t.backup.webdavAddAccount))],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        _toolbar(context, accounts),
        _pathBar(context),
        Expanded(child: _body(context)),
      ],
    );
  }

  Widget _toolbar(BuildContext context, List<WebDavAccount> accounts) {
    final t = context.t;
    final current = _currentOf(ref.watch(webdavAccountsProvider));
    final enabled = !_busy;
    // Without room for the verbs beside the picker, they move into the menu.
    final compact = MediaQuery.sizeOf(context).width < 560;
    return Row(
      spacing: DsSpace.s4,
      children: [
        Flexible(
          child: DsMenuAnchor(
            semanticLabel: t.backup.webdavSwitchAccount,
            items: [
              for (final account in accounts)
                DsMenuItem(
                  label: Text(account.name.isEmpty ? account.url : account.name),
                  leading: const DsIcon(DsIcons.server),
                  checked: account.id == current?.id,
                  onPressed: () => unawaited(_activate(account)),
                ),
              const DsMenuDivider(),
              DsMenuItem(
                label: Text(t.backup.webdavManageAccounts),
                leading: const DsIcon(DsIcons.pencil),
                onPressed: () => unawaited(_manageAccounts()),
              ),
              DsMenuItem(
                label: Text(t.backup.webdavAddAccount),
                leading: const DsIcon(DsIcons.plus),
                onPressed: () => unawaited(_editAccount()),
              ),
            ],
            builder: (context, controller, _) => DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.server, size: 16),
              trailing: const DsIcon(DsIcons.chevronDown, size: 14),
              semanticLabel: t.backup.webdavSwitchAccount,
              onPressed: controller.toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  current == null || current.name.isEmpty ? (current?.url ?? t.backup.webdavNoAccounts) : current.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
        if (_loading) const DsSpinner(style: DsSpinnerStyle(size: 16)),
        const Spacer(),
        if (!compact) ...[
          _ToolButton(
            icon: DsIcons.refreshCw,
            label: t.backup.webdavRefresh,
            onPressed: enabled ? () => unawaited(_load(keepRows: true)) : null,
          ),
          _ToolButton(
            icon: DsIcons.upload,
            label: t.backup.webdavUploadFile,
            onPressed: enabled ? () => unawaited(_uploadFiles()) : null,
          ),
          _ToolButton(
            icon: DsIcons.folderPlus,
            label: t.backup.webdavNewFolder,
            onPressed: enabled ? () => unawaited(_newFolder()) : null,
          ),
        ],
        DsMenuAnchor(
          semanticLabel: t.common.more,
          align: DsAlign.end,
          items: [
            if (compact) ...[
              DsMenuItem(
                label: Text(t.backup.webdavRefresh),
                leading: const DsIcon(DsIcons.refreshCw),
                onPressed: () {
                  if (enabled) unawaited(_load(keepRows: true));
                },
              ),
              DsMenuItem(
                label: Text(t.backup.webdavUploadFile),
                leading: const DsIcon(DsIcons.upload),
                onPressed: () {
                  if (enabled) unawaited(_uploadFiles());
                },
              ),
              DsMenuItem(
                label: Text(t.backup.webdavNewFolder),
                leading: const DsIcon(DsIcons.folderPlus),
                onPressed: () {
                  if (enabled) unawaited(_newFolder());
                },
              ),
              const DsMenuDivider(),
            ],
            DsMenuItem(
              label: Text(t.backup.webdavUpload),
              leading: const DsIcon(DsIcons.cloudUpload),
              onPressed: () {
                if (enabled) unawaited(_uploadBackup(BackupScope.all));
              },
            ),
            DsMenuItem(
              label: Text(t.backup.webdavUploadFollows),
              leading: const DsIcon(DsIcons.cloudUpload),
              onPressed: () {
                if (enabled) unawaited(_uploadBackup(BackupScope.follows));
              },
            ),
            const DsMenuDivider(),
            DsMenuItem(
              label: Text(t.backup.webdavManageAccounts),
              leading: const DsIcon(DsIcons.server),
              onPressed: () => unawaited(_manageAccounts()),
            ),
          ],
          builder: (context, controller, _) => DsButton.icon(
            variant: DsButtonVariant.ghost,
            size: DsSize.sm,
            semanticLabel: t.common.more,
            onPressed: controller.toggle,
            icon: const DsIcon(DsIcons.ellipsisVertical, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _pathBar(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final segments = _path.split('/').where((segment) => segment.isNotEmpty).toList();
    final trail = <(String, String)>[(t.backup.webdavRoot, WebDavBackupClient.root)];
    for (var index = 0; index < segments.length; index++) {
      trail.add((segments[index], '/${segments.take(index + 1).join('/')}'));
    }
    final quota = _quota;
    return Row(
      spacing: DsSpace.s8,
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (index, step) in trail.indexed) ...[
                  if (index > 0) DsIcon(DsIcons.chevronRight, size: 14, color: colors.textSubtle),
                  if (index == trail.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s6),
                      child: Text(
                        step.$1,
                        style: theme.typography.caption.copyWith(color: colors.text, fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    DsButton(
                      variant: DsButtonVariant.ghost,
                      size: DsSize.sm,
                      onPressed: _busy ? null : () => _openPath(step.$2),
                      child: Text(step.$1),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (quota != null && MediaQuery.sizeOf(context).width >= 560)
          Text(
            t.backup.webdavQuota(used: formatBackupSize(quota.$1), total: formatBackupSize(quota.$1 + quota.$2)),
            style: theme.typography.caption.copyWith(color: colors.textSubtle),
          ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final t = context.t;
    final error = _error;
    if (error != null) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.backup.webdavLoadFailed),
          description: Text(_messageOf(error)),
          actions: [DsButton(onPressed: () => unawaited(_load()), child: Text(t.common.retry))],
        ),
      );
    }
    final rows = _rows;
    if (rows == null) return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24)));
    if (rows.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.folderOpen),
          title: Text(t.backup.webdavEmpty),
          actions: [
            DsButton(onPressed: _busy ? null : () => unawaited(_uploadFiles()), child: Text(t.backup.webdavUploadFile)),
            DsButton(
              variant: DsButtonVariant.secondary,
              onPressed: _busy ? null : () => unawaited(_newFolder()),
              child: Text(t.backup.webdavNewFolder),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: DsSpace.s16),
      children: [
        DsListSection(
          children: [
            for (final entry in rows)
              _EntryRow(
                key: ValueKey(entry.path),
                entry: entry,
                enabled: !_busy,
                onOpen: () => _openFolder(entry),
                onDownload: () => unawaited(_download(entry)),
                onRestore: entry.name.toLowerCase().endsWith('.json') ? () => unawaited(_restore(entry)) : null,
                onRename: () => unawaited(_rename(entry)),
                onMove: () => unawaited(_move(entry)),
                onDelete: () => unawaited(_delete(entry)),
              ),
          ],
        ),
      ],
    );
  }
}

/// One folder or file of the open folder: a tap opens a folder or shows a
/// file's verbs, the ⋮ shows the same menu.
final class _EntryRow extends StatefulWidget {
  const _EntryRow({
    required this.entry,
    required this.enabled,
    required this.onOpen,
    required this.onDownload,
    required this.onRestore,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
    super.key,
  });

  final WebDavEntry entry;
  final bool enabled;
  final VoidCallback onOpen;
  final VoidCallback onDownload;

  /// Restores this device from the file; null when the file cannot be one.
  final VoidCallback? onRestore;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

final class _EntryRowState extends State<_EntryRow> {
  final DsOverlayController _menu = DsOverlayController();

  @override
  void dispose() {
    _menu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final entry = widget.entry;
    final restore = widget.onRestore;
    return DsMenuAnchor(
      controller: _menu,
      align: DsAlign.end,
      semanticLabel: t.common.more,
      items: [
        if (entry.isDirectory)
          DsMenuItem(
            leading: const DsIcon(DsIcons.folderOpen),
            label: Text(t.backup.webdavEnterFolder),
            onPressed: widget.onOpen,
          ),
        if (!entry.isDirectory) ...[
          if (restore != null)
            DsMenuItem(
              leading: const DsIcon(DsIcons.databaseBackup),
              label: Text(t.backup.webdavRestore),
              onPressed: restore,
            ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.download),
            label: Text(t.backup.webdavDownloadToLocal),
            onPressed: widget.onDownload,
          ),
        ],
        const DsMenuDivider(),
        DsMenuItem(
          leading: const DsIcon(DsIcons.pencil),
          label: Text(t.backup.webdavRename),
          onPressed: widget.onRename,
        ),
        DsMenuItem(
          leading: const DsIcon(DsIcons.moveHorizontal),
          label: Text(t.backup.webdavMove),
          onPressed: widget.onMove,
        ),
        DsMenuItem(
          leading: const DsIcon(DsIcons.trash2),
          label: Text(t.common.delete),
          destructive: true,
          onPressed: widget.onDelete,
        ),
      ],
      child: DsListRow(
        leading: DsIcon(
          entry.isDirectory
              ? DsIcons.folder
              : entry.name.toLowerCase().endsWith('.json')
              ? DsIcons.databaseBackup
              : DsIcons.file,
        ),
        title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        description: Text(
          entry.isDirectory
              ? t.backup.webdavEnterFolder
              : [
                  if (entry.size case final size?) formatBackupSize(size),
                  if (entry.modified case final modified?) formatBackupTime(modified),
                ].join(' · '),
        ),
        showChevron: entry.isDirectory,
        onPressed: !widget.enabled
            ? null
            : entry.isDirectory
            ? widget.onOpen
            : _menu.toggle,
        trailing: DsButton.icon(
          variant: DsButtonVariant.ghost,
          size: DsSize.sm,
          semanticLabel: t.common.more,
          onPressed: widget.enabled ? _menu.toggle : null,
          icon: const DsIcon(DsIcons.ellipsisVertical, size: 16),
        ),
      ),
    );
  }
}

/// One toolbar action: an icon button disabled while a server call runs.
final class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, required this.onPressed});

  final DsIconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DsButton.icon(
      variant: DsButtonVariant.ghost,
      size: DsSize.sm,
      semanticLabel: label,
      onPressed: onPressed,
      icon: DsIcon(icon, size: 18),
    );
  }
}
