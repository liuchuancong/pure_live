import 'dart:async' show StreamSubscription, unawaited;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/features/backup/backup_archive.dart';
import 'package:pure_live/features/backup/backup_documents.dart';
import 'package:pure_live/features/backup/web_dav_config.dart';
import 'package:pure_live/features/backup/web_dav_preferences.dart';
import 'package:pure_live/features/backup/web_dav_service.dart';
import 'package:pure_live/features/backup/web_dav_store.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/environment/app_directory.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:restart_app/restart_app.dart';
import 'package:url_launcher/url_launcher.dart';

/// WebDAV cloud backup (the reference's `WebDavPage`, the multi-server
/// shape): the named servers live in a sheet (create, edit, delete, switch),
/// passwords in the secret vault, and the page BROWSSES the server —
/// breadcrumbs over the folder tree, folders opened by tap, files restored
/// (a zip through the overwrite-and-restart path, a follows document
/// through the live replace) or deleted from each row's ⋮.
///
/// The FAB uploads to the folder you are standing in: the full archive, or
/// — under 更多操作 — the follows list as a JSON document, which is the file
/// the other device can restore without a restart.
final class WebDavPage extends ConsumerStatefulWidget {
  /// The WebDAV page.
  const new({super.key});

  @override
  ConsumerState<WebDavPage> createState() => _WebDavPageState();
}

final class _WebDavPageState extends ConsumerState<WebDavPage> {
  WebDavStore? _store;
  StreamSubscription<WebDavPreferences>? _subscription;
  WebDavPreferences _preferences = const WebDavPreferences();

  bool _listing = false;
  bool _uploading = false;
  String? _busyEntry;
  String? _status;
  bool _statusIsError = false;
  String tKey(String key) {
    try {
      final value = Translations.of(context)[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    } on Object {
      // Fall through to the key itself.
    }
    return key;
  }

  List<WebDavEntry> _entries = const [];

  /// The folder being browsed, relative to the server's own directory;
  /// '' is that directory itself.
  String _path = '';

  WebDavService? _service;
  String? _serviceKey;

  /// The strings, read per build so the page follows the app language.
  Translations get t => context.t;

  WebDavServer? get _active => _preferences.activeServer;

  /// The active server's runtime config, the vault's password merged in.
  WebDavConfig? get _config {
    final server = _active;
    if (server == null) {
      return null;
    }
    return WebDavConfig(
      name: server.name,
      address: server.address,
      username: server.username,
      password: _store?.passwordOf(server.name) ?? '',
      directory: server.directory,
    );
  }

  bool get _ready {
    final config = _config;
    return config != null &&
        config.address.trim().isNotEmpty &&
        config.username.trim().isNotEmpty &&
        config.password.isNotEmpty;
  }

  /// The live service for the active server; rebuilt when the server (or
  /// its address) changed, so the pooled transport survives a browse.
  WebDavService? _serviceNow() {
    final config = _config;
    if (config == null) {
      _service?.close();
      _service = null;
      _serviceKey = null;
      return null;
    }
    final key = '${config.name}|${config.address}|${config.username}|${config.password}|${config.directory}';
    if (_service != null && _serviceKey == key) {
      return _service;
    }
    _service?.close();
    _serviceKey = key;
    return _service = WebDavService(config: config);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_bind());
  }

