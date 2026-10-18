import 'dart:async' show unawaited;
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/environment/app_directory.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/app/routing/routes/login/login_routes.dart';
import 'package:pure_live/features/backup/backup_archive.dart';
import 'package:pure_live/features/backup/web_dav_page.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:restart_app/restart_app.dart';

/// Backup and restore (3.x `BackupPage`, local slice): a timestamped zip
/// of the data area's own files into the backups tree, restore from the
/// tree or from a picked file — the app restarts after a restore, because
/// the boxes the zip overwrites are open.
///
/// Written as one `pure_settings_ui` tree like the rest of the settings cluster,
/// and it carries the three doors the reference's hub carries: the WebDAV drive,
/// the LAN remote-sync receiver, and the cloud account.
final class BackupPage extends ConsumerStatefulWidget {
  /// The backup page.
  const new({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

final class _BackupPageState extends ConsumerState<BackupPage> {
  List<BackupEntry> _backups = const [];
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<(Directory, Directory)> _dirs() async {
    final paths = ref.read(pathsProvider);
    final data = await paths.directory(AppDirectory.data);
    final backups = await paths.directory(AppDirectory.backups);
    return (data, backups);
  }

  Future<void> _refresh() async {
    final (_, backups) = await _dirs();
    if (!mounted) {
      return;
    }
    setState(() => _backups = listBackups(backups));
  }

  Future<void> _setBusy(Future<void> Function() task) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await task();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _message = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      await _refresh();
    }
  }

  Future<void> _create() async {
    await _setBusy(() async {
      final (data, backups) = await _dirs();
      createBackup(dataDir: data, backupsDir: backups);
    });
  }

  /// Restores [backup] and restarts — the zip overwrites box files that
  /// are open, and a reload is the only way to read them consistently.
  Future<void> _restore(BackupEntry backup) async {
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: context.t.backup.restore,
      child: Text(context.t.backup.restoreConfirm(name: backup.name)),
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
    await _setBusy(() async {
      final (data, _) = await _dirs();
      restoreBackup(backup: backup.file, dataDir: data);
      await Restart.restartApp();
    });
  }

  Future<void> _restoreFromFile() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'zip', extensions: ['zip']),
      ],
    );
    if (file == null) {
      return;
    }
    await _setBusy(() async {
      final (data, _) = await _dirs();
      restoreBackup(backup: File(file.path), dataDir: data);
      await Restart.restartApp();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final busy = _busy;
    return PureScaffold(
      appBar: PureAppBar(title: t.backup.title),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.backup.title),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.backup_outlined),
                title: Text(t.backup.create),
                enabled: !busy,
                onPressed: (_) => unawaited(_create()),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.file_open_outlined),
                title: Text(t.backup.restoreFile),
                enabled: !busy,
                onPressed: (_) => unawaited(_restoreFromFile()),
              ),
              if (_message case final String message)
                CustomSettingsTile(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(message, style: TextStyle(color: PureTheme.of(context).colors.error)),
                  ),
                ),
            ],
          ),
          SettingsSection(
            title: Text(t.backup.sectionCloud),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(_webdavText('entryTitle')),
                description: Text(_webdavText('entrySubtitle')),
                enabled: !busy,
                // The WebDAV page is its own route class; this page reaches it
                // the same way it reaches the archive: a push above the shell.
                onPressed: (_) =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WebDavPage())),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.sync_outlined),
                title: Text(t.settings.remoteSync),
                description: Text(t.settings.remoteSyncSubtitle),
                onPressed: (_) => unawaited(context.push<void>(RoutePath.remoteSync)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(t.account.title),
                description: Text(t.settings.accountSubtitle),
                onPressed: (_) => unawaited(const AccountRoute().push<void>(context)),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.backup.existing),
            tiles: [
              if (_backups.isEmpty)
                SettingsTile(title: Text(t.backup.none))
              else
                for (final backup in _backups)
                  SettingsTile.navigation(
                    leading: const Icon(Icons.archive_outlined),
                    title: Text(backup.name),
                    value: Text(_when(backup.modified)),
                    // The row restores; the trash is the only thing that
                    // destroys, and it never sits under the row's own tap.
                    trailing: PureIconButton(
                      tooltip: t.backup.delete,
                      icon: Icons.delete_outline,
                      onPressed: busy ? null : () => unawaited(_setBusy(() async => deleteBackup(backup))),
                    ),
                    enabled: !busy,
                    onPressed: (_) => unawaited(_setBusy(() => _restore(backup))),
                  ),
            ],
          ),
        ],
      ),
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
