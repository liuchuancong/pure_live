import 'dart:async' show unawaited;
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/environment/app_directory.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/backup/backup_archive.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:restart_app/restart_app.dart';

/// Backup and restore (3.x `BackupPage`, local slice): a timestamped zip
/// of the data area's own files into the backups tree, restore from the
/// tree or from a picked file — the app restarts after a restore, because
/// the boxes the zip overwrites are open.
///
/// WebDAV, LAN sync and the TV hand-off join with their waves.
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
    return PureScaffold(
      appBar: PureAppBar(title: context.t.backup.title, actions: const [SettingsEntryButton()]),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: PureButton(
                  label: context.t.backup.create,
                  icon: Icons.backup_outlined,
                  onPressed: _busy ? null : _create,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PureButton(
                  label: context.t.backup.restoreFile,
                  icon: Icons.file_open_outlined,
                  onPressed: _busy ? null : _restoreFromFile,
                ),
              ),
            ],
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_message!, style: TextStyle(color: PureTheme.of(context).colors.error)),
            ),
          const SizedBox(height: 18),
          Text(context.t.backup.existing, style: PureTheme.of(context).text.title),
          const SizedBox(height: 8),
          if (_backups.isEmpty)
            PureEmpty(title: context.t.backup.none)
          else
            for (final backup in _backups)
              PureListRow(
                leading: const Icon(Icons.archive_outlined),
                title: backup.name,
                subtitle: _when(backup.modified),
                trailing: PureIconButton(
                  tooltip: context.t.backup.delete,
                  icon: Icons.delete_outline,
                  onPressed: _busy
                      ? null
                      : () => unawaited(
                          _setBusy(() async {
                            deleteBackup(backup);
                          }),
                        ),
                ),
                onTap: _busy
                    ? null
                    : () => unawaited(
                        _setBusy(() async {
                          await _restore(backup);
                        }),
                      ),
                divided: false,
              ),
        ],
      ),
    );
  }

  static String _when(DateTime local) =>
      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
