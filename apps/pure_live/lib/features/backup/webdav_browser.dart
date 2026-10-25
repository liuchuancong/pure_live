import 'dart:async' show unawaited;
import 'dart:convert' show utf8;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/features/backup/backup_actions.dart'
    show applyBackup, captureBackupDocument, formatBackupSize, formatBackupTime, webDavClient;
import 'package:pure_live/features/backup/backup_document.dart';
import 'package:pure_live/features/backup/backup_repository.dart' show backupSummaryProvider;
import 'package:pure_live/features/backup/webdav_client.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/widgets/app_loading_indicator.dart';

/// Opens the server's own folder browser: walk collections, upload the
/// current backup under a chosen name, restore any file, or delete one.
/// The fixed-name upload/download rows stay for the one-click path.
Future<void> showWebDavBrowser(BuildContext context) => showDsPanel<void>(
  context: context,
  builder: (context) => DsPanel(
    title: Text(context.t.backup.webdavBrowse),
    // The list is the scroller; the panel gives it the room between header
    // and footer.
    scrollable: false,
    child: const _WebDavBrowser(),
  ),
);

final class _WebDavBrowser extends ConsumerStatefulWidget {
  const _WebDavBrowser();

  @override
  ConsumerState<_WebDavBrowser> createState() => _WebDavBrowserState();
}

final class _WebDavBrowserState extends ConsumerState<_WebDavBrowser> {
  WebDavBackupClient? _client;
  Uri? _directory;
  late Future<List<WebDavEntry>> _future = _load();

  Future<List<WebDavEntry>> _load() async {
    final client = _client ?? await webDavClient(ref);
    _client = client;
    final directory = _directory ?? client.directory;
    _directory = directory;
    return await client.list(directory: directory);
  }

  Future<List<WebDavEntry>> _loadFrom(Uri directory) async {
    final client = _client ?? await webDavClient(ref);
    _client = client;
    _directory = directory;
    return await client.list(directory: directory);
  }

  void _open(Uri directory) => setState(() => _future = _loadFrom(directory));

  void _reload() => setState(() => _future = _loadFrom(_directory ?? _client!.directory));

  /// The parent collection, never above the configured base.
  Uri? get _parent {
    final client = _client;
    final current = _directory;
    if (client == null || current == null) return null;
    final base = client.directory;
    var path = current.path;
    if (!path.endsWith('/')) path = '$path/';
    if (path == base.path || path.length <= base.path.length) return null;
    final trimmed = path.substring(0, path.length - 1);
    final cut = trimmed.lastIndexOf('/');
    final parent = current.replace(path: cut <= 0 ? '/' : '${trimmed.substring(0, cut)}/');
    return parent.path.startsWith(base.path) ? parent : null;
  }

  Future<void> _upload() async {
    final t = context.t;
    final field = TextEditingController(text: BackupDocument.exportFileName(DateTime.now()));
    final name = await showDsDialog<String>(
      context: context,
      builder: (context) => DsDialog(
        title: Text(t.backup.webdavUploadHere),
        icon: const DsIcon(DsIcons.cloudUpload),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s8,
          children: [
            Text(t.backup.webdavUploadName),
            DsTextField(
              controller: field,
              autofocus: true,
              clearable: true,
              placeholder: BackupDocument.backupFileName,
              semanticLabel: t.backup.webdavUploadName,
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
            onPressed: () => Navigator.of(context).pop(field.text.trim()),
            child: Text(t.backup.webdavUploadHere),
          ),
        ],
      ),
    );
    field.dispose();
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
    final directory = _directory ?? _client!.directory;
    try {
      await _client!.uploadFile(directory.resolve(name), utf8.encode(document.encode()));
      if (!mounted) return;
      showDsToast(
        context: context,
        title: t.backup.webdavUploadDone(file: name),
        status: DsStatus.success,
      );
      _reload();
    } on Object catch (error) {
      if (mounted) _showFailure(error);
    }
  }

