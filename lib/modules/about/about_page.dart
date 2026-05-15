import 'package:get/get.dart';
import 'widgets/version_dialog.dart';
import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/markdown_block.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final SettingsService settings = Get.find<SettingsService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: <Widget>[
          SectionTitle(title: i18n("about")),
          ListTile(
            title: Text(i18n("online_update")),
            trailing: Text('${i18n("current_version")} v${VersionUtil.version}', style: Get.textTheme.bodyMedium),
            onTap: () {
              Get.toNamed(RoutePath.kVersionPage);
            },
          ),
          ListTile(
            title: Text(i18n("history")),
            subtitle: Text(i18n("history_desc")),
            onTap: () => Get.toNamed(RoutePath.kVersionHistory),
          ),
          ListTile(title: Text(i18n("license")), onTap: showLicenseDialog),
          SectionTitle(title: i18n("project")),
          ListTile(
            title: Text(i18n("project_page")),
            subtitle: const Text(VersionUtil.projectUrl),
            onTap: () {
              launchUrl(Uri.parse(VersionUtil.projectUrl), mode: LaunchMode.externalApplication);
            },
          ),
          ListTile(
            title: Text(i18n("project_alert")),
            subtitle: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(i18n("app_legalese"))),
          ),
        ],
      ),
    );
  }

  void showCheckUpdateDialog(BuildContext context) async {
    showDialog(
      context: Get.context!,
      builder: (context) => VersionUtil.hasNewVersion() ? NewVersionDialog() : NoNewVersionDialog(),
    );
  }

  void showLicenseDialog() {
    showLicensePage(
      context: context,
      applicationName: i18n("app_name"),
      applicationVersion: VersionUtil.version,
      applicationIcon: SizedBox(width: 60, child: Center(child: Image.asset('assets/icons/icon.png'))),
    );
  }

  void showNewFeaturesDialog() {
    final config = Get.isDarkMode ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
    final mediaQuery = MediaQuery.of(context);
    final maxWidth = mediaQuery.size.width * 0.9;
    final maxHeight = mediaQuery.size.height * 0.7;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(i18n("what_is_new")),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      launchUrl(
                        Uri.parse('https://github.com/liuchuancong/pure_live'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: Text(i18n("open_source_free"), style: const TextStyle(fontSize: 20)),
                  ),
                  MarkdownBlock(data: VersionUtil.latestUpdateLog, config: config),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.start,
        );
      },
    );
  }
}
