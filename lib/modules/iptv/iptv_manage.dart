import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/core/iptv/services/epg_sync_engine.dart';
import 'package:pure_live/core/iptv/services/iptv_sync_engine.dart';

enum ManageItemType { iptv, epg }

class ManageItem {
  final String id;
  final String name;
  final String url;
  final bool isNetwork;
  final bool isAutoSync;
  final ManageItemType type;
  final dynamic raw;

  ManageItem({
    required this.id,
    required this.name,
    required this.url,
    required this.isNetwork,
    required this.isAutoSync,
    required this.type,
    required this.raw,
  });
}

class ResourceGroup {
  final String title;
  final IconData icon;
  final List<ManageItem> items;

  ResourceGroup({required this.title, required this.icon, required this.items});
  bool get isNotEmpty => items.isNotEmpty;
}

class IptvManagePage extends StatefulWidget {
  const IptvManagePage({super.key});

  @override
  State<IptvManagePage> createState() => _IptvManagePageState();
}

class _IptvManagePageState extends State<IptvManagePage> {
  final RxList<ManageItem> allItems = <ManageItem>[].obs;

  final RxBool isSyncingAll = false.obs;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  bool _isNetwork(String url) {
    return url.startsWith("http://") || url.startsWith("https://");
  }

  Future<void> _refreshData() async {
    final db = Get.find<DbService>().db;

    SmartDialog.showLoading();

    try {
      final playlists = await db.getAllProviders();

      final epgs = await db.getAllEpgSources();

      final List<ManageItem> items = [];

      for (final item in playlists) {
        items.add(
          ManageItem(
            id: item.id,
            name: item.name,
            url: item.url ?? "",
            isNetwork: _isNetwork(item.url ?? ""),
            isAutoSync: item.isAutoUpdate,
            type: ManageItemType.iptv,
            raw: item,
          ),
        );
      }

      for (final item in epgs) {
        items.add(
          ManageItem(
            id: item.id,
            name: item.name,
            url: item.url,
            isNetwork: _isNetwork(item.url),
            isAutoSync: item.isAutoUpdate,
            type: ManageItemType.epg,
            raw: item,
          ),
        );
      }

      items.sort((a, b) {
        if (a.isNetwork == b.isNetwork) {
          return 0;
        }

        return a.isNetwork ? -1 : 1;
      });

      allItems.value = items;
    } finally {
      SmartDialog.dismiss();
    }
  }

  Future<void> _syncAll() async {
    if (isSyncingAll.value) return;

    final syncItems = allItems.where((e) => e.isNetwork && e.isAutoSync).toList();

    if (syncItems.isEmpty) {
      ToastUtil.show(i18n("manage_page_empty_tip"));
      return;
    }

    isSyncingAll.value = true;

    ToastUtil.show(i18n("manage_page_syncing"));

    try {
      for (final item in syncItems) {
        if (item.type == ManageItemType.iptv) {
          await IptvSyncEngine.instance.syncPlaylist(item.raw);
        } else {
          await EpgSyncEngine.instance.updateEpgCache(item.raw, forceUpdate: true);
        }
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
              onPressed: isSyncingAll.value ? null : _syncAll,
              icon: isSyncingAll.value
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Remix.refresh_line),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final networkItems = allItems.where((e) => e.isNetwork).toList();
        final localItems = allItems.where((e) => !e.isNetwork).toList();
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _buildStatsCard(theme)),
            ),

