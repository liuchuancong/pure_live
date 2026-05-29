import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/modules/iptv/iptv_manage.dart';
import 'package:pure_live/modules/auth/utils/constants.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/core/iptv/services/epg_import_manager.dart';
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';

class IptvPage extends StatefulWidget {
  const IptvPage({super.key});

  @override
  State<IptvPage> createState() => _IptvPageState();
}

class _IptvPageState extends State<IptvPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final RxList<database.Provider> playlists = <database.Provider>[].obs;
  final RxList<database.EpgSource> epgSources = <database.EpgSource>[].obs;

  final RxBool isGlobalSyncing = false.obs;
  final RxBool isSyncingEpg = false.obs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final db = Get.find<DbService>().db;
    epgSources.value = await db.getAllEpgSources();
    playlists.value = await db.getAllProviders();

    if (epgSources.isNotEmpty && SettingsService.to.iptv.selectedSourceId.v.isEmpty) {
      final activeSource = epgSources.first;
      SettingsService.to.iptv.selectedSourceId.v = activeSource.id;
      SettingsService.to.iptv.selectedSourceName.v = activeSource.name;
    }
  }

  void _showSourceSelectionDialog() async {
    final RxBool isDialogLoading = true.obs;
    List<database.EpgSource> sources = [];
    final screenSize = MediaQuery.of(context).size;
    final double dialogWidth = screenSize.width > 600 ? 520.0 : screenSize.width * 0.90;

    try {
      final db = Get.find<DbService>().db;
      sources = await db.getAllEpgSources();
    } catch (e) {
      debugPrint("Dialog source fetch failure: $e");
    } finally {
      isDialogLoading.value = false;
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.only(left: 24, top: 16, right: 12, bottom: 8),
        contentPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 12),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(i18n("select_epg_source"), style: AppTextStyles.t11.copyWith(fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.close, size: 22), onPressed: () => Navigator.of(context).pop()),
          ],
        ),
        content: SizedBox(
          width: dialogWidth,
          height: 400,
          child: Obx(() {
            if (isDialogLoading.value) {
              return AppStatusView(type: AppStatusType.loading, title: "", subtitle: "");
            }
            if (sources.isEmpty) {
              return Center(
                child: Text(
                  i18n("no_epg_sources_found"),
                  style: AppTextStyles.t14.copyWith(color: Theme.of(context).hintColor),
                ),
              );
            }

            return ListView.separated(
              physics: const BouncingScrollPhysics(),
              shrinkWrap: true,
              itemCount: sources.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final source = sources[index];

                return Obx(() {
                  final isSelected = SettingsService.to.iptv.selectedSourceId.v == source.id;

                  return Card(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        SettingsService.to.iptv.selectedSourceId.v = source.id;
                        final selectedSource = sources.firstWhereOrNull((s) => s.id == source.id);
                        if (selectedSource != null) {
                          SettingsService.to.iptv.selectedSourceName.v = selectedSource.name;
                        }
                        Navigator.of(context).pop();
                        ToastUtil.show(i18n("epg_source_switched"));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).unselectedWidgetColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    source.name,
                                    style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      source.url,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Theme.of(context).hintColor),
                                    ),
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
          }),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(i18n("cancel")))],
      ),
      barrierDismissible: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(i18n("iptv_settings"))),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          context.buildGroupTitle(i18n("manage_page_title")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.cloud_line,
              title: i18n("manage_page_title"),
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
              value: SettingsService.to.iptv.isAutoSyncEnabled.v,
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
            context.buildTile(
              icon: Remix.tv_line,
              title: i18n("custom_ua_title"),
              subtitle: SettingsService.to.iptv.customIptvUserAgent.v.length > 30
                  ? "${SettingsService.to.iptv.customIptvUserAgent.v.substring(0, 30)}..."
                  : SettingsService.to.iptv.customIptvUserAgent.v,
              onTap: () => _showEditUserAgentDialog(context),
            ),
          ]),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n("iptv_settings")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.download_2_line,
              title: i18n("import_action"),
              subtitle: "M3U / TXT",
              onTap: () => showIptvImportDialog(),
            ),
          ]),
          const SizedBox(height: 20),
          context.buildGroupTitle(i18n("epg_settings")),
          context.buildModernCard([
            context.buildTile(
              icon: Remix.file_add_line,
              title: i18n("import_action"),
              subtitle: "XML / GZ / JSON",
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

  void _showEditUserAgentDialog(BuildContext context) {
    final controller = TextEditingController(text: SettingsService.to.iptv.customIptvUserAgent.v);
    final RxDouble customInputHeight = 100.0.obs;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);

        return LayoutBuilder(
          builder: (context, constraints) {
            final dialogWidth = constraints.maxWidth > 640 ? 560.0 : constraints.maxWidth * 0.9;

            return AlertDialog(
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
                    Obx(
                      () => Container(
                        height: customInputHeight.value,
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
                                    icon: const Icon(Remix.close_circle_line, size: 18),
                                    onPressed: () => controller.clear(),
                                  ),
                                ),
                                style: AppTextStyles.t13.copyWith(fontFamily: 'monospace'),
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onVerticalDragUpdate: (details) {
                                final newHeight = customInputHeight.value + details.delta.dy;
                                if (newHeight >= 80 && newHeight <= 350) {
                                  customInputHeight.value = newHeight;
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: theme.dividerColor.withValues(alpha: 0.03),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(14),
                                    bottomRight: Radius.circular(14),
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 36,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: theme.hintColor.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                    SettingsService.to.iptv.customIptvUserAgent.v = trimmedValue;
                    Navigator.of(context).pop();
                    ToastUtil.show(i18n("settings_saved"));
                  },
                  child: Text(i18n("confirm")),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showIntervalSelectionMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final List<int> hoursOptions = [2, 6, 12, 24, 48, 72];

        return AlertDialog(
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
                  // 💡 判定当前小时数是否处于被激活状态
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

  Future<String?> showEditTextDialog({required bool isEpg}) async {
    final TextEditingController urlEditingController = TextEditingController();
    final TextEditingController textEditingController = TextEditingController();

    var result = await Get.dialog(
      AlertDialog(
        title: Text(i18n("enter_download_url")),
        content: SizedBox(
          width: 400.0,
          height: 300.0,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                TextField(
                  controller: urlEditingController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(12),
                    hintText: i18n("download_url"),
                  ),
                  autofocus: true,
                ),
                spacer(12.0),
                TextField(
                  controller: textEditingController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(12),
                    hintText: i18n("file_name"),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(Get.context!).pop(), child: Text(i18n("cancel"))),
          TextButton(
            onPressed: () async {
              final urlText = urlEditingController.text.trim();
              final fileNameText = textEditingController.text.trim();

              if (urlText.isEmpty) {
                ToastUtil.show(i18n("enter_download_link"));
                return;
              }
              if (!FileUtils.isValidUrl(urlText)) {
                ToastUtil.show(i18n("invalid_download_link"));
                return;
              }
              if (fileNameText.isEmpty) {
                ToastUtil.show(i18n("enter_file_name"));
                return;
              }

              bool isSuccess = false;

              if (isEpg) {
                isSuccess = await EpgImportManager().importFromNetworkUrl(urlText, fileNameText);
              } else {
                isSuccess = await IptvImportManager().importFromNetworkUrl(urlText, fileNameText);
              }

              if (isSuccess) {
                Navigator.of(Get.context!).pop();
                await _refreshData();
              }
            },
            child: Text(i18n("confirm")),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    return result;
  }
}
