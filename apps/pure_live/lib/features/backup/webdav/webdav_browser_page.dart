import 'dart:async' show unawaited;
import 'dart:convert' show utf8;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_repository.dart' show backupSummaryProvider;
import 'package:pure_live/features/backup/panes/backup_actions.dart'
    show applyBackup, captureBackupDocument, formatBackupSize, formatBackupTime, webDavClientFor;
import 'package:pure_live/features/backup/webdav/webdav_accounts.dart' show WebDavAccount;
import 'package:pure_live/features/backup/webdav/webdav_client.dart';
import 'package:pure_live/l10n/translations.dart';

/// Opens one account's folders: the page the viewer walks the server in.
///
/// It is a page rather than a panel because the walking is the point — a
/// breadcrumb, a folder to make, a file to restore or delete — and a dialog
/// would take the room the list needs.
Future<void> showWebDavFolders(BuildContext context, {required WebDavAccount account}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(DsPageRoute<void>(builder: (context) => WebDavFoldersPage(account: account)));
}

/// The server's folder page for one account.
final class WebDavFoldersPage extends ConsumerStatefulWidget {
  /// The page for [account].
  const WebDavFoldersPage({required this.account, super.key});

  /// The account whose server this page walks.
  final WebDavAccount account;

  @override
  ConsumerState<WebDavFoldersPage> createState() => _WebDavFoldersPageState();
}

final class _WebDavFoldersPageState extends ConsumerState<WebDavFoldersPage> {
  WebDavBackupClient? _client;

  /// The directory on screen, root-relative; `/` is the account's own folder.
  String _path = WebDavBackupClient.root;
  late Future<List<WebDavEntry>> _entries = _load(_path);
  bool _busy = false;

  Future<List<WebDavEntry>> _load(String path) async => await (await _ensureClient()).list(path: path);

  Future<WebDavBackupClient> _ensureClient() async => _client ??= await webDavClientFor(ref, widget.account);

  void _open(String path) => setState(() {
    _path = path;
    _entries = _load(path);
  });

  Future<void> _reload() async => _open(_path);

  /// The account root and every segment below it, in order, each with the
  /// path it opens.
  List<(String, String)> get _trial {
    final segments = _path.split('/').where((segment) => segment.isNotEmpty).toList();
    final trail = <(String, String)>[(context.t.backup.webdavRoot, WebDavBackupClient.root)];
    for (var index = 0; index < segments.length; index++) {
      final walked = '/${segments.take(index + 1).join('/')}';
      trail.add((segments[index], walked));
    }
    return trail;
  }