  Future<void> _bind() async {
    final store = await ref.read(webDavStoreProvider.future);
    if (!mounted) {
      return;
    }
    setState(() {
      _store = store;
      _preferences = store.value;
      _subscription = store.changes.listen((preferences) {
        if (mounted) {
          setState(() => _preferences = preferences);
        }
      });
    });
    if (_ready) {
      unawaited(_list());
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _service?.close();
    super.dispose();
  }

  void _showStatus(String message, {required bool isError}) {
    if (mounted) {
      setState(() {
        _status = message;
        _statusIsError = isError;
      });
    }
  }

  String _failureMessage(WebDavException error) => switch (error.kind) {
    WebDavFailure.unauthorized => '${t.webdav.testFailed} (401/403)',
    WebDavFailure.notFound => '${t.webdav.testFailed} (404)',
    WebDavFailure.server => '${t.webdav.testFailed} (${error.statusCode ?? '?'})',
    WebDavFailure.network => '${t.webdav.testFailed}: network',
  };

  Future<void> _list() async {
    final service = _serviceNow();
    if (service == null) {
      return;
    }
    setState(() => _listing = true);
    try {
      final entries = await service.list(path: _path);
      if (mounted) {
        setState(() => _entries = entries);
      }
    } on WebDavException catch (error) {
      _showStatus(_failureMessage(error), isError: true);
    } on Object catch (error) {
      _showStatus('$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _listing = false);
      }
    }
  }

  void _openFolder(WebDavEntry entry) {
    setState(() {
      _path = _path.isEmpty ? entry.name : '$_path/${entry.name}';
      _entries = const [];
    });
    unawaited(_list());
  }

  void _goto(String path) {
    setState(() {
      _path = path;
      _entries = const [];
    });
    unawaited(_list());
  }

  Future<(Directory, Directory)> _dirs() async {
    final paths = ref.read(pathsProvider);
    final data = await paths.directory(AppDirectory.data);
    final backups = await paths.directory(AppDirectory.backups);
    return (data, backups);
  }

  /// The FAB: the full archive into the folder being browsed.
  Future<void> _uploadFull() async {
    final service = _serviceNow();
    if (service == null) {
      return;
    }
    setState(() => _uploading = true);
    try {
      final (data, backups) = await _dirs();
      final archive = createBackup(dataDir: data, backupsDir: backups);
      final name = archive.uri.pathSegments.last;
      await service.upload(name, await archive.readAsBytes(), path: _path);
      await _store?.updateActive((server) => server.copyWith(lastBackupAt: DateTime.now()));
      _showStatus(t.webdav.uploaded(name: name), isError: false);
      await _list();
    } on WebDavException catch (error) {
      _showStatus('${t.webdav.uploadFailed}: ${_failureMessage(error)}', isError: true);
    } on Object catch (error) {
      _showStatus('$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  /// 更多操作: the follows list as one JSON document — the file the other
  /// device restores live, without the restart a zip forces.
  Future<void> _uploadFollows() async {
    final service = _serviceNow();
    if (service == null) {
      return;
    }
    setState(() => _uploading = true);
    try {
      final repository = ref.read(followRepositoryProvider);
      await repository.load();
      final name = followsBackupName(DateTime.now());
      final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(buildFollowsDocument(repository)));
      await service.upload(name, Uint8List.fromList(bytes), path: _path);
      _showStatus(t.webdav.uploaded(name: name), isError: false);
      await _list();
    } on WebDavException catch (error) {
      _showStatus('${t.webdav.uploadFailed}: ${_failureMessage(error)}', isError: true);
    } on Object catch (error) {
      _showStatus('$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _restore(WebDavEntry entry) async {
    final service = _serviceNow();
    if (service == null) {
      return;
    }
    final followsFile = entry.name.toLowerCase().endsWith('.json');
    final confirmed = await _confirm(
      title: t.webdav.restore,
      message: followsFile ? t.webdav.restoreFavorites : t.webdav.restoreConfirm,
      confirmLabel: t.webdav.restore,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busyEntry = entry.href);
    try {
      final bytes = await service.download(entry);
      if (followsFile) {
        final parsed = FollowsBackup.tryParse(_jsonOf(bytes));
        if (parsed == null) {
          _showStatus(t.webdav.downloadFailed, isError: true);
          return;
        }
        final repository = ref.read(followRepositoryProvider);
        await repository.load();
        await repository.replaceAll(rooms: parsed.rooms, groups: parsed.groups);
        _showStatus(t.webdav.restored(name: entry.name), isError: false);
      } else {
        final (data, backups) = await _dirs();
        final local = File('${backups.path}${Platform.pathSeparator}${_safeFileName(entry.name)}');
        await local.writeAsBytes(bytes, flush: true);
        restoreBackup(backup: local, dataDir: data);
        await _store?.updateActive((server) => server.copyWith(lastRestoreAt: DateTime.now()));
        await Restart.restartApp();
      }
    } on WebDavException catch (error) {
      _showStatus('${t.webdav.downloadFailed}: ${_failureMessage(error)}', isError: true);
    } on Object catch (error) {
      _showStatus('$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyEntry = null);
      }
    }
  }

  Future<void> _deleteRemote(WebDavEntry entry) async {
    final service = _serviceNow();
    if (service == null) {
      return;
    }
    final confirmed = await _confirm(
      title: t.webdav.delete,
      message: t.webdav.confirmDeleteItem(name: entry.name),
      confirmLabel: t.webdav.delete,
      danger: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busyEntry = entry.href);
    try {
      await service.delete(entry);
      _showStatus(t.webdav.deleteSuccess, isError: false);
      await _list();
    } on WebDavException catch (error) {
      _showStatus('${t.webdav.deleteFailed}: ${_failureMessage(error)}', isError: true);
    } on Object catch (error) {
      _showStatus('$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyEntry = null);
      }
    }
  }

  static Map<String, Object?> _jsonOf(List<int> bytes) {
    final decoded = utf8.decode(bytes);
    final value = jsonDecode(decoded);
    if (value is! Map) {
      throw const FormatException('not a JSON object');
    }
    return Map<String, Object?>.from(value);
  }

  /// Keeps what a server returned from escaping the backups tree.
  static String _safeFileName(String name) {
    final clean = name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    return clean.toLowerCase().endsWith('.zip') ? clean : '$clean.zip';
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool danger = false,
  }) => showPureDialog<bool>(
    context: context,
    title: title,
    child: Text(message),
    actions: (dialogContext) => [
      PureButton(
        label: dialogContext.t.common.cancel,
        variant: ButtonVariant.ghost,
        onPressed: () => Navigator.of(dialogContext).pop(false),
      ),
      PureButton(
        label: confirmLabel,
        variant: danger ? ButtonVariant.danger : ButtonVariant.primary,
        onPressed: () => Navigator.of(dialogContext).pop(true),
      ),
    ],
  );

  // ——— the server sheet ———

  Future<void> _openServers() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _WebDavServersSheet(
        store: _store!,
        preferences: _preferences,
        onEdit: (server) {
          Navigator.of(sheetContext).pop();
          unawaited(_editServer(server));
        },
        onAdd: () {
          WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_editServer(null)));
        },
      ),
    );
  }

