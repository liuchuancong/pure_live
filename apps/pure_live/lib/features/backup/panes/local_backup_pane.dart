import 'dart:async' show unawaited;
import 'dart:io' show Directory, FileSystemException;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/backup/document/backup_document.dart';
import 'package:pure_live/features/backup/document/backup_repository.dart';
import 'package:pure_live/features/backup/panes/backup_actions.dart';
import 'package:pure_live/features/backup/panes/backup_section_picker.dart';
import 'package:pure_live/features/backup/panes/restore_preview_dialog.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/widgets/app_dialog.dart';

/// The one action running: the other rows grey out and the running row
/// spins until it settles.
enum _BackupAction { createAll, createFollows, folder, openFolder, restoreFile, deleteFile }

/// The local backup page, one of the four ways under Backup and restore:
/// the document written as a file in a local backup folder — the sections
/// the user picked, or the follows alone in one tap — the folder itself,
/// and what it holds (newest first), each file restored or deleted behind
/// a confirm; a restore asks which of the file's sections to take, then
/// shows what taking them changes before it writes anything.
///
/// Public for the settings surface to embed; the page owns nothing beyond
/// its own busy and folder state. The secrets switch lives on the hub page
/// above, since every way honours it.
final class LocalBackupPane extends ConsumerStatefulWidget {
  /// The local backup pane.
  const LocalBackupPane({super.key});

  @override
  ConsumerState<LocalBackupPane> createState() => _LocalBackupPaneState();
}