  /// Runs one server call with the toolbar greyed while it works.
  Future<void> _run(Future<void> Function(WebDavBackupClient client) work) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await work(await _ensureClient());
    } on Object catch (error) {
      if (mounted) _showFailure(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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

  Future<void> _newFolder() async {
    final t = context.t;
    final name = await _askText(title: t.backup.webdavNewFolder, hint: t.backup.webdavNewFolderName);
    if (name == null) return;
    if (name.isEmpty) {
      if (mounted) showDsToast(context: context, title: t.backup.webdavUploadInvalid);
      return;
    }
    await _run((client) async {
      await client.createFolder(_childPath(_path, name));
      if (!mounted) return;
      showDsToast(context: context, title: t.backup.webdavFolderCreated, status: DsStatus.success);
      unawaited(_reload());
    });
  }

  Future<void> _uploadHere() async {
    final t = context.t;
    final name = await _askText(
      title: t.backup.webdavUploadHere,
      initial: BackupDocument.exportFileName(DateTime.now()),
      hint: t.backup.webdavUploadName,
    );
    if (name == null) return;
    if (name.isEmpty) {
      if (mounted) showDsToast(context: context, title: t.backup.webdavUploadInvalid);
      return;
    }
    final document = await captureBackupDocument(ref);
    if (!mounted) return;
    if (document.isEmpty) {
      showDsToast(context: context, title: t.backup.exportEmpty);
      return;
    }
    await _run((client) async {
      await client.writeFile(_childPath(_path, name), utf8.encode(document.encode()));
      if (!mounted) return;
      showDsToast(context: context, title: t.backup.webdavUploadDone(file: name), status: DsStatus.success);
      unawaited(_reload());
    });
  }

  Future<void> _restore(WebDavEntry entry) async {
    final t = context.t;
    final document = await _readDocument(entry);
    if (!mounted) return;
    if (document == null) {
      showDsToast(context: context, title: t.backup.importBadData, status: DsStatus.danger);
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
    if (!confirmed) return;
    await applyBackup(ref, document);
    ref.invalidate(backupSummaryProvider);
    if (mounted) showDsToast(context: context, title: t.backup.webdavRestored, status: DsStatus.success);
  }

  /// Reads one remote file and parses it, through the busy guard.
  Future<BackupDocument?> _readDocument(WebDavEntry entry) async {
    BackupDocument? document;
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      final bytes = (await _ensureClient()).readFile(entry.path);
      document = BackupDocument.tryDecode(utf8.decode(await bytes, allowMalformed: true));
    } on Object catch (error) {
      if (mounted) _showFailure(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return document;
  }

  Future<void> _delete(WebDavEntry entry) async {
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
    if (!confirmed) return;
    await _run((client) async {
      await client.delete(entry);
      if (!mounted) return;
      showDsToast(context: context, title: t.backup.webdavDeleted, status: DsStatus.success);
      unawaited(_reload());
    });
  }

  /// One message per failure kind, the same words the sync page uses.
  void _showFailure(Object error) {
    final t = context.t;
    final message = switch (error) {
      WebDavFailure(problem: WebDavProblem.auth) => t.backup.webdavAuthFailed,
      WebDavFailure(problem: WebDavProblem.notFound) => t.backup.webdavNotFound,
      WebDavFailure(:final status?) => t.backup.webdavServerFailed(status: status),
      WebDavFailure() => t.backup.webdavNetworkFailed,
      StateError() => t.backup.webdavUrlMissing,
      _ => t.backup.webdavFailed,
    };
    showDsToast(context: context, title: message, status: DsStatus.danger);
  }

  /// `path` with one more segment; the root keeps its leading slash.
  static String _childPath(String path, String name) {
    final trimmed = name.trim().replaceAll('/', '');
    if (path == WebDavBackupClient.root) return '/$trimmed';
    return '${path.endsWith('/') ? path.substring(0, path.length - 1) : path}/$trimmed';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final busy = _busy;
    final trail = _trial;
    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s4),
              child: Row(
                spacing: DsSpace.s8,
                children: [
                  DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const DsIcon(DsIcons.chevronLeft),
                    semanticLabel: t.common.back,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.account.name.isEmpty ? widget.account.url : widget.account.name,
                          style: theme.typography.title.copyWith(color: colors.text),
                        ),
                        Text(
                          widget.account.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.small.copyWith(color: colors.textSubtle),
                        ),
                      ],
                    ),
                  ),
                  _ToolButton(
                    icon: DsIcons.refreshCw,
                    label: t.backup.webdavRefresh,
                    busy: busy,
                    onPressed: _reload,
                  ),
                  _ToolButton(
                    icon: DsIcons.folderPlus,
                    label: t.backup.webdavNewFolder,
                    busy: busy,
                    onPressed: _newFolder,
                  ),
                  _ToolButton(
                    icon: DsIcons.cloudUpload,
                    label: t.backup.webdavUploadHere,
                    busy: busy,
                    onPressed: _uploadHere,
                  ),
                ],
              ),
            ),
            // The breadcrumb is the page's address bar: every step is a
            // button, only the last one is where the viewer already is.
            Padding(
              padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s4, DsSpace.s16, DsSpace.s8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (index, step) in trail.indexed) ...[
                      if (index > 0)
                        DsIcon(DsIcons.chevronRight, size: 14, color: colors.textSubtle),
                      if (index == trail.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s6),
                          child: Text(
                            step.$1,
                            style: theme.typography.caption.copyWith(
                              color: colors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        DsButton(
                          variant: DsButtonVariant.ghost,
                          size: DsSize.sm,
                          onPressed: busy ? null : () => _open(step.$2),
                          child: Text(step.$1),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<WebDavEntry>>(
                future: _entries,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24)));
                  }
                  if (snapshot.hasError) {
                    return DsEmptyState(
                      icon: const DsIcon(DsIcons.cloudOff),
                      title: Text(t.backup.webdavLoadFailed),
                      description: Text('${snapshot.error}'),
                      actions: [DsButton(onPressed: _reload, child: Text(t.common.retry))],
                    );
                  }
                  final entries = snapshot.data ?? const <WebDavEntry>[];
                  if (entries.isEmpty) {
                    return DsEmptyState(
                      icon: const DsIcon(DsIcons.folderOpen),
                      title: Text(t.backup.webdavEmpty),
                      actions: [
                        DsButton(onPressed: _newFolder, child: Text(t.backup.webdavNewFolder)),
                      ],
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(DsSpace.s16, 0, DsSpace.s16, DsSpace.s16),
                    children: [
                      DsListSection(
                        children: [
                          for (final entry in entries)
                            DsListRow(
                              leading: DsIcon(entry.isDirectory ? DsIcons.folder : DsIcons.fileBraces),
                              title: Text(entry.name),
                              description: Text(
                                entry.isDirectory
                                    ? t.backup.webdavEnterFolder
                                    : [
                                        if (entry.size case final size?) formatBackupSize(size),
                                        if (entry.modified case final modified?) formatBackupTime(modified),
                                      ].join(' · '),
                              ),
                              onPressed: entry.isDirectory
                                  ? () => _open(entry.path)
                                  : () => unawaited(_restore(entry)),
                              trailing: DsButton.icon(
                                variant: DsButtonVariant.ghost,
                                size: DsSize.sm,
                                semanticLabel: t.backup.webdavFileDelete,
                                onPressed: busy ? null : () => unawaited(_delete(entry)),
                                icon: const DsIcon(DsIcons.trash2, size: 16),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One toolbar action: an icon button with a label under the page's rhythm,
/// disabled while a server call is running.
final class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.label, required this.busy, required this.onPressed});

  final DsIconData icon;
  final String label;
  final bool busy;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return DsButton.icon(
      variant: DsButtonVariant.ghost,
      size: DsSize.sm,
      semanticLabel: label,
      onPressed: busy ? null : onPressed,
      icon: DsIcon(icon, size: 18),
    );
  }
}