            if (networkItems.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: _buildSectionTitle(theme, i18n("network_resource"), Remix.global_line),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: networkItems.length,
                  itemBuilder: (_, index) {
                    return _buildItemCard(theme, networkItems[index]);
                  },
                ),
              ),
            ],

            if (localItems.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: _buildSectionTitle(theme, i18n("local_resource"), Remix.folder_2_line),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: localItems.length,
                  itemBuilder: (_, index) {
                    return _buildItemCard(theme, localItems[index]);
                  },
                ),
              ),
            ],

            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        );
      }),
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    final networkCount = allItems.where((e) => e.isNetwork).length;

    final playlistCount = allItems.where((e) => e.type == ManageItemType.iptv).length;

    final epgCount = allItems.where((e) => e.type == ManageItemType.epg).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: [theme.colorScheme.primary.withValues(alpha: 0.12), theme.cardColor]),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(theme, "IPTV", playlistCount.toString(), Remix.play_list_2_line),
          _buildStatItem(theme, "EPG", epgCount.toString(), Remix.tv_2_line),
          _buildStatItem(theme, i18n("network_tag"), networkCount.toString(), Remix.global_line),
        ],
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 10),
        Text(value, style: AppTextStyles.t12.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(title, style: AppTextStyles.t11.copyWith(color: theme.hintColor)),
      ],
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.t12.copyWith(fontSize: 17, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildItemCard(ThemeData theme, ManageItem item) {
    String formatText = 'M3U';
    final String lowercaseUrl = item.url.toLowerCase();

    if (item.type == ManageItemType.epg) {
      formatText = lowercaseUrl.endsWith('.gz') ? 'XML.GZ' : 'EPG';
    } else if (lowercaseUrl.contains('.txt') || (item.raw.type?.toLowerCase() == 'txt')) {
      formatText = 'TXT';
    } else if (lowercaseUrl.contains('.json') || (item.raw.type?.toLowerCase() == 'json')) {
      formatText = 'JSON';
    } else if (lowercaseUrl.endsWith('.gz') || (item.raw.type?.toLowerCase() == 'gz')) {
      formatText = 'GZ';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: theme.shadowColor.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            FileUtils.openFileOrUrl(item.url);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // 💡 核心注入点：将处理好的格式标识以及主题传入原本的图标构建方法中
                    _buildLeadingIconWithBadge(theme, item, formatText),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w700),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            item.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: theme.hintColor),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    _buildTag(theme, item),
                  ],
                ),

                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth <= 680;
                    if (compact) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              if (item.isNetwork) ...[
                                Expanded(
                                  child: _buildActionButton(
                                    theme,
                                    icon: Remix.download_cloud_2_line,
                                    label: i18n("sync"),
                                    onTap: () async {
                                      ToastUtil.show(i18n("manage_page_single_syncing"));
                                      if (item.type == ManageItemType.iptv) {
                                        await IptvSyncEngine.instance.syncPlaylist(item.raw, showTips: true);
                                      } else {
                                        await EpgSyncEngine.instance.updateEpgCache(item.raw, forceUpdate: true);
                                      }

                                      await _refreshData();
                                    },
                                  ),
                                ),

                                const SizedBox(width: 10),
                              ],

                              Expanded(
                                child: _buildActionButton(
                                  theme,
                                  icon: Remix.delete_bin_6_line,
                                  label: i18n("webdav_delete"),
                                  danger: true,
                                  onTap: () {
                                    _showDeleteDialog(item);
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (item.isNetwork) ...[const SizedBox(height: 10), _buildSwitchButton(theme, item)],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        if (item.isNetwork) ...[
                          Expanded(
                            child: _buildActionButton(
                              theme,
                              icon: Remix.download_cloud_2_line,
                              label: i18n("sync"),
                              onTap: () async {
                                ToastUtil.show(i18n("manage_page_single_syncing"));

                                if (item.type == ManageItemType.iptv) {
                                  await IptvSyncEngine.instance.syncPlaylist(item.raw, showTips: true);
                                } else {
                                  await EpgSyncEngine.instance.updateEpgCache(item.raw, forceUpdate: true);
                                }

                                await _refreshData();
                              },
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(child: _buildSwitchButton(theme, item)),

                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _buildActionButton(
                            theme,
                            icon: Remix.delete_bin_6_line,
                            label: i18n("webdav_delete"),
                            danger: true,
                            onTap: () {
                              _showDeleteDialog(item);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIconWithBadge(ThemeData theme, ManageItem item, String formatText) {
    Color badgeColor = theme.colorScheme.primary; // M3U 使用主色
    if (formatText == 'TXT') badgeColor = Colors.orange; // TXT 亮橙
    if (formatText == 'EPG') badgeColor = Colors.teal; // Epg/Xml 薄荷绿
    if (formatText == 'JSON') badgeColor = Colors.purple; // JSON 高级紫
    if (formatText == 'GZ' || formatText == 'XML.GZ') {
      badgeColor = theme.brightness == Brightness.dark ? Colors.blueGrey[400]! : Colors.blueGrey[600]!;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildLeadingIcon(theme, item),
        Positioned(
          right: -4,
          bottom: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.cardColor, width: 2), // 白色/暗色描边切断视觉背景
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Text(
              formatText,
              style: AppTextStyles.t12.copyWith(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeadingIcon(ThemeData theme, ManageItem item) {
    final isPlaylist = item.type == ManageItemType.iptv;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: isPlaylist ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        isPlaylist ? Remix.play_list_2_line : Remix.tv_2_line,
        color: isPlaylist ? theme.colorScheme.primary : Colors.orange,
      ),
    );
  }

  Widget _buildTag(ThemeData theme, ManageItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: item.isNetwork ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        item.isNetwork ? i18n("network_tag") : i18n("local_tag"),
        style: TextStyle(color: item.isNetwork ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionButton(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? theme.colorScheme.error : theme.colorScheme.primary;

    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),

              const SizedBox(width: 6),

              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchButton(ThemeData theme, ManageItem item) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Remix.repeat_line, size: 16, color: theme.colorScheme.primary),

              const SizedBox(width: 6),

              Text(
                i18n("auto_sync"),
                style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
              ),
            ],
          ),

          Switch(
            value: item.isAutoSync,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeThumbColor: theme.colorScheme.primary,

            onChanged: (value) async {
              final db = Get.find<DbService>().db;

              if (item.type == ManageItemType.iptv) {
                await db.updateProviderUpdateStatus(item.id, value);
              } else {
                await db.updateEpgSourceUpdateStatus(item.id, value);
              }

              final index = allItems.indexOf(item);

              allItems[index] = ManageItem(
                id: item.id,
                name: item.name,
                url: item.url,
                isNetwork: item.isNetwork,
                isAutoSync: value,
                type: item.type,
                raw: item.raw,
              );

              allItems.value = [...allItems];

              ToastUtil.show(value ? i18n("auto_sync_tag") : i18n("auto_sync_disabled"));
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(ManageItem item) {
    final theme = Theme.of(context);

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(i18n("delete_confirm_title")),
        content: Text(i18n("delete_confirm_message")),
        actions: [
          TextButton(onPressed: () => Navigator.of(Get.context!).pop(), child: Text(i18n("cancel"))),
          TextButton(
            onPressed: () async {
              final db = Get.find<DbService>().db;
              if (item.type == ManageItemType.iptv) {
                await db.deleteProviderCascading(item.id);
              } else {
                await db.deleteEpgSourceCascading(item.id);
              }
              allItems.remove(item);
              Navigator.of(Get.context!).pop();
              ToastUtil.show(i18n("manage_page_delete_success"));
            },
            child: Text(i18n("confirm"), style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
