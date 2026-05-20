import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/markdown_block.dart';

class NoNewVersionDialog extends StatelessWidget {
  const NoNewVersionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(i18n("check_update")),
      content: Text(i18n("no_new_version_info")),
      actions: <Widget>[
        TextButton(
          child: Text(i18n("confirm")),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class NewVersionDialog extends StatelessWidget {
  const NewVersionDialog({super.key, this.entry});

  final OverlayEntry? entry;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxWidth = mediaQuery.size.width * 0.9;
    final maxHeight = mediaQuery.size.height * 0.7;
    final config = Get.isDarkMode ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
    return AlertDialog(
      title: Text(i18n("check_update")),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  if (entry != null) {
                    entry!.remove();
                  } else {
                    Navigator.pop(context);
                  }
                  launchUrl(
                    Uri.parse('https://github.com/liuchuancong/pure_live'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: Text(i18n('open_source_free'), style: TextStyle(fontSize: 20)),
              ),
              MarkdownBlock(data: VersionUtil.latestUpdateLog, config: config),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.start,
      actions: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              child: Text(i18n("cancel")),
              onPressed: () {
                if (entry != null) {
                  entry!.remove();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            ElevatedButton(
              child: Text(i18n("update")),
              onPressed: () {
                if (entry != null) {
                  entry!.remove();
                } else {
                  Navigator.pop(context);
                }
                Get.toNamed(RoutePath.kVersionPage);
              },
            ),
          ],
        ),
      ],
    );
  }
}
