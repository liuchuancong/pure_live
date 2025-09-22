import 'package:extended_image/extended_image.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher.dart';

import 'widgets/version_dialog.dart';

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
          SectionTitle(title: S.current.about),
          ListTile(
            title: Text(S.current.what_is_new),
            onTap: showNewFeaturesDialog,
          ),
          ListTile(
            title: Text(S.current.check_update),
            onTap: () => showCheckUpdateDialog(context),
          ),
          ListTile(
            title: Text(S.current.version),
            subtitle: const Text(VersionUtil.version),
          ),
          ListTile(
            title: Text(S.current.version_history),
            subtitle: Text(S.current.version_history_info),
            onTap: () => Get.toNamed(RoutePath.kVersionHistory),
          ),
          ListTile(
            title: Text(S.current.license),
            onTap: showLicenseDialog,
          ),
          SectionTitle(title: S.current.project),
          ListTile(
            title: Text(S.current.help_and_support),
            onTap: () => Get.toNamed(RoutePath.kDonate),
          ),
          ListTile(
            title: Text(S.current.project_page),
            subtitle: const Text(VersionUtil.projectUrl),
            onTap: () {
              launchUrl(
                Uri.parse(VersionUtil.projectUrl),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          ListTile(
            title: Text(S.current.project_alert),
            subtitle: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(S.current.app_legalese),
            ),
          ),
        ],
      ),
    );
  }

  void showCheckUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => VersionUtil.hasNewVersion() ? const NewVersionDialog() : const NoNewVersionDialog(),
    );
  }

  void showLicenseDialog() {
    showLicensePage(
      context: context,
      applicationName: S.current.app_name,
      applicationVersion: VersionUtil.version,
      applicationIcon: SizedBox(
        width: 60,
        child: Center(child: ExtendedImage.asset('assets/icons/icon.png')),
      ),
    );
  }

  void showNewFeaturesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.current.what_is_new),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Version ${VersionUtil.latestVersion}'),
            const SizedBox(height: 20),
            Text(
              VersionUtil.latestUpdateLog,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