  Future<void> _restore(WebDavEntry entry) async {
    final t = context.t;
    try {
      final bytes = await _client!.downloadFile(entry.uri);
      final document = BackupDocument.tryDecode(utf8.decode(bytes, allowMalformed: true));
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
      if (mounted) {
        showDsToast(context: context, title: t.backup.webdavRestored, status: DsStatus.success);
      }
    } on Object catch (error) {
      if (mounted) _showFailure(error);
    }
  }

  Future<void> _delete(WebDavEntry entry) async {
    final t = context.t;
    final confirmed = await showDsConfirm(
      context: context,
      title: t.backup.webdavDeleteTitle(name: entry.name),
      description: t.backup.webdavDeleteDesc,
      confirmLabel: t.common.delete,
      cancelLabel: t.common.cancel,
      destructive: true,
      icon: const DsIcon(DsIcons.trash2),
    );
    if (!confirmed) return;
    try {
      await _client!.deleteFile(entry.uri);
      if (!mounted) return;
      showDsToast(context: context, title: t.backup.webdavDeleted, status: DsStatus.success);
      _reload();
    } on Object catch (error) {
      if (mounted) _showFailure(error);
    }
  }

  /// One toast for a WebDAV failure, in the pane's own words.
  void _showFailure(Object error) {
    final t = context.t;
    final message = switch (error) {
      WebDavFailure(problem: WebDavProblem.auth) => t.backup.webdavAuthFailed,
      WebDavFailure(problem: WebDavProblem.notFound) => t.backup.webdavNotFound,
      WebDavFailure(:final status?) => t.backup.webdavServerFailed(status: status),
      WebDavFailure() => t.backup.webdavNetworkFailed,
      StateError() => t.backup.webdavNoServer,
      _ => t.backup.webdavFailed,
    };
    showDsToast(context: context, title: message, status: DsStatus.danger);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final parent = _parent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          spacing: DsSpace.s8,
          children: [
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              size: DsSize.sm,
              semanticLabel: t.backup.webdavUp,
              onPressed: parent == null ? null : () => _open(parent),
              icon: const DsIcon(DsIcons.arrowUp),
            ),
            Expanded(
              child: Text(
                Uri.decodeFull(_directory?.path ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(color: colors.textMuted),
              ),
            ),
            DsButton.icon(
              variant: DsButtonVariant.ghost,
              size: DsSize.sm,
              semanticLabel: t.backup.webdavUploadHere,
              onPressed: _directory == null ? null : () => unawaited(_upload()),
              icon: const DsIcon(DsIcons.cloudUpload),
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<WebDavEntry>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: AppLoadingIndicator(size: 24));
              }
              if (snapshot.hasError) {
                return DsEmptyState(
                  icon: const DsIcon(DsIcons.cloudOff),
                  title: Text(t.backup.webdavLoadFailed),
                  description: Text('${snapshot.error}'),
                  actions: [
                    DsButton(
                      onPressed: _client == null ? () => setState(() => _future = _load()) : _reload,
                      child: Text(t.common.retry),
                    ),
                  ],
                );
              }
              final entries = snapshot.data ?? const <WebDavEntry>[];
              if (entries.isEmpty) {
                return DsEmptyState(icon: const DsIcon(DsIcons.folderOpen), title: Text(t.backup.webdavEmpty));
              }
              return ListView(
                children: [
                  DsListSection(
                    children: [
                      for (final entry in entries)
                        DsListRow(
                          leading: DsIcon(entry.isDirectory ? DsIcons.folder : DsIcons.fileBraces),
                          title: Text(entry.name),
                          description: entry.isDirectory ? null : Text(_metaOf(entry)),
                          onPressed: entry.isDirectory ? () => _open(entry.uri) : () => unawaited(_restore(entry)),
                          trailing: entry.isDirectory
                              ? const DsIcon(DsIcons.chevronRight)
                              : DsButton.icon(
                                  variant: DsButtonVariant.ghost,
                                  size: DsSize.sm,
                                  semanticLabel: t.backup.webdavFileDelete,
                                  onPressed: () => unawaited(_delete(entry)),
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
    );
  }

  /// A file's size and time, whichever the server gave.
  static String _metaOf(WebDavEntry entry) => [
    if (entry.size case final size?) formatBackupSize(size),
    if (entry.modified case final modified?) formatBackupTime(modified),
  ].join(' · ');
}