  Future<void> _editServer(WebDavServer? existing) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) =>
          _WebDavServerForm(store: _store!, existing: existing, onSaved: () => Navigator.of(sheetContext).pop()),
    );
  }

  // ——— the chrome ———

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    if (_store == null) {
      return PureScaffold(
        appBar: PureAppBar(title: t.webdav.title),
        body: const Center(child: PureLoading()),
      );
    }
    final active = _active;
    return PureScaffold(
      appBar: PureAppBar(
        title: t.webdav.title,
        actions: [
          PureIconButton(
            key: const ValueKey('webdav-servers'),
            tooltip: t.webdav.openList,
            icon: Icons.dns_outlined,
            onPressed: () => unawaited(_openServers()),
          ),
          PureIconButton(
            key: const ValueKey('webdav-refresh'),
            tooltip: t.webdav.refresh,
            icon: Icons.refresh,
            onPressed: _busy ? null : () => unawaited(_list()),
          ),
          PureMenu(
            items: [
              PureMenuItem(
                id: 'follows',
                label: t.webdav.uploadFavorites,
                icon: Icons.bookmark_add_outlined,
                onTap: _busy ? null : () => unawaited(_uploadFollows()),
              ),
              PureMenuItem(
                id: 'help',
                label: t.webdav.helpTutorial,
                icon: Icons.help_outline,
                onTap: () => unawaited(_openOfficialHelp()),
              ),
            ],
            child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.more_vert)),
          ),
        ],
      ),
      floatingActionButton: active == null
          ? null
          : PureButton(
              key: const ValueKey('webdav-upload'),
              label: _uploading ? t.webdav.backingUp : t.webdav.uploadFull,
              icon: Icons.cloud_upload_outlined,
              loading: _uploading,
              onPressed: _busy ? null : () => unawaited(_uploadFull()),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: [
          if (active == null)
            PureEmpty(
              key: const ValueKey('webdav-no-config'),
              title: t.webdav.noConfigCreateFirst,
              message: t.webdav.intro,
              icon: Icons.cloud_off_outlined,
              action: PureButton(
                key: const ValueKey('webdav-create-first'),
                label: t.webdav.createNew,
                onPressed: () => unawaited(_editServer(null)),
              ),
            )
          else ...[
            PureListRow(
              leading: const Icon(Icons.cloud_outlined),
              title: active.name,
              subtitle: active.address,
              trailing: PureIconButton(
                key: const ValueKey('webdav-edit-active'),
                tooltip: t.webdav.editServer,
                icon: Icons.edit_outlined,
                onPressed: () => unawaited(_editServer(active)),
              ),
            ),
            if (!(_store?.secretsOk ?? true))
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                child: Text(t.webdav.secretsNote, style: theme.text.caption.copyWith(color: theme.colors.warning)),
              ),
            PureListRow(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: t.webdav.lastBackup,
              subtitle: _when(active.lastBackupAt),
              divided: false,
            ),
            PureListRow(
              leading: const Icon(Icons.cloud_download_outlined),
              title: t.webdav.lastRestore,
              subtitle: _when(active.lastRestoreAt),
              divided: false,
            ),
            const SizedBox(height: PureSpacing.sm),
            _breadcrumbs(theme),
            const SizedBox(height: PureSpacing.xs),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(PureSpacing.xs, PureSpacing.xs, PureSpacing.xs, PureSpacing.sm),
                child: Text(
                  _status!,
                  style: TextStyle(color: _statusIsError ? theme.colors.error : theme.colors.primary),
                ),
              ),
            _folder(theme),
          ],
          const SizedBox(height: 18),
          _help(theme),
        ],
      ),
    );
  }

  bool get _busy => _listing || _uploading || _busyEntry != null;

  Widget _breadcrumbs(PureTheme theme) {
    final segments = _path.split('/').where((part) => part.isNotEmpty).toList();
    var walked = '';
    final crumbs = <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: PureSpacing.xxs),
        child: PureButton(
          key: const ValueKey('webdav-crumb-root'),
          label: _active?.directory.isEmpty ?? true ? '/' : _active!.directory,
          size: ControlSize.sm,
          variant: _path.isEmpty ? ButtonVariant.primary : ButtonVariant.ghost,
          onPressed: _path.isEmpty ? null : () => _goto(''),
        ),
      ),
    ];
    for (final segment in segments) {
      walked = walked.isEmpty ? segment : '$walked/$segment';
      final target = walked;
      final last = segment == segments.last;
      crumbs.addAll([
        Icon(Icons.chevron_right, size: 16, color: theme.colors.textTertiary),
        PureButton(
          key: ValueKey('webdav-crumb-$target'),
          label: segment,
          size: ControlSize.sm,
          variant: last ? ButtonVariant.primary : ButtonVariant.ghost,
          onPressed: last ? null : () => _goto(target),
        ),
      ]);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: crumbs),
    );
  }

  Widget _folder(PureTheme theme) {
    if (!_ready) {
      return PureEmpty(title: t.webdav.configIncomplete, icon: Icons.vpn_key_outlined);
    }
    if (_listing) {
      return const Center(child: PureLoading());
    }
    if (_entries.isEmpty) {
      return PureEmpty(title: t.webdav.folderEmpty, message: t.webdav.intro, icon: Icons.folder_open_outlined);
    }
    return Column(
      children: [
        for (final entry in _entries)
          PureListRow(
            key: ValueKey('webdav-entry-${entry.href}'),
            leading: Icon(entry.isDirectory ? Icons.folder_outlined : Icons.archive_outlined),
            title: entry.name,
            subtitle: [
              if (entry.modified case final modified?) _when(modified.toLocal()),
              if (!entry.isDirectory)
                if (entry.size case final size?) formatBackupSize(size),
            ].join(' · '),
            trailing: _busyEntry == entry.href
                ? const PureSpinner()
                : entry.isDirectory
                ? const Icon(Icons.chevron_right)
                : PureMenu(
                    key: ValueKey('webdav-entry-menu-${entry.name}'),
                    items: [
                      PureMenuItem(
                        id: 'restore',
                        label: entry.name.toLowerCase().endsWith('.json')
                            ? t.webdav.restoreFavorites
                            : t.webdav.restoreAllSettings,
                        icon: Icons.restore,
                        onTap: _busy ? null : () => unawaited(_restore(entry)),
                      ),
                      PureMenuItem(
                        id: 'delete',
                        label: t.webdav.delete,
                        icon: Icons.delete_outline,
                        danger: true,
                        onTap: _busy ? null : () => unawaited(_deleteRemote(entry)),
                      ),
                    ],
                    child: const Padding(padding: EdgeInsets.all(10), child: Icon(Icons.more_vert, size: 20)),
                  ),
            onTap: _busy
                ? null
                : entry.isDirectory
                ? () => _openFolder(entry)
                : () => unawaited(_restore(entry)),
            divided: false,
          ),
      ],
    );
  }

  Widget _help(PureTheme theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(t.webdav.helpTitle, style: theme.text.title),
      const SizedBox(height: PureSpacing.sm),
      Text(t.webdav.helpIntro, style: theme.text.bodySmall),
      const SizedBox(height: PureSpacing.sm),
      Text(t.webdav.helpSteps, style: theme.text.bodySmall),
      const SizedBox(height: PureSpacing.sm),
      Text(t.webdav.helpServer, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
      Text(t.webdav.helpAccount, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
      Text(t.webdav.helpPassword, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
      Text(t.webdav.helpIssues, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
      const SizedBox(height: 10),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: PureButton(
          label: t.webdav.openOfficialHelp,
          icon: Icons.open_in_new,
          variant: ButtonVariant.secondary,
          size: ControlSize.sm,
          onPressed: () => unawaited(_openOfficialHelp()),
        ),
      ),
    ],
  );

  Future<void> _openOfficialHelp() async {
    final uri = Uri.parse('https://help.jianguoyun.com/?p=2064');
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      opened = false;
    }
    if (!opened) {
      _showStatus(t.webdav.helpOpenFailed, isError: true);
    }
  }

  static String _when(DateTime? at) => at == null
      ? '—'
      : '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')} '
            '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

