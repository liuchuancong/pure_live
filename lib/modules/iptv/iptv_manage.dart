import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/core/iptv/services/epg_sync_manager.dart';
import 'package:pure_live/core/iptv/services/iptv_sync_engine.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;

class IptvManagePage extends StatefulWidget {
  const IptvManagePage({super.key});

  @override
  State<IptvManagePage> createState() => _IptvManagePageState();
}

class _IptvManagePageState extends State<IptvManagePage> {
  final RxList<database.Provider> playlists = <database.Provider>[].obs;
  final RxList<database.EpgSource> epgSources = <database.EpgSource>[].obs;
  final RxBool isSyncingAll = false.obs;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    SmartDialog.showLoading();
    final db = Get.find<DbService>().db;
    playlists.value = await db.getAllProviders();
    epgSources.value = await db.getAllEpgSources();
    SmartDialog.dismiss();
  }

  Future<void> _syncAll() async {
    if (isSyncingAll.value) return;

    final networkPlaylists = playlists
        .where(
          (p) =>
              p.url != null &&
              (p.url!.startsWith('http://') || p.url!.startsWith('https://')) &&
              p.isAutoUpdate == true,
        )
        .toList();
    final networkEpgs = epgSources
        .where(
          (e) =>
              e.url.isNotEmpty &&
              (e.url.startsWith('http://') || e.url.startsWith('https://')) &&
              e.isAutoUpdate == true,
        )
        .toList();

    if (networkPlaylists.isEmpty && networkEpgs.isEmpty) {
      ToastUtil.show(i18n("manage_page_empty_tip"));
      return;
    }

    isSyncingAll.value = true;
    ToastUtil.show(i18n("manage_page_syncing"));

    try {
      for (var playlist in networkPlaylists) {
        await IptvSyncEngine.instance.syncPlaylist(playlist);
      }
      for (var epg in networkEpgs) {
        await EpgSyncManager().updateEpgCache(downloadUrl: epg.url, sourceName: epg.name);
      }
      await _refreshData();
      ToastUtil.show(i18n("manage_page_success"));
    } catch (e) {
      debugPrint("$e");
      ToastUtil.show(i18n("manage_page_failed"));
    } finally {
      isSyncingAll.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = Get.find<SettingsService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n("manage_page_title")),
        actions: [
          Obx(
            () => IconButton(
              icon: isSyncingAll.value
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Remix.refresh_line),
              onPressed: isSyncingAll.value ? null : () => _syncAll(),
            ),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          SectionTitle(title: i18n("manage_page_network_section")),
          Obx(() => _buildPlaylistSection(theme)),

          const SizedBox(height: 16),
          SectionTitle(title: i18n("manage_page_epg_section")),
          Obx(() => _buildEpgSection(theme)),

          const SizedBox(height: 16),
          SectionTitle(title: i18n("auto_sync_settings")),

          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1), width: 1),
              boxShadow: [
                BoxShadow(color: theme.shadowColor.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Obx(
                  () => SwitchListTile(
                    secondary: Icon(
                      Remix.time_line,
                      color: settings.isAutoSyncEnabled.value ? theme.colorScheme.primary : theme.hintColor,
                    ),
                    title: Text(
                      i18n("enable_auto_sync"),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    subtitle: Text(
                      i18n("enable_auto_sync_subtitle"),
                      style: TextStyle(color: theme.hintColor, fontSize: 12),
                    ),
                    value: settings.isAutoSyncEnabled.value,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20), bottom: Radius.circular(20)),
                    ),
                    onChanged: (bool value) {
                      settings.isAutoSyncEnabled.value = value;
                    },
                  ),
                ),

                Obx(
                  () => AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      children: [
                        Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withValues(alpha: 0.1)),
                        ListTile(
                          leading: Icon(Remix.hourglass_line, color: theme.colorScheme.primary),
                          title: Text(
                            i18n("sync_interval"),
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                          ),
                          subtitle: Text(
                            "${settings.autoSyncHoursInterval.value} ${i18n("hours")}",
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right, color: theme.hintColor, size: 20),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                          ),
                          onTap: () => _showIntervalSelectionDialog(context),
                        ),
                      ],
                    ),
                    crossFadeState: settings.isAutoSyncEnabled.value
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 250),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showIntervalSelectionDialog(BuildContext context) {
    final intervals = [6, 12, 24, 48];
    final settings = Get.find<SettingsService>();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(i18n("sync_interval")),
        content: SizedBox(
          width: 280,
          child: Obx(
            () => RadioGroup<int>(
              groupValue: settings.autoSyncHoursInterval.value,
              onChanged: (int? value) {
                if (value != null) {
                  settings.autoSyncHoursInterval.value = value;
                  Navigator.of(context).pop();
                  ToastUtil.show(i18n("manage_page_success"));
                }
              },
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: intervals.length,
                itemBuilder: (context, index) {
                  final hours = intervals[index];
                  return RadioListTile<int>(title: Text("$hours ${i18n("hours")}"), value: hours);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistSection(ThemeData theme) {
    final networkLists = playlists
        .where((p) => p.url != null && (p.url!.startsWith('http://') || p.url!.startsWith('https://')))
        .toList();
    if (networkLists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(i18n("manage_page_empty_tip"), style: TextStyle(color: theme.hintColor)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: networkLists.length,
      itemBuilder: (context, index) {
        final item = networkLists[index];
        return ListTile(
          leading: Icon(Remix.file_list_3_line, color: theme.colorScheme.primary),
          title: Text(item.name, style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
          subtitle: Text(
            item.url!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: theme.hintColor),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      i18n("auto_sync_tag"),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: item.isAutoUpdate ? theme.colorScheme.primary : theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 24,
                      child: Transform.scale(
                        scale: 0.75,
                        child: Switch(
                          value: item.isAutoUpdate,
                          activeThumbColor: theme.colorScheme.primary,
                          onChanged: (bool value) async {
                            final db = Get.find<DbService>().db;
                            await db.updateProviderUpdateStatus(item.id, value);
                            await _refreshData();
                            ToastUtil.show(value ? "${item.name} ${i18n('enable_auto_sync')}" : "${item.name} 已跳过自动同步");
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Remix.download_cloud_line),
                color: theme.colorScheme.primary,
                onPressed: () async {
                  ToastUtil.show(i18n("manage_page_single_syncing"));
                  await IptvSyncEngine.instance.syncPlaylist(item);
                  await _refreshData();
                },
              ),
              IconButton(
                icon: Icon(Remix.delete_bin_line, color: theme.colorScheme.error),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text(i18n("delete_confirm_title")),
                        content: Text(i18n("delete_confirm_message")),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n("cancel"))),
                          TextButton(
                            onPressed: () async {
                              final db = Get.find<DbService>().db;
                              await db.deleteProviderCascading(item.id);
                              playlists.remove(item);
                              Navigator.of(Get.context!).pop();
                              ToastUtil.show(i18n("manage_page_delete_success"));
                            },
                            child: Text(i18n("confirm"), style: TextStyle(color: theme.colorScheme.error)),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEpgSection(ThemeData theme) {
    final networkEpgs = epgSources
        .where((e) => e.url.isNotEmpty && (e.url.startsWith('http://') || e.url.startsWith('https://')))
        .toList();
    if (networkEpgs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(i18n("manage_page_empty_tip"), style: TextStyle(color: theme.hintColor)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: networkEpgs.length,
      itemBuilder: (context, index) {
        final source = networkEpgs[index];
        return ListTile(
          leading: Icon(Remix.tv_2_line, color: theme.hintColor.withValues(alpha: 0.6)),
          title: Text(source.name, style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
          subtitle: Text(
            source.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: theme.hintColor),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      i18n("auto_sync_tag"),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: source.isAutoUpdate ? theme.colorScheme.primary : theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 24,
                      child: Transform.scale(
                        scale: 0.75,
                        child: Switch(
                          value: source.isAutoUpdate,
                          activeThumbColor: theme.colorScheme.primary,
                          onChanged: (bool value) async {
                            final db = Get.find<DbService>().db;
                            await db.updateEpgSourceUpdateStatus(source.id, value);
                            await _refreshData();
                            ToastUtil.show(
                              value ? "${source.name} ${i18n('enable_auto_sync')}" : "${source.name} 已跳过自动同步",
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Remix.download_cloud_line),
                color: theme.colorScheme.primary,
                onPressed: () async {
                  ToastUtil.show(i18n("manage_page_single_syncing"));
                  await EpgSyncManager().updateEpgCache(
                    downloadUrl: source.url,
                    sourceName: source.name,
                    forceUpdate: true,
                  );
                  await _refreshData();
                },
              ),
              IconButton(
                icon: Icon(Remix.delete_bin_line, color: theme.colorScheme.error),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text(i18n("delete_confirm_title")),
                        content: Text(i18n("delete_confirm_message")),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n("cancel"))),
                          TextButton(
                            onPressed: () async {
                              final db = Get.find<DbService>().db;
                              await db.deleteEpgSourceCascading(source.id);
                              epgSources.remove(source);
                              Navigator.of(Get.context!).pop();
                              ToastUtil.show(i18n("manage_page_delete_success"));
                            },
                            child: Text(i18n("confirm"), style: TextStyle(color: theme.colorScheme.error)),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
