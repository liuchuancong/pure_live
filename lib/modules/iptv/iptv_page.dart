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
    final double dialogWidth = screenSize.width > 600 ? 460.0 : screenSize.width * 0.88;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(i18n("select_epg_source")),
        content: SizedBox(
          width: dialogWidth,
          height: 400,
          child: Obx(() {
            if (isDialogLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (sources.isEmpty) {
              return Center(child: Text(i18n("no_epg_sources_found")));
            }
            return RadioGroup<String>(
              groupValue: settings.selectedSourceId.value,
              onChanged: (String? value) {
                if (value != null) {
                  settings.selectedSourceId.value = value;
                  final selectedSource = sources.firstWhereOrNull((s) => s.id == value);
                  if (selectedSource != null) {
                    settings.selectedSourceName.value = selectedSource.name;
                  }
                  Navigator.of(context).pop();
                  ToastUtil.show(i18n("epg_source_updated"));
                }
              },
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                shrinkWrap: true,
                itemCount: sources.length,
                itemBuilder: (context, index) {
                  final source = sources[index];
                  final displayName = source.name;
                  return RadioListTile<String>(title: Text(displayName), value: source.id);
                },
              ),
            );
          }),
        ),
      ),
      barrierDismissible: true,
    );

    try {
      final db = Get.find<DbService>().db;
      sources = await db.getAllEpgSources();
    } catch (e) {
      debugPrint("$e");
    } finally {
      isDialogLoading.value = false;
    }
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
            onTap: () => showPlaylistImportDialog(),
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

  void showPlaylistImportDialog() {
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Icon(Remix.draft_line, color: theme.colorScheme.primary),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                // 1. 调用重构后的 EpgSyncEngine 静态方法（无需任何实例化）
                isSuccess = await EpgImportManager().importFromNetworkUrl(urlText, fileNameText);
              } else {
                // 2. 抛弃原本的 FileRecoverUtils，直接调用规范化解耦后的 IptvImportManager 网络下载方法
                isSuccess = await IptvImportManager().importFromNetworkUrl(urlText, fileNameText);
              }

              if (isSuccess) {
                Navigator.of(Get.context!).pop();
                await _refreshData(); // 如果你在当前类有实现这个数据刷新方法，它将被正常调用
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
