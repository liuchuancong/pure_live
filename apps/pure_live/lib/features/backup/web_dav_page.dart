import 'dart:async' show StreamSubscription, unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/environment/app_directory.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/backup/backup_archive.dart';
import 'package:pure_live/features/backup/web_dav_config.dart';
import 'package:pure_live/features/backup/web_dav_preferences.dart';
import 'package:pure_live/features/backup/web_dav_service.dart';
import 'package:pure_live/features/backup/web_dav_store.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:restart_app/restart_app.dart';
import 'package:url_launcher/url_launcher.dart';

/// WebDAV cloud backup (the 3.x `web_dav` slice, re-homed): the user's own
/// WebDAV server receives the same archive the local backups use. The page
/// holds the server form, the connect test, the upload ("back up now") and
/// the remote backup list, where a tap downloads and restores — with the
/// same restart-after-restore contract as the local slice, because the zip
/// overwrites boxes that are open.
///
/// One configuration (address, account, app password, optional directory),
/// persisted through [webDavStoreProvider]; the reference's multi-server
/// drawer collapsed into this single form, which is what one user with one
/// cloud drive needs.
final class WebDavPage extends ConsumerStatefulWidget {
  /// The WebDAV page.
  const new({super.key});

  @override
  ConsumerState<WebDavPage> createState() => _WebDavPageState();
}

final class _WebDavPageState extends ConsumerState<WebDavPage> {
  final _addressController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _directoryController = TextEditingController();

  WebDavStore? _store;
  StreamSubscription<WebDavPreferences>? _subscription;
  WebDavPreferences _preferences = const WebDavPreferences();
  bool _seeded = false;

  bool _obscurePassword = true;
  bool _testing = false;
  bool _backingUp = false;
  String? _busyEntry;
  String? _status;
  bool _statusIsError = false;
  List<WebDavEntry> _entries = const [];
  bool _listing = false;
  String? _addressError;

  /// The config the form's fields hold right now.
  WebDavConfig get _formConfig => WebDavConfig(
    address: _addressController.text.trim(),
    username: _usernameController.text.trim(),
    password: _passwordController.text,
    directory: _directoryController.text.trim(),
  );

  /// The live service for [config]; one per page, rebuilt only when the
  /// config actually changed, so the pooled transport survives a listing
  /// after an upload.
  WebDavService _serviceFor(WebDavConfig config) {
    final existing = _service;
    if (existing != null && existing.config == config) {
      return existing;
    }
    existing?.close();
    return _service = WebDavService(config: config);
  }

  WebDavService? _service;

