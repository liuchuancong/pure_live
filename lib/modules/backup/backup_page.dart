import 'dart:io';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/backup/scan_page.dart';
import 'package:pure_live/plugins/file_recover_utils.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final settings = Get.find<SettingsService>();
  late String backupDirectory = settings.backupDirectory.value;
  late String m3uDirectory = settings.m3uDirectory.value;

  SizedBox spacer(double height) {
    return SizedBox(height: height);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          SectionTitle(title: i18n("backup_recover")),

          ListTile(
            title: Text(i18n("webdav")),
            subtitle: Text(i18n("backup_to_webdav")),
            onTap: () async {
              Get.toNamed(RoutePath.kWebDavPage);
            },
          ),

          ListTile(
            title: Text(i18n("network")),
            subtitle: Text(i18n("import_m3u")),
            onTap: () => showImportSetDialog(),
          ),

          if (Platform.isAndroid || Platform.isIOS)
            ListTile(
              title: Text(i18n("sync_tv_data")),
              subtitle: Text(i18n("sync_tv_data_subtitle")),
              onTap: () async {
                Get.to(() => const ScanCodePage());
              },
            ),

          ListTile(
            title: Text(i18n("create_backup")),
            subtitle: Text(i18n("create_backup_subtitle")),
            onTap: () async {
              final selectedDirectory = await FileRecoverUtils().createBackup(backupDirectory);

              if (selectedDirectory != null) {
                setState(() {
                  backupDirectory = selectedDirectory;
                });
              }
            },
          ),

          ListTile(
            title: Text(i18n("recover_backup")),
            subtitle: Text(i18n("recover_backup_subtitle")),
            onTap: () => FileRecoverUtils().recoverBackup(),
          ),

          SectionTitle(title: i18n("auto_backup")),

          ListTile(
            title: Text(i18n("backup_directory")),
            subtitle: Text(backupDirectory),
            onTap: () async {
              final selectedDirectory = await FileRecoverUtils().selectBackupDirectory(backupDirectory);

              if (selectedDirectory != null) {
                setState(() {
                  backupDirectory = selectedDirectory;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  void showImportSetDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(i18n("import_m3u_title")),
          children: [
            RadioGroup<String>(
              groupValue: '',
              onChanged: (String? value) {
                importFile(value!);
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 0, bottom: 10, left: 16, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [i18n("local_import"), i18n("network_import")].map<Widget>((name) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(value: name, activeColor: Theme.of(context).colorScheme.primary),
                        GestureDetector(
                          onTap: () {
                            importFile(name);
                            Navigator.of(context).pop();
                          },
                          child: Text(name, style: Theme.of(context).textTheme.bodyLarge),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String?> showEditTextDialog() async {
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
          TextButton(
            onPressed: () {
              Navigator.of(Get.context!).pop();
            },
            child: Text(i18n("cancel")),
          ),
          TextButton(
            onPressed: () async {
              if (urlEditingController.text.isEmpty) {
                ToastUtil.show(i18n("enter_download_link"));
                return;
              }

              bool validate = FileRecoverUtils.isUrl(urlEditingController.text);

              if (!validate) {
                ToastUtil.show(i18n("invalid_download_link"));
                return;
              }

              if (textEditingController.text.isEmpty) {
                ToastUtil.show(i18n("enter_file_name"));
                return;
              }

              await FileRecoverUtils().recoverNetworkM3u8Backup(urlEditingController.text, textEditingController.text);

              Navigator.of(Get.context!).pop();
            },
            child: Text(i18n("confirm")),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    return result;
  }

  void importFile(String value) {
    if (value == i18n("local_import")) {
      FileRecoverUtils().recoverM3u8Backup();
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop(false);
      showEditTextDialog();
    }
  }
}