final class _LocalBackupPaneState extends ConsumerState<LocalBackupPane> {
  _BackupAction? _busy;
  String? _busyPath;
  String? _folder;
  bool _customFolder = false;
  List<LocalBackupFile>? _files;
  bool _filesFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFolder());
  }

  void _toast(String message) => showDsToast(context: context, title: message);

  /// Runs one action at a time: the running row spins, the rest grey out,
  /// and every failure becomes the one message the pane keeps for it.
  /// [path] marks the backup file a restore or delete is working on.
  Future<void> _run(_BackupAction action, Future<void> Function() work, {String? path}) async {
    final t = context.t;
    if (_busy != null) {
      _toast(t.backup.busy);
      return;
    }
    setState(() {
      _busy = action;
      _busyPath = path;
    });
    try {
      await work();
    } on Object catch (error) {
      if (mounted) _toast(_failureMessage(action, error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = null;
          _busyPath = null;
        });
      }
    }
  }

  String _failureMessage(_BackupAction action, Object error) {
    final t = context.t;
    // A refusal of its own: the pane says why the data was left alone.
    if (error is BackupRestoreBusy) return t.backup.restoreBusy;
    if (error is BackupRecordingsBusy) return t.backup.restoreRecordingsBusy;
    if (error is BackupDocumentEmpty) return t.backup.restoreEmptyDocument;
    return switch (action) {
      _BackupAction.createAll || _BackupAction.createFollows => t.backup.createFailed,
      _BackupAction.folder => t.backup.folderSaveFailed,
      _BackupAction.openFolder => t.backup.openFolderFailed,
      _BackupAction.restoreFile => t.backup.restoreFailed,
      _BackupAction.deleteFile => t.backup.deleteFileFailed,
    };
  }

  // -- Local backup folder ------------------------------------------------

  /// The chosen folder (from prefs) or the default one, then its backups.
  Future<void> _loadFolder() async {
    final saved = storedBackupFolder();
    final folder = saved.isNotEmpty ? saved : ref.read(appPathsProvider).backups.path;
    if (!mounted) return;
    setState(() {
      _folder = folder;
      _customFolder = saved.isNotEmpty;
    });
    await _loadFiles();
  }

  Future<void> _loadFiles() async {
    final folder = _folder;
    if (folder == null) return;
    if (_filesFailed) {
      setState(() {
        _files = null;
        _filesFailed = false;
      });
    }
    List<LocalBackupFile> files;
    var failed = false;
    try {
      files = await listBackupFiles(Directory(folder));
    } on FileSystemException {
      files = const [];
      failed = true;
    }
    if (!mounted || folder != _folder) return;
    setState(() {
      _files = files;
      _filesFailed = failed;
    });
  }

  Future<void> _chooseFolder() async {
    final t = context.t;
    if (_busy != null) {
      _toast(t.backup.busy);
      return;
    }
    final path = await pickBackupDirectory(dialogTitle: t.backup.folderPickTitle, initialDirectory: _folder);
    if (path == null || !mounted) return;
    await _run(_BackupAction.folder, () async {
      if (!await ensureWritableFolder(Directory(path))) {
        _toast(t.backup.folderUnwritable);
        return;
      }
      await storeBackupFolder(path);
      if (!mounted) return;
      setState(() {
        _folder = path;
        _customFolder = true;
        _files = null;
      });
      await _loadFiles();
    });
  }

  Future<void> _resetFolder() => _run(_BackupAction.folder, () async {
    await storeBackupFolder('');
    await _loadFolder();
  });

  Future<void> _openFolder() => _run(_BackupAction.openFolder, () async {
    final folder = _folder;
    if (folder == null) return;
    await openBackupFolder(Directory(folder));
  });

  // -- Local backup files -------------------------------------------------

  /// Asks which sections to write, then writes them. [preset] skips the
  /// question: the follows-only row writes rooms and areas in one tap.
  Future<void> _create({Set<BackupSection>? preset}) async {
    final t = context.t;
    if (_busy != null) {
      _toast(t.backup.busy);
      return;
    }
    var sections = preset;
    if (sections == null) {
      sections = await showBackupSectionPicker(
        context,
        title: t.backup.pickCreateTitle,
        confirmLabel: t.backup.createTitle,
        available: BackupSection.values.toSet(),
        counts: ref.read(backupSummaryProvider).value ?? const {},
        secretsAllowed: includeSecretsAllowed(),
      );
      if (sections == null || !mounted) return;
    }
    final chosen = sections;
    final followsOnly = preset == BackupSection.followsOnly;
    await _run(followsOnly ? _BackupAction.createFollows : _BackupAction.createAll, () async {
      final folder = _folder;
      if (folder == null) return;
      final document = await captureBackupDocument(ref, sections: chosen);
      if (document.isEmpty) {
        _toast(t.backup.exportEmpty);
        return;
      }
      try {
        final file = await writeBackupDocument(Directory(folder), document);
        await _loadFiles();
        if (mounted) _toast(t.backup.createDone(name: file.uri.pathSegments.last));
      } on FileSystemException {
        if (mounted) _toast(t.backup.folderUnwritable);
      }
    });
  }

  /// Reads the file, asks which of its sections to take, shows what taking
  /// them changes on this device, then restores exactly those.
  Future<void> _restoreFile(LocalBackupFile entry) async {
    final t = context.t;
    if (_busy != null) {
      _toast(t.backup.busy);
      return;
    }
    // A restore another page started is still writing: say so before the
    // file is even read, not after the user picked and confirmed.
    if (restoreInProgress(ref)) {
      _toast(t.backup.restoreBusy);
      return;
    }
    final chosen = await _pickRestore(entry);
    if (chosen == null || !mounted) return;
    await _run(_BackupAction.restoreFile, () async {
      await applyBackup(ref, chosen);
      ref.invalidate(backupSummaryProvider);
      if (mounted) _toast(t.backup.importDone);
    }, path: entry.file.path);
  }

  /// Reads [entry] and takes it through the picker and the preview: the
  /// document to restore, or null when the user backed out or the file was
  /// no backup (the pane has said why).
  Future<BackupDocument?> _pickRestore(LocalBackupFile entry) async {
    final t = context.t;
    try {
      final document = await readBackupDocument(entry.file);
      if (!mounted) return null;
      if (document == null) {
        _toast(t.backup.importBadData);
        return null;
      }
      return await pickAndPreviewRestore(
        context,
        ref,
        document: document,
        name: entry.name,
        title: t.backup.pickRestoreTitle(name: entry.name),
      );
    } on Object {
      // The file could not be read, or the stores to compare it with did
      // not open: nothing was written.
      if (mounted) _toast(t.backup.restoreFailed);
      return null;
    }
  }

  Future<void> _deleteFile(LocalBackupFile entry) async {
    final t = context.t;
    if (_busy != null) {
      _toast(t.backup.busy);
      return;
    }
    final confirmed = await _confirm(
      t.backup.deleteConfirmTitle,
      description: t.backup.deleteConfirmDesc(name: entry.name),
    );
    if (!confirmed || !mounted) return;
    await _run(_BackupAction.deleteFile, () async {
      await deleteBackupFile(entry.file);
      await _loadFiles();
      if (mounted) _toast(t.backup.deleteDone);
    }, path: entry.file.path);
  }

  // -- Dialogs ------------------------------------------------------------

  Future<bool> _confirm(String title, {required String description}) => showAppConfirm(
    context: context,
    title: title,
    description: description,
    confirmLabel: context.t.common.confirm,
    cancelLabel: context.t.common.cancel,
    destructive: true,
  );

  // -- Build --------------------------------------------------------------

  /// One backup file: name, "time · size · kind"; a tap restores it after
  /// a confirm, the trailing bin deletes it after one.
  Widget _fileRow(LocalBackupFile entry) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final busy = _busy;
    final fileAction = busy == _BackupAction.restoreFile || busy == _BackupAction.deleteFile;
    final thisRow = fileAction && _busyPath == entry.file.path;
    return DsListRow(
      key: ValueKey(entry.file.path),
      leading: DsIcon(entry.followsOnly ? DsIcons.heart : DsIcons.fileBraces),
      title: Text(entry.name),
      description: Text(
        t.backup.fileMeta(
          time: formatBackupTime(entry.modified),
          size: formatBackupSize(entry.size),
          kind: entry.followsOnly ? t.backup.kindFollows : t.backup.kindFull,
        ),
      ),
      onPressed: busy == null ? () => unawaited(_restoreFile(entry)) : null,
      trailing: thisRow
          ? const DsSpinner()
          : DsPressable(
              semanticLabel: t.backup.fileDelete,
              onPressed: busy == null ? () => unawaited(_deleteFile(entry)) : null,
              builder: (context, states, _) => DsIcon(
                DsIcons.trash2,
                size: 16,
                color: (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused))
                    ? colors.danger.text
                    : colors.textSubtle,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final files = _files;
    final opensFolder = ref.watch(deviceProfileProvider).isDesktop;
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
              leading: const DsIcon(DsIcons.archive),
              title: Text(t.backup.createTitle),
              description: Text(t.backup.createDescription),
              onPressed: _folder != null && free(_BackupAction.createAll) ? () => unawaited(_create()) : null,
              trailing: spinner(_BackupAction.createAll),
              showChevron: true,
            ),
            DsListRow(
              leading: const DsIcon(DsIcons.heart),
              title: Text(t.backup.createFollowsTitle),
              description: Text(t.backup.createFollowsDescription),
              onPressed: _folder != null && free(_BackupAction.createFollows)
                  ? () => unawaited(_create(preset: BackupSection.followsOnly))
                  : null,
              trailing: spinner(_BackupAction.createFollows),
            ),
          ],
        ),
        // Where the files land is its own subject: a folder, its way back
        // and the way into it, not another backup action.
        DsListSection(
          header: Text(t.backup.folderSection),
          children: [
            DsListRow(
              leading: const DsIcon(DsIcons.folder),
              title: Text(_customFolder ? t.backup.folderTitle : t.backup.folderDefault),
              detail: Text(_folder ?? t.backup.folderLoading),
              onPressed: free(_BackupAction.folder) ? () => unawaited(_chooseFolder()) : null,
              trailing: spinner(_BackupAction.folder),
              showChevron: true,
            ),
            if (_customFolder)
              DsListRow(
                leading: const DsIcon(DsIcons.rotateCcw),
                title: Text(t.backup.folderReset),
                onPressed: free(_BackupAction.folder) ? () => unawaited(_resetFolder()) : null,
              ),
            if (opensFolder)
              DsListRow(
                leading: const DsIcon(DsIcons.folderOpen),
                title: Text(t.backup.folderOpen),
                onPressed: _folder != null && free(_BackupAction.openFolder) ? () => unawaited(_openFolder()) : null,
                trailing: spinner(_BackupAction.openFolder),
              ),
          ],
        ),
        DsListSection(
          header: Text(
            files == null || files.isEmpty ? t.backup.filesSection : t.backup.filesCount(count: files.length),
          ),
          children: [
            if (files == null)
              DsListRow(
                leading: const DsIcon(DsIcons.fileBraces),
                title: Text(t.backup.folderLoading),
                trailing: const DsSpinner(),
              )
            else if (_filesFailed)
              DsListRow(
                leading: const DsIcon(DsIcons.circleAlert),
                title: Text(t.backup.filesFailed),
                description: Text(t.backup.filesFailedHint),
                onPressed: busy == null ? () => unawaited(_loadFiles()) : null,
                trailing: const DsIcon(DsIcons.refreshCw),
              )
            else if (files.isEmpty)
              DsListRow(leading: const DsIcon(DsIcons.fileBraces), title: Text(t.backup.filesEmpty))
            else
              for (final entry in files) _fileRow(entry),
          ],
        ),
      ],
    );
  }
}
