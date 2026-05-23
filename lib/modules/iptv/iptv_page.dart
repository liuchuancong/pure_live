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
  final settings = Get.find<SettingsService>();

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

    if (epgSources.isNotEmpty && settings.selectedSourceId.value.isEmpty) {
      final activeSource = epgSources.first;
      settings.selectedSourceId.value = activeSource.id;
      settings.selectedSourceName.value = activeSource.name;
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
            Text(i18n("select_epg_source"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            IconButton(icon: const Icon(Icons.close, size: 22), onPressed: () => Navigator.of(context).pop()),
          ],
        ),
        content: SizedBox(
          width: dialogWidth,
          height: 400,
          child: Obx(() {
            if (isDialogLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (sources.isEmpty) {
              return Center(
                child: Text(i18n("no_epg_sources_found"), style: TextStyle(color: Theme.of(context).hintColor)),
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
                  final isSelected = settings.selectedSourceId.value == source.id;

                  return Card(
                    elevation: 0,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        settings.selectedSourceId.value = source.id;
                        final selectedSource = sources.firstWhereOrNull((s) => s.id == source.id);
                        if (selectedSource != null) {
                          settings.selectedSourceName.value = selectedSource.name;
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
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      source.url,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          SectionTitle(title: i18n("iptv_settings")),

          ListTile(
            leading: const Icon(Remix.download_2_line, size: 22),
            title: Text(i18n("import_action")),
            subtitle: const Text("M3U / TXT"),
            onTap: () => showIptvImportDialog(),
          ),

          ListTile(
            leading: const Icon(Remix.cloud_line, size: 22),
            title: Text(i18n("manage_page_title")),
            subtitle: Text(i18n("download_guide_sub")),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Get.to(() => const IptvManagePage()),
          ),

          SectionTitle(title: i18n("epg_settings")),

          ListTile(
            leading: const Icon(Remix.file_add_line, size: 22),
            title: Text(i18n("import_action")),
            subtitle: const Text("XML / GZ / JSON"),
            onTap: () => showEpgImportDialog(),
          ),

          Obx(
            () => ListTile(
              leading: const Icon(Remix.tv_2_line, size: 22),
              title: Text(i18n("active_epg_source"), style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
              subtitle: Text(
                settings.selectedSourceId.value.isEmpty
                    ? i18n("please_select_epg_source")
                    : settings.selectedSourceName.value,
                style: TextStyle(color: settings.selectedSourceId.value.isEmpty ? Colors.orange : theme.hintColor),
              ),
              trailing: Icon(Icons.chevron_right, color: theme.hintColor),
              onTap: () => _showSourceSelectionDialog(),
            ),
          ),
        ],
      ),
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
