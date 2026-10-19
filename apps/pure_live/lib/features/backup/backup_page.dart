import 'dart:async' show unawaited;
import 'dart:io';

import 'package:file_picker/file_picker.dart' show FilePickerPlatform;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:open_file/open_file.dart';
import 'package:pure_live/app/environment/app_directory.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/backup/backup_archive.dart';
import 'package:pure_live/features/backup/backup_documents.dart';
import 'package:pure_live/features/backup/web_dav_page.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:restart_app/restart_app.dart';

/// Which row of the page is running; one backup action at a time (the
/// reference's `_Action` set): the running one spins, the others grey out.
enum _Action { create, createFollows, restoreFile, folder, resetFolder, files, delete }

/// Backup and restore (3.x `BackupPage`, docs/A12.4): the ways to other
/// devices first, then the local backups — a full zip of the data area and
/// a follows-only JSON document (the reference's two scopes) — then the
/// backups found in the folder (a tap restores a follows document after a
/// count preview, a zip after the overwrite-and-restart ask), and the
/// folder itself (choose, reset to the app default, open on desktop).
///
/// The two formats are this app's own: the zip copies every box file the
/// data area holds (the reference's whole-directory semantics), the JSON
/// document carries the follow rooms and groups exactly as the follow page
/// stores them, so a follows backup restores live without a restart.
final class BackupPage extends ConsumerStatefulWidget {
  /// The backup page.
  const new({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

final class _BackupPageState extends ConsumerState<BackupPage> {
  _Action? _busy;
  String? _folder;
  List<BackupEntry>? _files;
  bool _filesFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFolder());
  }

  /// The chosen folder (the stored 备份目录) or the app's own backups tree.
  Future<void> _loadFolder() async {
    final custom = ref.read(appPreferencesProvider).backupDirectory.trim();
    final folder = custom.isNotEmpty ? custom : (await _defaultFolder()).path;
    if (!mounted) {
      return;
    }
    setState(() => _folder = folder);
    await _loadFiles();
  }

  Future<Directory> _defaultFolder() => ref.read(pathsProvider).directory(AppDirectory.backups);

  Future<void> _loadFiles() async {
    final folder = _folder;
    if (folder == null) {
      return;
    }
    List<BackupEntry> files;
    var failed = false;
    try {
      files = listBackups(Directory(folder));
    } on FileSystemException {
      files = const [];
      failed = true;
    }
    if (!mounted || folder != _folder) {
      return;
    }
    setState(() {
      _files = files;
      _filesFailed = failed;
    });
  }

  /// Runs one action at a time; the row shows its progress.
  Future<void> _run(_Action action, Future<void> Function() work) async {
    if (_busy != null) {
      return;
    }
    setState(() => _busy = action);
    try {
      await work();
    } finally {
      if (mounted) {
        setState(() => _busy = null);
      }
    }
  }

  bool _usable(_Action action) => _busy == null || _busy == action;

  Future<void> _create() => _run(_Action.create, () async {
    final folder = _folder;
    if (folder == null) {
      return;
    }
    final data = await ref.read(pathsProvider).directory(AppDirectory.data);
    if (!mounted) {
      return;
    }
    try {
      final file = createBackup(dataDir: data, backupsDir: Directory(folder));
      _done(context.t.backup.created(name: _baseName(file.path)));
    } on Object {
      _fail(context.t.backup.directoryUnwritable);
    }
    await _loadFiles();
  });

  /// The 仅导出关注列表 action: the rooms and groups as one JSON document.
  Future<void> _createFollows() => _run(_Action.createFollows, () async {
    final folder = _folder;
    if (folder == null) {
      return;
    }
    final repository = ref.read(followRepositoryProvider);
    await repository.load();
    if (!mounted) {
      return;
    }
    try {
      final file = writeFollowsBackup(folder: Directory(folder), document: buildFollowsDocument(repository));
      _done(context.t.backup.created(name: _baseName(file.path)));
    } on Object {
      _fail(context.t.backup.directoryUnwritable);
    }
    await _loadFiles();
  });

  Future<void> _restoreFromFile() async {
    if (_busy != null) {
      return;
    }
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'backup', extensions: ['zip', 'json']),
      ],
    );
    if (file == null) {
      return;
    }
    final picked = File(file.path);
    if (!picked.existsSync()) {
      if (mounted) {
        PureToast.show(context, context.t.backup.readFailed, type: PureToastType.error);
      }
      return;
    }
    final stat = picked.statSync();
    await _restore(
      BackupEntry(
        file: picked,
        name: _baseName(picked.path),
        modified: stat.modified,
        size: stat.size,
        followsOnly: file.path.toLowerCase().endsWith('.json'),
      ),
    );
  }

  /// Restores one file. A follows document is previewed by counts and
  /// written through the repository (no restart — nothing open on disk is
  /// overwritten); a zip overwrites the data area, which is why the
  /// reference's own answer there is the restart.
  Future<void> _restore(BackupEntry entry) => _run(_Action.files, () async {
    if (!entry.followsOnly) {
      await _restoreZip(entry);
      return;
    }
    final FollowsBackup backup;
    try {
      final parsed = FollowsBackup.tryParse(readBackupDocument(entry.file));
      if (parsed == null) {
        PureToast.show(context, context.t.backup.readFailed, type: PureToastType.error);
        return;
      }
      backup = parsed;
    } on Object {
      PureToast.show(context, context.t.backup.readFailed, type: PureToastType.error);
      return;
    }
    final repository = ref.read(followRepositoryProvider);
    await repository.load();
    if (!mounted) {
      return;
    }
    final go = await _confirmPreview(
      entry: entry,
      currentRooms: repository.rooms.length,
      incomingRooms: backup.rooms.length,
      currentGroups: repository.groups.length,
      incomingGroups: backup.groups.length,
    );
    if (!go) {
      return;
    }
    await repository.replaceAll(rooms: backup.rooms, groups: backup.groups);
    if (!mounted) {
      return;
    }
    _done(context.t.backup.restored(name: entry.name));
  });

  Future<void> _restoreZip(BackupEntry entry) async {
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: context.t.backup.restore,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        child: Text('${context.t.backup.restoreConfirm(name: entry.name)}\n${context.t.backup.restoreFileSubtitle}'),
      ),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          label: dialogContext.t.backup.restore,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed != true) {
      return;
    }
    final data = await ref.read(pathsProvider).directory(AppDirectory.data);
    restoreBackup(backup: entry.file, dataDir: data);
    await Restart.restartApp();
  }

  /// The preview of a follows restore (the reference's per-part count line,
  /// cut to the two parts this document carries).
  Future<bool> _confirmPreview({
    required BackupEntry entry,
    required int currentRooms,
    required int incomingRooms,
    required int currentGroups,
    required int incomingGroups,
  }) async {
    final t = context.t;
    final theme = PureTheme.of(context);
    final go = await showPureDialog<bool>(
      context: context,
      title: t.backup.previewTitle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
        child: Column(
          key: const ValueKey('backup-preview'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(entry.name, style: theme.text.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text(t.backup.previewRooms(current: '$currentRooms', incoming: '$incomingRooms')),
            Text(t.backup.previewGroups(current: '$currentGroups', incoming: '$incomingGroups')),
            const SizedBox(height: 8),
            Text(t.backup.previewNote, style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
          ],
        ),
      ),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          key: const ValueKey('backup-restore-confirm'),
          label: dialogContext.t.backup.restoreNow,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    return go ?? false;
  }

  Future<void> _delete(BackupEntry entry) async {
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: context.t.backup.delete,
      child: Text(context.t.backup.deleteConfirm(name: entry.name)),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          key: const ValueKey('backup-delete-confirm'),
          label: dialogContext.t.backup.delete,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (!(confirmed ?? false)) {
      return;
    }
    await _run(_Action.delete, () async {
      try {
        deleteBackup(entry);
      } on FileSystemException {
        if (mounted) {
          PureToast.show(context, context.t.backup.deleteFailed, type: PureToastType.error);
        }
      }
      await _loadFiles();
    });
  }

  Future<void> _chooseFolder() => _run(_Action.folder, () async {
    final folder = _folder;
    if (folder == null) {
      return;
    }
    final selected = await FilePickerPlatform.instance.getDirectoryPath(
      dialogTitle: context.t.backup.chooseDirectory,
      initialDirectory: folder,
    );
    if (selected == null || selected == folder || !mounted || !Directory(selected).existsSync()) {
      return;
    }
    await ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(backupDirectory: selected));
    setState(() {
      _folder = selected;
      _files = null;
      _filesFailed = false;
    });
    await _loadFiles();
  });

  Future<void> _resetFolder() => _run(_Action.resetFolder, () async {
    await ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(backupDirectory: ''));
    await _loadFolder();
  });

  Future<void> _openFolder() async {
    final folder = _folder;
    if (folder == null) {
      return;
    }
    try {
      final result = await OpenFile.open(folder);
      if (result.type != ResultType.done && mounted) {
        PureToast.show(context, context.t.recorder.folderNotOpened, type: PureToastType.error);
      }
    } on Object {
      if (mounted) {
        PureToast.show(context, context.t.recorder.folderNotOpened, type: PureToastType.error);
      }
    }
  }

  void _done(String message) {
    if (mounted) {
      PureToast.show(context, message, type: PureToastType.success);
    }
  }

  void _fail(String message) {
    if (mounted) {
      PureToast.show(context, message, type: PureToastType.error);
    }
  }

  static String _baseName(String path) => path.split(Platform.pathSeparator).last;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final folder = _folder;
    final files = _files;
    final isDesktop = switch (ref.watch(environmentProvider).runtime.kind) {
      PlatformKind.windows || PlatformKind.macos || PlatformKind.linux => true,
      _ => false,
    };
    final custom = ref.watch(appPreferencesProvider).backupDirectory.trim().isNotEmpty;
    return PureScaffold(
      appBar: PureAppBar(title: t.backup.title),
      body: RefreshIndicator(
        onRefresh: _loadFiles,
        child: SettingsList(
          sections: [
            SettingsSection(
              title: Text(t.backup.devicesGroup),
              tiles: [
                SettingsTile.navigation(
                  key: const Key('backup-webdav'),
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(_webdavText('entryTitle')),
                  description: Text(_webdavText('entrySubtitle')),
                  enabled: _busy == null,
                  // The WebDAV page is its own route class; this page reaches it
                  // the same way it reaches the archive: a push above the shell.
                  onPressed: (_) =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WebDavPage())),
                ),
                SettingsTile.navigation(
                  key: const Key('backup-remote-sync'),
                  leading: const Icon(Icons.sync_outlined),
                  title: Text(t.settings.remoteSync),
                  description: Text(t.settings.remoteSyncSubtitle),
                  onPressed: (_) => unawaited(context.push<void>(RoutePath.remoteSync)),
                ),
                SettingsTile.navigation(
                  key: const Key('backup-account'),
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(t.account.title),
                  description: Text(t.settings.accountSubtitle),
                  onPressed: (_) => unawaited(const AccountRoute().push<void>(context)),
                ),
              ],
            ),
            SettingsSection(
              title: Text(t.backup.localGroup),
              tiles: [
                _actionTile(
                  key: 'backup-create',
                  action: _Action.create,
                  icon: Icons.backup_outlined,
                  title: t.backup.create,
                  subtitle: t.backup.createSubtitle,
                  onTap: () => unawaited(_create()),
                ),
                _actionTile(
                  key: 'backup-restore',
                  action: _Action.restoreFile,
                  icon: Icons.file_open_outlined,
                  title: t.backup.restoreFile,
                  subtitle: t.backup.restoreFileSubtitle,
                  onTap: () => unawaited(_restoreFromFile()),
                ),
                _actionTile(
                  key: 'backup-create-follows',
                  action: _Action.createFollows,
                  icon: Icons.bookmark_add_outlined,
                  title: t.backup.kindFollows,
                  subtitle: t.backup.followsScopeHint,
                  onTap: () => unawaited(_createFollows()),
                ),
              ],
            ),
            SettingsSection(
              title: Text(
                files == null || files.isEmpty ? t.backup.filesTitle : t.backup.filesCount(count: files.length),
              ),
              tiles: [
                if (_filesFailed)
                  SettingsTile(
                    key: const Key('backup-files-error'),
                    leading: Icon(Icons.error_outline, color: PureTheme.of(context).colors.error),
                    title: Text(t.backup.filesError),
                    description: Text(t.backup.filesHint),
                    trailing: PureButton(
                      key: const ValueKey('backup-files-retry'),
                      label: t.backup.retry,
                      size: ControlSize.sm,
                      variant: ButtonVariant.ghost,
                      onPressed: () => unawaited(_loadFiles()),
                    ),
                  )
                else if (files == null)
                  SettingsTile(leading: const PureSpinner(size: 20), title: Text(t.backup.loading))
                else if (files.isEmpty)
                  SettingsTile(
                    key: const Key('backup-files-empty'),
                    leading: const Icon(Icons.folder_open_outlined),
                    title: Text(t.backup.filesEmpty),
                    description: Text(t.backup.filesHint),
                  )
                else
                  for (final entry in files) _fileTile(entry),
              ],
            ),
            SettingsSection(
              title: Text(t.backup.directoryGroup),
              tiles: [
                SettingsTile.navigation(
                  key: const Key('backup-folder'),
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(custom ? t.backup.directory : t.backup.directoryDefaultLabel),
                  description: Text(folder ?? t.backup.loading),
                  enabled: _usable(_Action.folder),
                  onPressed: (_) => unawaited(_chooseFolder()),
                ),
                if (custom)
                  SettingsTile.navigation(
                    key: const Key('backup-folder-reset'),
                    leading: const Icon(Icons.restore_outlined),
                    title: Text(t.backup.resetDirectory),
                    enabled: _busy == null,
                    onPressed: (_) => unawaited(_resetFolder()),
                  ),
                if (folder != null && isDesktop)
                  SettingsTile.navigation(
                    key: const Key('backup-open-folder'),
                    leading: const Icon(Icons.drive_file_move_outlined),
                    title: Text(t.backup.openDirectory),
                    onPressed: (_) => unawaited(_openFolder()),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  SettingsTile _actionTile({
    required String key,
    required _Action action,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => SettingsTile.navigation(
    key: Key(key),
    leading: _busy == action ? const PureSpinner(size: 20) : Icon(icon),
    title: Text(title),
    description: Text(subtitle),
    enabled: _usable(action),
    onPressed: (_) => onTap(),
  );

  /// A backup in the folder: name, "time · size · kind"; the tap restores
  /// (preview for a follows document, the overwrite ask for a zip) and ⋮
  /// carries the same actions apart from deleting.
  SettingsTile _fileTile(BackupEntry entry) {
    final t = context.t;
    // The reference's row line: "time · size · kind".
    final kind = entry.followsOnly ? t.backup.kindFollows : t.backup.kindFull;
    return SettingsTile.navigation(
      key: Key('backup-file-${entry.name}'),
      leading: Icon(entry.followsOnly ? Icons.bookmark_outlined : Icons.archive_outlined),
      title: Text(entry.name),
      description: Text([_when(entry.modified), formatBackupSize(entry.size), kind].join(' · ')),
      // The ⋮ sits in the trailing slot: the row's own tap stays the restore.
      trailing: PureMenu(
        items: [
          PureMenuItem(
            id: 'restore',
            label: t.backup.restore,
            icon: Icons.restore,
            onTap: () => unawaited(_restore(entry)),
          ),
          PureMenuItem(
            id: 'delete',
            label: t.backup.delete,
            icon: Icons.delete_outline,
            danger: true,
            onTap: () => unawaited(_delete(entry)),
          ),
        ],
        child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.more_vert, size: 20)),
      ),
      enabled: _usable(_Action.files),
      onPressed: (_) => unawaited(_restore(entry)),
    );
  }

  static String _when(DateTime local) =>
      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

  /// Reads a `webdav.*` string through the map lookup, which keeps working
  /// before and after the strings are regenerated.
  static String _webdavText(String key) {
    try {
      final value = t['webdav.$key'];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    } on Object {
      // Fall through to the key itself.
    }
    return key;
  }
}