/// The server sheet: every configured drive with the active one ticked, a
/// tap to switch, and per-row edit and delete; 创建新配置 at the bottom
/// (the reference's drawer, cut to a sheet).
final class _WebDavServersSheet extends StatefulWidget {
  const new({required this.store, required this.preferences, required this.onEdit, required this.onAdd});

  final WebDavStore store;
  final WebDavPreferences preferences;
  final void Function(WebDavServer server) onEdit;
  final VoidCallback onAdd;

  @override
  State<_WebDavServersSheet> createState() => _WebDavServersSheetState();
}

final class _WebDavServersSheetState extends State<_WebDavServersSheet> {
  Future<void> _select(String name) async {
    await widget.store.select(name);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _remove(WebDavServer server) async {
    final t = context.t;
    final confirmed = await showPureDialog<bool>(
      context: context,
      title: t.webdav.deleteServer,
      child: Text(t.webdav.confirmDeleteConfig(name: server.name)),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.cancel,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(
          key: const ValueKey('webdav-config-delete-confirm'),
          label: dialogContext.t.webdav.deleteServer,
          variant: ButtonVariant.danger,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    );
    if (confirmed != true) {
      return;
    }
    await widget.store.removeServer(server.name);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final servers = widget.preferences.servers;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(PureSpacing.md, 0, PureSpacing.md, PureSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(PureSpacing.sm, 0, PureSpacing.sm, PureSpacing.sm),
              child: Text(t.webdav.servers, style: PureTheme.of(context).text.title),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final server in servers)
                      PureListRow(
                        key: ValueKey('webdav-server-${server.name}'),
                        leading: Icon(
                          server.name == widget.preferences.activeServer?.name
                              ? Icons.check_circle
                              : Icons.cloud_outlined,
                        ),
                        title: server.name,
                        subtitle: server.address,
                        selected: server.name == widget.preferences.activeServer?.name,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PureIconButton(
                              key: ValueKey('webdav-server-edit-${server.name}'),
                              tooltip: t.webdav.editServer,
                              icon: Icons.edit_outlined,
                              onPressed: () => widget.onEdit(server),
                            ),
                            PureIconButton(
                              key: ValueKey('webdav-server-delete-${server.name}'),
                              tooltip: t.webdav.deleteServer,
                              icon: Icons.delete_outline,
                              onPressed: () => unawaited(_remove(server)),
                            ),
                          ],
                        ),
                        onTap: () => unawaited(_select(server.name)),
                        divided: false,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: PureSpacing.sm),
            PureButton(
              key: const ValueKey('webdav-server-add'),
              label: t.webdav.createNew,
              icon: Icons.add,
              variant: ButtonVariant.secondary,
              onPressed: () {
                Navigator.of(context).pop();
                // The page opens the fresh-form sheet once this one is gone.
                widget.onAdd();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The add/edit form of one server (the reference's config dialog): name,
/// address, account, password, directory — 测试连接 proves it against the
/// server before 保存 keeps it, and the password goes to the vault, not the
/// document.
final class _WebDavServerForm extends StatefulWidget {
  const new({required this.store, required this.existing, required this.onSaved});

  final WebDavStore store;
  final WebDavServer? existing;
  final VoidCallback onSaved;

  @override
  State<_WebDavServerForm> createState() => _WebDavServerFormState();
}

final class _WebDavServerFormState extends State<_WebDavServerForm> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _address = TextEditingController(text: widget.existing?.address ?? '');
  late final TextEditingController _username = TextEditingController(text: widget.existing?.username ?? '');
  late final TextEditingController _password = TextEditingController(
    text: widget.existing == null ? '' : widget.store.passwordOf(widget.existing!.name),
  );
  late final TextEditingController _directory = TextEditingController(text: widget.existing?.directory ?? '');

  String? _nameError;
  String? _addressError;
  String? _status;
  bool _testing = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _username.dispose();
    _password.dispose();
    _directory.dispose();
    super.dispose();
  }

  WebDavServer _server() => WebDavServer(
    name: _name.text.trim(),
    address: _address.text.trim(),
    username: _username.text.trim(),
    directory: _directory.text.trim(),
    lastBackupAt: widget.existing?.lastBackupAt,
    lastRestoreAt: widget.existing?.lastRestoreAt,
  );

  Future<bool> _test() async {
    final server = _server();
    final service = WebDavService(
      config: WebDavConfig(
        name: server.name,
        address: server.address,
        username: server.username,
        password: _password.text,
        directory: server.directory,
      ),
    );
    setState(() {
      _testing = true;
      _status = null;
    });
    try {
      await service.testConnection();
      if (mounted) {
        setState(() => _status = 'ok');
      }
      return true;
    } on WebDavException catch (error) {
      if (mounted) {
        setState(
          () => _status = switch (error.kind) {
            WebDavFailure.unauthorized => '401/403',
            _ => '${error.kind.name}${error.statusCode == null ? '' : ' ${error.statusCode}'}',
          },
        );
      }
      return false;
    } on Object catch (error) {
      if (mounted) {
        setState(() => _status = '$error');
      }
      return false;
    } finally {
      service.close();
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _save() async {
    final t = context.t;
    final server = _server();
    setState(() {
      _nameError = null;
      _addressError = null;
    });
    if (server.name.isEmpty) {
      setState(() => _nameError = t.webdav.serverName);
      return;
    }
    final renaming = widget.existing != null && widget.existing!.name != server.name;
    if ((renaming || widget.existing == null) && widget.store.value.servers.any((entry) => entry.name == server.name)) {
      setState(() => _nameError = t.webdav.nameExists);
      return;
    }
    if (!WebDavConfig.isValidAddress(server.address)) {
      setState(() => _addressError = t.webdav.addressInvalid);
      return;
    }
    setState(() => _saving = true);
    try {
      // The same door the 测试连接 button uses: nothing half-verified is kept.
      final proved =
          _password.text.isNotEmpty || widget.existing != null && widget.store.passwordOf(server.name).isNotEmpty;
      if (!proved || !await _test()) {
        if (mounted) {
          setState(() => _saving = false);
        }
        return;
      }
      await widget.store.saveServer(server, password: _password.text.isEmpty ? null : _password.text);
      if (!mounted) {
        return;
      }
      PureToast.show(context, t.webdav.saved, type: PureToastType.success);
      widget.onSaved();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? t.webdav.createNew : t.webdav.editServer, style: theme.text.title),
            const SizedBox(height: PureSpacing.md),
            PureTextField(
              key: const ValueKey('webdav-field-name'),
              controller: _name,
              placeholder: t.webdav.serverName,
              enabled: widget.existing == null,
              errorText: _nameError,
              onChanged: (_) => setState(() => _nameError = null),
            ),
            const SizedBox(height: 10),
            PureTextField(
              key: const ValueKey('webdav-field-address'),
              controller: _address,
              placeholder: t.webdav.addressHint,
              keyboardType: TextInputType.url,
              errorText: _addressError,
              onChanged: (_) => setState(() => _addressError = null),
            ),
            const SizedBox(height: 10),
            PureTextField(controller: _username, placeholder: t.webdav.username),
            const SizedBox(height: 10),
            PureTextField(
              key: const ValueKey('webdav-field-password'),
              controller: _password,
              placeholder: t.webdav.password,
              obscure: true,
            ),
            const SizedBox(height: 10),
            PureTextField(controller: _directory, placeholder: t.webdav.directory),
            if (_status != null)
              Padding(
                padding: const EdgeInsets.only(top: PureSpacing.sm),
                child: Text(
                  _status == 'ok' ? t.webdav.testOk : '${t.webdav.testFailed}: $_status',
                  style: theme.text.caption.copyWith(
                    color: _status == 'ok' ? theme.colors.success : theme.colors.error,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: PureButton(
                    key: const ValueKey('webdav-form-test'),
                    label: _testing ? t.webdav.testing : t.webdav.testConnection,
                    icon: Icons.wifi_tethering_outlined,
                    variant: ButtonVariant.secondary,
                    loading: _testing,
                    onPressed: _busy ? null : () => unawaited(_test()),
                  ),
                ),
                const SizedBox(width: PureSpacing.md),
                Expanded(
                  child: PureButton(
                    key: const ValueKey('webdav-form-save'),
                    label: t.common.save,
                    icon: Icons.check,
                    loading: _saving,
                    onPressed: _busy ? null : () => unawaited(_save()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _busy => _testing || _saving;
}
