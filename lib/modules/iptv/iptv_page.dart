import 'dart:async';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/modules/iptv/iptv_manage.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/core/iptv/services/epg_import_manager.dart';
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';
import 'package:pure_live/core/iptv/services/auto_sync_scheduler.dart';

class IptvPage extends StatefulWidget {
  const IptvPage({super.key, this.importFromNetwork, this.loadDefaultEpg});

  final Future<bool> Function(bool isEpg, String url, String name)? importFromNetwork;
  final Future<void> Function()? loadDefaultEpg;

  @override
  State<IptvPage> createState() => _IptvPageState();
}

class _IptvPageState extends State<IptvPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _initializing = false;
  String? _initializationErrorKey;
  bool _sourceDialogOpen = false;
  bool _networkDialogOpen = false;
  bool _networkImporting = false;

  final RxList<database.Provider> playlists = <database.Provider>[].obs;
  final RxList<database.EpgSource> epgSources = <database.EpgSource>[].obs;

  final RxBool isGlobalSyncing = false.obs;
  final RxBool isSyncingEpg = false.obs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    unawaited(_initializePageResources());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final db = Get.find<DbService>().db;
    final sources = await db.getAllEpgSources();
    if (!mounted) return;
    final providers = await db.getAllProviders();
    if (!mounted) return;
    epgSources.value = sources;
    playlists.value = providers;
    if (_initializationErrorKey != null &&
        (_initializationErrorKey == 'iptv_initial_load_failed' || sources.isNotEmpty)) {
      setState(() => _initializationErrorKey = null);
    }

    if (epgSources.isNotEmpty && SettingsService.to.iptv.selectedSourceId.v.isEmpty) {
      final activeSource = epgSources.first;
      SettingsService.to.iptv.selectedSourceId.v = activeSource.id;
      SettingsService.to.iptv.selectedSourceName.v = activeSource.name;
    }
  }

  Future<void> _initializePageResources() async {
    if (_initializing || !mounted) return;
    setState(() {
      _initializing = true;
      _initializationErrorKey = null;
    });
    var errorKey = 'iptv_initial_load_failed';
    try {
      await _refreshData();
      if (!mounted || epgSources.isNotEmpty) return;

      // Defaults are still imported only at feature entry, not ordinary startup.
      errorKey = 'iptv_default_epg_unavailable';
      await (widget.loadDefaultEpg ?? AutoSyncScheduler.instance.loadDefaultEpgResources)();
      if (!mounted) return;
      await _refreshData();
      if (mounted && epgSources.isEmpty) {
        setState(() => _initializationErrorKey = errorKey);
      }
    } catch (_) {
      if (mounted) setState(() => _initializationErrorKey = errorKey);
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _showSourceSelectionDialog() async {
    if (_sourceDialogOpen) return;
    _sourceDialogOpen = true;
    try {
      final db = Get.find<DbService>().db;
      final selected = await showDialog<database.EpgSource>(
        context: context,
        builder: (_) => _EpgSourceDialog(load: db.getAllEpgSources),
      );
      if (!mounted || selected == null) return;
      SettingsService.to.iptv.selectedSourceId.v = selected.id;
      SettingsService.to.iptv.selectedSourceName.v = selected.name;
      ToastUtil.show(i18n("epg_source_switched"));
    } finally {
      _sourceDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("iptv_settings"))),
      body: ListView(
        physics: const PureLiveScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          if (_initializing) ...[
            LinearProgressIndicator(semanticsLabel: i18n('refresh_loading')),
            const SizedBox(height: 12),
          ],
          if (_initializationErrorKey != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i18n(_initializationErrorKey!)),
                    TextButton(onPressed: _initializePageResources, child: Text(i18n('retry'))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          context.buildGroupTitle(i18n("iptv_manage")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.cloud_line,
              title: i18n("iptv_list_manage"),
              subtitle: i18n("download_guide_sub"),
              onTap: () => Get.to(() => const IptvManagePage()),
            ),
          ]),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n("auto_sync_settings")),
          context.buildModernCard([
            context.buildSwitchTile(
              icon: Remix.refresh_line,
              title: i18n("auto_sync_title"),
              subtitle: i18n("auto_sync_desc"),
              value: SettingsService.to.iptv.isAutoSyncEnabled,
            ),
            Obx(() {
              if (!SettingsService.to.iptv.isAutoSyncEnabled.v) return const SizedBox.shrink();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  context.buildTile(
                    icon: Remix.time_line,
                    title: i18n("sync_interval_title"),
                    subtitle: i18n(
                      "sync_interval_hours",
                      args: {"hour": "${SettingsService.to.iptv.autoSyncHoursInterval.v}"},
                    ),
                    onTap: () => _showIntervalSelectionMenu(context),
                  ),
                ],
              );
            }),
            Obx(
              () => context.buildTile(
                icon: Remix.tv_line,
                title: i18n("custom_ua_title"),
                subtitle: SettingsService.to.iptv.customIptvUserAgent.v,
                onTap: () => _showEditUserAgentDialog(context),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n("playlist_settings")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.download_2_line,
              title: i18n("import_playlist"),
              subtitle: i18n("playlist_file_type"),
              onTap: () => showIptvImportDialog(),
            ),
          ]),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n("epg_settings")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.file_add_line,
              title: i18n("import_epg_source"),
              subtitle: i18n("epg_file_type"),
              onTap: () => showEpgImportDialog(),
            ),
            Obx(
              () => context.buildTile(
                icon: Remix.tv_2_line,
                title: i18n("active_epg_source"),
                subtitle: SettingsService.to.iptv.selectedSourceId.v.isEmpty
                    ? i18n("please_select_epg_source")
                    : SettingsService.to.iptv.selectedSourceName.v,
                subtitleColor: SettingsService.to.iptv.selectedSourceId.v.isEmpty ? Colors.orange : null,
                onTap: () => _showSourceSelectionDialog(),
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _showEditUserAgentDialog(BuildContext context) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _UserAgentDialog(initialValue: SettingsService.to.iptv.customIptvUserAgent.v),
    );
    if (!mounted || value == null) return;
    SettingsService.to.iptv.customIptvUserAgent.v = value;
    ToastUtil.show(i18n("settings_saved"));
  }

  void _showIntervalSelectionMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final List<int> hoursOptions = [2, 6, 12, 24, 48, 72];

        return AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          title: Row(
            children: [
              Icon(Remix.time_line, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  i18n("select_sync_interval"),
                  style: AppTextStyles.t18.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: hoursOptions.map((hours) {
              return Material(
                color: Colors.transparent,
                child: Obx(() {
                  final bool isSelected = SettingsService.to.iptv.autoSyncHoursInterval.v == hours;

                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
                    leading: Icon(
                      isSelected ? Remix.checkbox_circle_fill : Remix.checkbox_blank_circle_line,
                      color: isSelected ? theme.colorScheme.primary : theme.hintColor.withValues(alpha: 0.5),
                      size: 22,
                    ),
                    title: Text(
                      "$hours ${i18n("hours")}",
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    onTap: () {
                      SettingsService.to.iptv.autoSyncHoursInterval.v = hours;
                      Navigator.of(context).pop();
                      ToastUtil.show(i18n("settings_saved"));
                    },
                  );
                }),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void showIptvImportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          title: Row(
            children: [
              Icon(Remix.play_list_add_line, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  i18n("dialog_import_playlist_title"),
                  style: AppTextStyles.t18.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(Remix.folder_open_line, color: theme.colorScheme.primary),
                  title: Text(i18n("local_import")),
                  onTap: () {
                    Navigator.of(context).pop();
                    IptvImportManager().importFromLocalPicker().then((_) => _refreshData());
                  },
                ),
              ),
              const SizedBox(height: 4),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(Remix.global_line, color: theme.colorScheme.primary),
                  title: Text(i18n("network_import")),
                  onTap: () {
                    Navigator.of(context).pop();
                    showEditTextDialog(isEpg: false);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void showEpgImportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          title: Row(
            children: [
              Icon(Remix.file_add_line, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  i18n("dialog_import_epg_title"),
                  style: AppTextStyles.t18.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(Remix.draft_line, color: theme.colorScheme.primary),
                  title: Text(i18n("local_import")),
                  onTap: () {
                    Navigator.of(context).pop();
                    EpgImportManager().importFromLocalPicker().then((_) => _refreshData());
                  },
                ),
              ),
              const SizedBox(height: 4),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(Remix.cloud_windy_line, color: theme.colorScheme.primary),
                  title: Text(i18n("network_import")),
                  onTap: () {
                    Navigator.of(context).pop();
                    showEditTextDialog(isEpg: true);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> showEditTextDialog({required bool isEpg}) async {
    if (_networkDialogOpen) return;
    if (_networkImporting) {
      ToastUtil.show(i18n("iptv_import_in_progress"));
      return;
    }
    _networkDialogOpen = true;
    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _NetworkImportDialog(
          submit: (url, name) async {
            if (_networkImporting) return false;
            _networkImporting = true;
            try {
              final success = widget.importFromNetwork != null
                  ? await widget.importFromNetwork!(isEpg, url, name)
                  : isEpg
                  ? await EpgImportManager().importFromNetworkUrl(url, name)
                  : await IptvImportManager().importFromNetworkUrl(url, name);
              if (success && mounted) {
                try {
                  await _refreshData();
                } catch (_) {
                  if (mounted) ToastUtil.show(i18n('iptv_import_refresh_failed'));
                }
              }
              return success;
            } finally {
              _networkImporting = false;
            }
          },
        ),
      );
    } finally {
      _networkDialogOpen = false;
    }
  }
}

// Draft fields belong to the route subtree, not the earlier pop-result Future.
class _UserAgentDialog extends StatefulWidget {
  const _UserAgentDialog({required this.initialValue});
  final String initialValue;
  @override
  State<_UserAgentDialog> createState() => _UserAgentDialogState();
}

class _UserAgentDialogState extends State<_UserAgentDialog> {
  static const double _minInputHeight = 120;
  static const double _maxInputHeight = 360;
  static const double _inputResizeStep = 48;

  late final TextEditingController controller;
  final RxDouble customInputHeight = 144.0.obs;

  void _setInputHeight(double value) {
    customInputHeight.value = value.clamp(_minInputHeight, _maxInputHeight).toDouble();
  }

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    controller.dispose();
    customInputHeight.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final dialogWidth = constraints.maxWidth > 640 ? 560.0 : constraints.maxWidth * 0.9;

        return AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          actionsPadding: const EdgeInsets.only(bottom: 16, right: 24, left: 24),
          title: Row(
            children: [
              Icon(Remix.tv_line, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(i18n("edit_ua_title"), style: AppTextStyles.t18.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i18n("custom_ua_desc"), style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 16),
                Obx(() {
                  final inputHeight = customInputHeight.value;
                  final canShrink = inputHeight > _minInputHeight;
                  final canGrow = inputHeight < _maxInputHeight;
                  final resizeLabel = i18n('edit_ua_title');
                  return Container(
                    height: inputHeight,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            maxLines: null,
                            expands: true,
                            maxLength: 500,
                            decoration: InputDecoration(
                              hintText: "Mozilla/5.0...",
                              border: InputBorder.none,
                              counterText: "",
                              contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                              suffixIcon: IconButton(
                                tooltip: i18n('clear'),
                                icon: const Icon(Remix.close_circle_line, size: 18),
                                onPressed: () => controller.clear(),
                              ),
                            ),
                            style: AppTextStyles.t13.copyWith(fontFamily: 'monospace'),
                          ),
                        ),
                        Container(
                          height: kMinInteractiveDimension,
                          decoration: BoxDecoration(
                            color: theme.dividerColor.withValues(alpha: 0.03),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(14),
                              bottomRight: Radius.circular(14),
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                key: const ValueKey('iptv-user-agent-resize-decrease'),
                                tooltip: i18n('decrease_value', args: {'label': resizeLabel}),
                                onPressed: canShrink ? () => _setInputHeight(inputHeight - _inputResizeStep) : null,
                                icon: const Icon(Icons.remove_rounded),
                              ),
                              Expanded(
                                child: Semantics(
                                  label: resizeLabel,
                                  value: '${inputHeight.round()} px',
                                  increasedValue:
                                      '${(inputHeight + _inputResizeStep).clamp(_minInputHeight, _maxInputHeight).round()} px',
                                  decreasedValue:
                                      '${(inputHeight - _inputResizeStep).clamp(_minInputHeight, _maxInputHeight).round()} px',
                                  onIncrease: canGrow ? () => _setInputHeight(inputHeight + _inputResizeStep) : null,
                                  onDecrease: canShrink ? () => _setInputHeight(inputHeight - _inputResizeStep) : null,
                                  child: GestureDetector(
                                    key: const ValueKey('iptv-user-agent-resize-handle'),
                                    behavior: HitTestBehavior.opaque,
                                    onVerticalDragUpdate: (details) =>
                                        _setInputHeight(customInputHeight.value + details.delta.dy),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.drag_indicator_rounded,
                                          size: 20,
                                          color: theme.hintColor.withValues(alpha: 0.65),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${inputHeight.round()} px',
                                          style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                key: const ValueKey('iptv-user-agent-resize-increase'),
                                tooltip: i18n('increase_value', args: {'label': resizeLabel}),
                                onPressed: canGrow ? () => _setInputHeight(inputHeight + _inputResizeStep) : null,
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n("cancel"))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () {
                final trimmedValue = controller.text.trim();
                Navigator.of(context).pop(trimmedValue);
              },
              child: Text(i18n("confirm")),
            ),
          ],
        );
      },
    );
  }
}

class _NetworkImportDialog extends StatefulWidget {
  const _NetworkImportDialog({required this.submit});
  final Future<bool> Function(String url, String name) submit;
  @override
  State<_NetworkImportDialog> createState() => _NetworkImportDialogState();
}

class _NetworkImportDialogState extends State<_NetworkImportDialog> {
  final _url = TextEditingController();
  final _name = TextEditingController();
  bool _submitting = false;
  String? _errorKey;

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final url = _url.text.trim();
    final name = _name.text.trim();
    final validation = url.isEmpty
        ? 'enter_download_link'
        : !FileUtils.isValidUrl(url)
        ? 'invalid_download_link'
        : name.isEmpty
        ? 'enter_file_name'
        : null;
    if (validation != null) {
      setState(() => _errorKey = validation);
      return;
    }
    setState(() {
      _submitting = true;
      _errorKey = null;
    });
    final route = ModalRoute.of(context)!;
    final navigator = Navigator.of(context);
    var succeeded = false;
    try {
      succeeded = await widget.submit(url, name);
    } catch (_) {
      // Keep the editable draft and expose a generic failure, not server credentials.
    }
    if (!mounted) return;
    if (succeeded) {
      // A newer route may cover this dialog while its request completes.
      // Finish only our own route, never pop that newer UI using global context.
      if (route.isCurrent) {
        navigator.pop(true);
      } else if (route.isActive) {
        navigator.removeRoute(route, true);
      }
    } else {
      setState(() {
        _submitting = false;
        _errorKey = 'network_import_failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(i18n('enter_download_url')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _url,
              readOnly: _submitting,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(12),
                hintText: i18n('download_url'),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              readOnly: _submitting,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.all(12),
                hintText: i18n('file_name'),
              ),
            ),
            if (_errorKey != null) ...[
              const SizedBox(height: 12),
              Text(i18n(_errorKey!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_submitting) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(i18n('iptv_import_close_hint')),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n(_submitting ? 'close' : 'cancel'))),
        TextButton(onPressed: _submitting ? null : _submit, child: Text(i18n('confirm'))),
      ],
    );
  }
}

class _EpgSourceDialog extends StatefulWidget {
  const _EpgSourceDialog({required this.load});
  final Future<List<database.EpgSource>> Function() load;
  @override
  State<_EpgSourceDialog> createState() => _EpgSourceDialogState();
}

class _EpgSourceDialogState extends State<_EpgSourceDialog> {
  bool _loading = false;
  bool _failed = false;
  List<database.EpgSource> _sources = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final sources = List<database.EpgSource>.unmodifiable(await widget.load());
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Widget _content(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed || _sources.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(i18n(_failed ? 'epg_sources_load_failed' : 'no_epg_sources_found')),
            if (_failed) TextButton(onPressed: _load, child: Text(i18n('retry'))),
          ],
        ),
      );
    }
    return ListView.separated(
      physics: const PureLiveScrollPhysics(),
      itemCount: _sources.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final source = _sources[index];
        return Obx(() {
          final selected = SettingsService.to.iptv.selectedSourceId.v == source.id;
          return Card(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25)
                : Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(source),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).unselectedWidgetColor,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(source.name, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(
                            source.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Theme.of(context).hintColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => AlertDialog(
        scrollable: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.only(left: 24, top: 16, right: 12, bottom: 8),
        contentPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 12),
        title: Row(
          children: [
            Expanded(
              child: Text(i18n('select_epg_source'), style: AppTextStyles.t11.copyWith(fontWeight: FontWeight.bold)),
            ),
            IconButton(
              tooltip: i18n('close'),
              icon: const Icon(Icons.close, size: 22),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          height: (constraints.maxHeight * 0.6).clamp(100.0, 400.0),
          child: _content(context),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n('cancel')))],
      ),
    );
  }
}
