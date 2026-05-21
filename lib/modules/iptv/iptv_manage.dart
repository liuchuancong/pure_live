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
        .where((p) => p.url != null && (p.url!.startsWith('http://') || p.url!.startsWith('https://')))
        .toList();
    final networkEpgs = epgSources
        .where((e) => e.url.isNotEmpty && (e.url.startsWith('http://') || e.url.startsWith('https://')))
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
        await EpgSyncManager().updateEpgCache(sourceName: epg.name, downloadUrl: epg.url, forceUpdate: true);
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
        children: [
          SectionTitle(title: i18n("manage_page_network_section")),
          Obx(() => _buildPlaylistSection(theme)),
          const Divider(height: 1, thickness: 0.5),
          SectionTitle(title: i18n("manage_page_epg_section")),
          Obx(() => _buildEpgSection(theme)),
        ],
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
              IconButton(
                icon: const Icon(Remix.download_cloud_line),
                color: theme.colorScheme.primary,
                onPressed: () async {
                  ToastUtil.show(i18n("manage_page_single_syncing"));
                  await EpgSyncManager().updateEpgCache(downloadUrl: source.url, sourceName: source.name);
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
