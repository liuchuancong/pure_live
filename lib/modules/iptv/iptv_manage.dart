import 'dart:async';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/core/iptv/services/epg_sync_engine.dart';
import 'package:pure_live/core/iptv/services/iptv_sync_engine.dart';
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';

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
  final Set<String> _busyItems = <String>{};
  bool _loading = true;
  String? _loadErrorKey;
  int _refreshEpoch = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshData());
  }

  bool _isNetwork(String url) {
    return url.startsWith("http://") || url.startsWith("https://");
  }

  String _operationKey(ManageItem item) => '${item.type.name}:${item.id}';

  bool _itemActionsBlocked(ManageItem item) => isSyncingAll.value || _busyItems.contains(_operationKey(item));

  Future<bool> _refreshData() async {
    final epoch = ++_refreshEpoch;
    if (mounted) {
      setState(() {
        _loading = true;
        _loadErrorKey = null;
      });
    }
    final db = Get.find<DbService>().db;
    try {
      final playlists = await db.getAllProviders();
      if (!mounted || epoch != _refreshEpoch) return false;
      final epgs = await db.getAllEpgSources();
      if (!mounted || epoch != _refreshEpoch) return false;
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
        final networkOrder = (a.isNetwork ? 0 : 1).compareTo(b.isNetwork ? 0 : 1);
        if (networkOrder != 0) return networkOrder;
        final typeOrder = a.type.index.compareTo(b.type.index);
        if (typeOrder != 0) return typeOrder;
        final nameOrder = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return nameOrder != 0 ? nameOrder : a.id.compareTo(b.id);
      });

      allItems.value = items;
      return true;
    } catch (_) {
      if (mounted && epoch == _refreshEpoch) {
        setState(() => _loadErrorKey = 'manage_page_load_failed_title');
      }
      return false;
    } finally {
      if (mounted && epoch == _refreshEpoch) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _refreshEpoch++;
    super.dispose();
  }

  Future<void> _syncAll() async {
    if (isSyncingAll.value || _loading || _busyItems.isNotEmpty) return;

    final syncItems = allItems.where((e) => e.isNetwork && e.isAutoSync).toList();

    if (syncItems.isEmpty) {
      ToastUtil.show(i18n("manage_page_empty_tip"));
      return;
    }

    isSyncingAll.value = true;

    ToastUtil.show(i18n("manage_page_syncing"));

    try {
      var allSucceeded = true;
      for (final item in syncItems) {
        if (!mounted) return;
        final bool succeeded;
        if (item.type == ManageItemType.iptv) {
          succeeded = await IptvSyncEngine.instance.syncPlaylist(item.raw);
        } else {
          succeeded = await EpgSyncEngine.instance.updateEpgCache(item.raw, forceUpdate: true);
        }
        allSucceeded = allSucceeded && succeeded;
      }

      final refreshed = await _refreshData();
      if (mounted) ToastUtil.show(i18n(allSucceeded && refreshed ? 'manage_page_success' : 'manage_page_failed'));
    } catch (e) {
      debugPrint("$e");
      if (mounted) ToastUtil.show(i18n("manage_page_failed"));
    } finally {
      isSyncingAll.value = false;
    }
  }

  Future<void> _syncItem(ManageItem item) async {
    final key = _operationKey(item);
    if (isSyncingAll.value || _busyItems.contains(key)) return;
    setState(() => _busyItems.add(key));
    if (mounted) ToastUtil.show(i18n('manage_page_single_syncing'));
    try {
      final bool succeeded;
      if (item.type == ManageItemType.iptv) {
        succeeded = await IptvSyncEngine.instance.syncPlaylist(item.raw);
      } else {
        succeeded = await EpgSyncEngine.instance.updateEpgCache(item.raw, forceUpdate: true);
      }
      final refreshed = mounted ? await _refreshData() : false;
      if (mounted) ToastUtil.show(i18n(succeeded && refreshed ? 'manage_page_success' : 'manage_page_failed'));
    } catch (error) {
      debugPrint('$error');
      if (mounted) ToastUtil.show(i18n('manage_page_failed'));
    } finally {
      _busyItems.remove(key);
      if (mounted) setState(() {});
    }
  }

  Future<void> _openItemSource(ManageItem item) async {
    final key = _operationKey(item);
    if (isSyncingAll.value || _busyItems.contains(key)) return;
    setState(() => _busyItems.add(key));
    try {
      final opened = await FileUtils.openFileOrUrl(item.url);
      if (!opened && mounted) ToastUtil.show(i18n('manage_page_open_failed'));
    } catch (_) {
      if (mounted) ToastUtil.show(i18n('manage_page_open_failed'));
    } finally {
      _busyItems.remove(key);
      if (mounted) setState(() {});
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
              tooltip: i18n('sync'),
              onPressed: isSyncingAll.value || _loading || _busyItems.isNotEmpty ? null : _syncAll,
              icon: isSyncingAll.value
                  ? AppStatusView(type: AppStatusType.loading, title: "", subtitle: "", isMini: true)
                  : const Icon(Remix.refresh_line),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final networkItems = allItems.where((e) => e.isNetwork).toList();
        final localItems = allItems.where((e) => !e.isNetwork).toList();
        return CustomScrollView(
          physics: const PureLiveScrollPhysics(),
          slivers: [
            if (_loading) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
            if (_loadErrorKey != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildStateCard(
                    theme,
                    icon: Remix.error_warning_line,
                    title: i18n(_loadErrorKey!),
                    subtitle: i18n('manage_page_load_failed_subtitle'),
                    actionLabel: i18n('retry'),
                    onAction: _loading ? null : _refreshData,
                  ),
                ),
              ),
            if (!_loading && _loadErrorKey == null && allItems.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildStateCard(
                    theme,
                    icon: Remix.play_list_add_line,
                    title: i18n('manage_page_empty_title'),
                    subtitle: i18n('manage_page_empty_subtitle'),
                  ),
                ),
              ),
            if (allItems.isNotEmpty)
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

  Widget _buildStateCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle, style: AppTextStyles.t13.copyWith(color: theme.hintColor)),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(onPressed: onAction, icon: const Icon(Remix.refresh_line), label: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme) {
    final networkCount = allItems.where((e) => e.isNetwork).length;

    final playlistCount = allItems.where((e) => e.type == ManageItemType.iptv).length;

    final epgCount = allItems.where((e) => e.type == ManageItemType.epg).length;

    final stats = <({String title, String value, IconData icon})>[
      (title: 'IPTV', value: playlistCount.toString(), icon: Remix.play_list_2_line),
      (title: 'EPG', value: epgCount.toString(), icon: Remix.tv_2_line),
      (title: i18n('network_tag'), value: networkCount.toString(), icon: Remix.global_line),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 240 || MediaQuery.textScalerOf(context).scale(14) > 22;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(colors: [theme.colorScheme.primary.withValues(alpha: 0.12), theme.cardColor]),
          ),
          child: stacked
              ? Column(
                  children: [
                    for (var index = 0; index < stats.length; index++) ...[
                      if (index > 0) const Divider(height: 20),
                      _buildStatRow(theme, stats[index].title, stats[index].value, stats[index].icon),
                    ],
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final stat in stats) Expanded(child: _buildStatItem(theme, stat.title, stat.value, stat.icon)),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildStatRow(ThemeData theme, String title, String value, IconData icon) {
    return Row(
      children: [
        _buildStatIcon(theme, icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: AppTextStyles.t11.copyWith(color: theme.hintColor)),
        ),
        const SizedBox(width: 8),
        Text(value, style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatIcon(ThemeData theme, IconData icon) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: theme.colorScheme.primary),
    );
  }

  Widget _buildStatItem(ThemeData theme, String title, String value, IconData icon) {
    return Column(
      children: [
        _buildStatIcon(theme, icon),
        const SizedBox(height: 10),
        Text(value, style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.t11.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.bold)),
        ),
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
          onTap: _itemActionsBlocked(item) ? null : () => unawaited(_openItemSource(item)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 240 || MediaQuery.textScalerOf(context).scale(14) > 22;
                    final identity = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLeadingIconWithBadge(theme, item, formatText),
                        const SizedBox(width: 14),
                        Expanded(child: _buildItemText(theme, item, stacked: stacked)),
                      ],
                    );
                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          identity,
                          const SizedBox(height: 12),
                          Align(alignment: AlignmentDirectional.centerStart, child: _buildTag(theme, item)),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: 10),
                        _buildTag(theme, item),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final accessibleStack =
                        constraints.maxWidth < 240 || MediaQuery.textScalerOf(context).scale(14) > 22;
                    final compact = constraints.maxWidth <= 680;
                    if (accessibleStack) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (item.isNetwork) ...[
                            _buildActionButton(
                              theme,
                              icon: Remix.download_cloud_2_line,
                              label: i18n('sync'),
                              onTap: _itemActionsBlocked(item) ? null : () => _syncItem(item),
                            ),
                            const SizedBox(height: 10),
                          ],
                          _buildActionButton(
                            theme,
                            icon: Remix.delete_bin_6_line,
                            label: i18n('webdav_delete'),
                            danger: true,
                            onTap: _itemActionsBlocked(item) ? null : () => _showDeleteDialog(item),
                          ),
                          if (item.isNetwork) ...[const SizedBox(height: 10), _buildSwitchButton(theme, item)],
                        ],
                      );
                    }
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
                                    onTap: _itemActionsBlocked(item) ? null : () => _syncItem(item),
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
                                  onTap: _itemActionsBlocked(item) ? null : () => _showDeleteDialog(item),
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
                              onTap: _itemActionsBlocked(item) ? null : () => _syncItem(item),
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
                            onTap: _itemActionsBlocked(item) ? null : () => _showDeleteDialog(item),
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

  Widget _buildItemText(ThemeData theme, ManageItem item, {required bool stacked}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          maxLines: stacked ? 3 : 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.t15.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          item.url,
          maxLines: stacked ? 3 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: theme.hintColor),
        ),
      ],
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
            constraints: const BoxConstraints(maxWidth: 58, minHeight: 18, maxHeight: 24),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.cardColor, width: 2), // 白色/暗色描边切断视觉背景
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatText,
                style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.2),
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
    required VoidCallback? onTap,
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
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),

              const SizedBox(width: 6),

              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
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
    final operationKey = _operationKey(item);
    final busy = _itemActionsBlocked(item);

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Remix.repeat_line, size: 16, color: theme.colorScheme.primary),

          const SizedBox(width: 6),

          Expanded(
            child: Text(
              i18n("auto_sync"),
              style: AppTextStyles.t12.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
            ),
          ),

          Switch(
            value: item.isAutoSync,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            activeThumbColor: theme.colorScheme.primary,

            onChanged: busy
                ? null
                : (value) async {
                    setState(() => _busyItems.add(operationKey));
                    final db = Get.find<DbService>().db;

                    try {
                      if (item.type == ManageItemType.iptv) {
                        await db.updateProviderUpdateStatus(item.id, value);
                      } else {
                        await db.updateEpgSourceUpdateStatus(item.id, value);
                      }

                      if (!mounted) return;
                      final index = allItems.indexWhere(
                        (candidate) => candidate.type == item.type && candidate.id == item.id,
                      );
                      if (index < 0) return;

                      allItems[index] = ManageItem(
                        id: item.id,
                        name: item.name,
                        url: item.url,
                        isNetwork: item.isNetwork,
                        isAutoSync: value,
                        type: item.type,
                        raw: item.type == ManageItemType.iptv
                            ? (item.raw as database.Provider).copyWith(isAutoUpdate: value)
                            : (item.raw as database.EpgSource).copyWith(isAutoUpdate: value),
                      );

                      ToastUtil.show(value ? i18n("auto_sync_tag") : i18n("auto_sync_disabled"));
                    } catch (error) {
                      debugPrint('$error');
                      if (mounted) ToastUtil.show(i18n('manage_page_failed'));
                    } finally {
                      _busyItems.remove(operationKey);
                      if (mounted) setState(() {});
                    }
                  },
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(ManageItem item) {
    if (_itemActionsBlocked(item)) {
      ToastUtil.show(i18n('iptv_import_in_progress'));
      return;
    }
    final theme = Theme.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final operationKey = _operationKey(item);
    setState(() => _busyItems.add(operationKey));
    var deleting = false;
    late final DialogRoute<void> route;

    route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          key: ValueKey('iptv-delete-$operationKey'),
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(i18n("delete_confirm_title")),
          content: Text(i18n("delete_confirm_message")),
          actions: [
            TextButton(onPressed: deleting ? null : () => navigator.removeRoute(route), child: Text(i18n("cancel"))),
            TextButton(
              onPressed: deleting
                  ? null
                  : () async {
                      setDialogState(() => deleting = true);

                      try {
                        if (item.type == ManageItemType.iptv) {
                          final deleted = await IptvImportManager().deleteProviderDurably(
                            item.raw as database.Provider,
                          );
                          if (!deleted) throw StateError('Playlist changed before deletion');
                        } else {
                          final deleted = await EpgImportManager().deleteSourceDurably(item.raw as database.EpgSource);
                          if (!deleted) throw StateError('EPG source changed before deletion');
                        }

                        if (!mounted) return;
                        allItems.removeWhere((candidate) => candidate.type == item.type && candidate.id == item.id);
                        final shouldNotify = route.isCurrent;
                        if (route.isActive) navigator.removeRoute(route);
                        if (shouldNotify) ToastUtil.show(i18n("manage_page_delete_success"));
                      } catch (error) {
                        debugPrint('$error');
                        if (!mounted || !route.isActive) return;
                        setDialogState(() => deleting = false);
                        if (route.isCurrent) ToastUtil.show(i18n('manage_page_failed'));
                      }
                    },
              child: deleting
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(i18n("confirm"), style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        ),
      ),
    );

    unawaited(
      navigator.push(route).whenComplete(() {
        _busyItems.remove(operationKey);
        if (mounted) setState(() {});
      }),
    );
  }
}
