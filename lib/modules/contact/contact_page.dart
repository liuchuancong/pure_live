import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  void clipboard(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((value) => SnackBarUtil.success('已复制到剪贴板'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          SectionTitle(title: S.current.contact),
          ListTile(
            leading: const Icon(CustomIcons.mail_squared, size: 34),
            title: Text(S.current.email),
            subtitle: const Text(VersionUtil.email),
            onLongPress: () => clipboard(VersionUtil.email),
            onTap: () {
              launchUrl(
                Uri.parse(VersionUtil.emailUrl),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          ListTile(
            leading: const Icon(CustomIcons.github_circled, size: 32),
            title: Text(S.current.github),
            subtitle: const Text(VersionUtil.githubUrl),
            onTap: () {
              launchUrl(
                Uri.parse(VersionUtil.githubUrl),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ],
      ),
    );
  }
}