  /// Reads a `webdav.*` string through the map lookup, which keeps working
  /// before and after the strings are regenerated.
  String _t(String key) {
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
    if (_preferences.config?.isComplete ?? false) {
      unawaited(_list());
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _service?.close();
    _addressController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _directoryController.dispose();
    super.dispose();
  }

  /// Seeds the form fields from the persisted config exactly once — later
  /// store emissions (sync times) must not fight what the user is typing.
  void _seedForm() {
    if (_seeded) {
      return;
    }
    final config = _preferences.config;
    if (config == null) {
      return;
    }
    _seeded = true;
    _addressController.text = config.address;
    _usernameController.text = config.username;
    _passwordController.text = config.password;
    _directoryController.text = config.directory;
  }

  Future<void> _saveConfig(WebDavConfig config) async {
    _addressError = WebDavConfig.isValidAddress(config.address) ? null : _t('addressInvalid');
    await _store?.update((preferences) => preferences.copyWith(config: config));
    if (mounted) {
      setState(() {});
    }
  }

  Future<(Directory, Directory)> _dirs() async {
    final paths = ref.read(pathsProvider);
    final data = await paths.directory(AppDirectory.data);
    final backups = await paths.directory(AppDirectory.backups);
    return (data, backups);
  }

  void _showStatus(String message, {required bool isError}) {
    if (mounted) {
      setState(() {
        _status = message;
        _statusIsError = isError;
      });
    }
  }

  /// Runs [task] with [busyLabel] in the status line; a [WebDavException]
  /// degrades to its named message, anything else to its own words.
  Future<void> _run(String busyLabel, Future<void> Function() task) async {
    setState(() {
      _status = busyLabel;
      _statusIsError = false;
    });
    try {
      await task();
    } on WebDavException catch (error) {
      _showStatus('${_failureMessage(error)}${error.detail == null ? '' : '\n${error.detail}'}', isError: true);
    } on Object catch (error) {
      _showStatus('$error', isError: true);
    }
  }

  /// The message a failure is named by; the transport's own detail rides on
  /// a second line, where a support question needs it.
  String _failureMessage(WebDavException error) => switch (error.kind) {
    WebDavFailure.unauthorized => '${_t('testFailed')} (401/403)',
    WebDavFailure.notFound => '${_t('testFailed')} (404)',
    WebDavFailure.server => '${_t('testFailed')} (${error.statusCode ?? '?'})',
    WebDavFailure.network => '${_t('testFailed')}: network',
  };

  bool get _configReady => _preferences.config?.isComplete ?? false;

  bool get _busy => _testing || _backingUp || _busyEntry != null || _listing;

  Future<void> _testConnection() async {
    final config = _formConfig;
    if (!WebDavConfig.isValidAddress(config.address)) {
      _showStatus(_t('addressInvalid'), isError: true);
      return;
    }
    await _saveConfig(config);
    setState(() => _testing = true);
    try {
      await _run(_t('testing'), () async {
        await _serviceFor(config).testConnection();
        _showStatus(_t('testOk'), isError: false);
        await _list();
      });
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _list() async {
    if (!_configReady) {
      return;
    }
    setState(() => _listing = true);
    try {
      final entries = await _serviceFor(_preferences.config!).listDirectory();
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

  /// Creates the local archive with the local slice's own logic and pushes
  /// its bytes to the server — one payload, two destinations.
  Future<void> _backupNow() async {
    final config = _preferences.config;
    if (config == null || !config.isComplete) {
      _showStatus(_t('configIncomplete'), isError: true);
      return;
    }
    setState(() => _backingUp = true);
    try {
      await _run(_t('backingUp'), () async {
        final (data, backups) = await _dirs();
        final archive = createBackup(dataDir: data, backupsDir: backups);
        await _serviceFor(config).upload(archive.uri.pathSegments.last, await archive.readAsBytes());
        await _store?.update((preferences) => preferences.copyWith(lastBackupAt: DateTime.now()));
        _showStatus(_t('backupDone'), isError: false);
        await _list();
      });
    } finally {
      if (mounted) {
        setState(() => _backingUp = false);
      }
    }
  }

  /// Downloads the remote archive into the local backups tree and restores
  /// it — the same path the local slice restores from, restart included.
  Future<void> _restore(WebDavEntry entry) async {
    final config = _preferences.config;
    if (config == null || entry.isDirectory) {
      return;
    }
    final confirmed = await _confirm(title: _t('restore'), message: _t('restoreConfirm'), confirmLabel: _t('restore'));
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busyEntry = entry.href);
    try {
      final (data, backups) = await _dirs();
      final bytes = await _serviceFor(config).download(entry);
      final local = File('${backups.path}${Platform.pathSeparator}${_safeFileName(entry.name)}');
      await local.writeAsBytes(bytes, flush: true);
      restoreBackup(backup: local, dataDir: data);
      await _store?.update((preferences) => preferences.copyWith(lastRestoreAt: DateTime.now()));
      await Restart.restartApp();
    } on WebDavException catch (error) {
      _showStatus(_failureMessage(error), isError: true);
    } on Object catch (error) {
      _showStatus('$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyEntry = null);
      }
    }
  }

  Future<void> _deleteRemote(WebDavEntry entry) async {
    final confirmed = await _confirm(
      title: _t('delete'),
      message: _t('deleteConfirm'),
      confirmLabel: _t('delete'),
      danger: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busyEntry = entry.href);
    try {
      await _serviceFor(_preferences.config!).delete(entry);
      await _list();
    } on WebDavException catch (error) {
      _showStatus(_failureMessage(error), isError: true);
    } on Object catch (error) {
      _showStatus('$error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyEntry = null);
      }
    }
  }

  /// Keeps what a server returned from escaping the backups tree.
  String _safeFileName(String name) {
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

  @override
  Widget build(BuildContext context) {
    _seedForm();
    return PureScaffold(
      appBar: PureAppBar(title: _t('title')),
      body: _store == null
          ? const Center(child: PureLoading())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _buildForm(context),
                const SizedBox(height: 14),
                _buildActions(context),
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _status!,
                      style: TextStyle(
                        color: _statusIsError
                            ? PureTheme.of(context).colors.error
                            : PureTheme.of(context).colors.primary,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                _buildSyncTimes(context),
                const SizedBox(height: 18),
                _buildRemote(context),
                const SizedBox(height: 18),
                _buildHelp(context),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final colors = PureTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_t('sectionConfig'), style: PureTheme.of(context).text.title),
        const SizedBox(height: 8),
        PureTextField(
          controller: _addressController,
          placeholder: _t('addressHint'),
          keyboardType: TextInputType.url,
          enabled: !_busy,
          errorText: _addressError,
          onChanged: (_) => unawaited(_saveConfig(_formConfig)),
        ),
        const SizedBox(height: 10),
        PureTextField(
          controller: _usernameController,
          placeholder: _t('username'),
          enabled: !_busy,
          onChanged: (_) => unawaited(_saveConfig(_formConfig)),
        ),
        const SizedBox(height: 10),
        PureTextField(
          controller: _passwordController,
          placeholder: _t('password'),
          obscure: _obscurePassword,
          enabled: !_busy,
          onChanged: (_) => unawaited(_saveConfig(_formConfig)),
          suffix: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: colors.icon,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 10),
        PureTextField(
          controller: _directoryController,
          placeholder: _t('directory'),
          enabled: !_busy,
          onChanged: (_) => unawaited(_saveConfig(_formConfig)),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PureButton(
            label: _testing ? _t('testing') : _t('testConnection'),
            icon: Icons.wifi_tethering_outlined,
            variant: ButtonVariant.secondary,
            loading: _testing,
            onPressed: _busy && !_testing ? null : () => unawaited(_testConnection()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PureButton(
            label: _backingUp ? _t('backingUp') : _t('backupNow'),
            icon: Icons.cloud_upload_outlined,
            loading: _backingUp,
            onPressed: _busy && !_backingUp ? null : () => unawaited(_backupNow()),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncTimes(BuildContext context) {
    String when(DateTime? at) => at == null
        ? _t('never')
        : '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')} '
              '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return Column(
      children: [
        PureListRow(
          leading: const Icon(Icons.cloud_upload_outlined),
          title: _t('lastBackup'),
          subtitle: when(_preferences.lastBackupAt),
        ),
        PureListRow(
          leading: const Icon(Icons.cloud_download_outlined),
          title: _t('lastRestore'),
          subtitle: when(_preferences.lastRestoreAt),
          divided: false,
        ),
      ],
    );
  }

  Widget _buildRemote(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(_t('remote'), style: PureTheme.of(context).text.title)),
            PureIconButton(
              tooltip: context.t.common.retry,
              icon: Icons.refresh,
              onPressed: _busy ? null : () => unawaited(_list()),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_configReady)
          PureEmpty(title: _t('configIncomplete'))
        else if (_listing)
          const Center(child: PureLoading())
        else if (_entries.isEmpty)
          PureEmpty(title: _t('remoteEmpty'))
        else
          for (final entry in _entries)
            PureListRow(
              leading: Icon(
                entry.isDirectory ? Icons.folder_outlined : Icons.archive_outlined,
                color: PureTheme.of(context).colors.primary,
              ),
              title: entry.name,
              subtitle: switch (entry.modified) {
                null => null,
                final modified => _when(modified),
              },
              trailing: _busyEntry == entry.href
                  ? const PureSpinner()
                  : PureIconButton(
                      tooltip: context.t.backup.delete,
                      icon: Icons.delete_outline,
                      onPressed: _busy ? null : () => unawaited(_deleteRemote(entry)),
                    ),
              onTap: _busy || entry.isDirectory ? null : () => unawaited(_restore(entry)),
              divided: false,
            ),
      ],
    );
  }

  Widget _buildHelp(BuildContext context) {
    final colors = PureTheme.of(context).colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_t('helpTitle'), style: PureTheme.of(context).text.title),
        const SizedBox(height: 8),
        Text(_t('helpIntro'), style: PureTheme.of(context).text.bodySmall),
        const SizedBox(height: 8),
        Text(_t('helpSteps'), style: PureTheme.of(context).text.bodySmall),
        const SizedBox(height: 8),
        Text(_t('helpServer'), style: PureTheme.of(context).text.bodySmall.copyWith(color: colors.textSecondary)),
        Text(_t('helpAccount'), style: PureTheme.of(context).text.bodySmall.copyWith(color: colors.textSecondary)),
        Text(_t('helpPassword'), style: PureTheme.of(context).text.bodySmall.copyWith(color: colors.textSecondary)),
        Text(_t('helpIssues'), style: PureTheme.of(context).text.bodySmall.copyWith(color: colors.textSecondary)),
        const SizedBox(height: 10),
        PureButton(
          label: _t('openOfficialHelp'),
          icon: Icons.open_in_new,
          variant: ButtonVariant.secondary,
          onPressed: () => unawaited(_openOfficialHelp()),
        ),
      ],
    );
  }

  Future<void> _openOfficialHelp() async {
    final uri = Uri.parse('https://help.jianguoyun.com/?p=2064');
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      opened = false;
    }
    if (!opened) {
      _showStatus(_t('helpOpenFailed'), isError: true);
    }
  }

  static String _when(DateTime local) =>
      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
