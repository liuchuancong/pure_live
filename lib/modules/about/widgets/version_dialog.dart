import 'package:pure_live/common/index.dart';
import 'package:url_launcher/url_launcher.dart';

class NoNewVersionDialog extends StatelessWidget {
  const NoNewVersionDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.current.check_update),
      content: Text(S.current.no_new_version_info),
      actions: <Widget>[
        TextButton(
          child: Text(S.current.confirm),
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
    return AlertDialog(
      title: Text(S.current.check_update),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(S.current.new_version_info(VersionUtil.latestVersion)),
          const SizedBox(height: 20),
          Text(
            VersionUtil.latestUpdateLog,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              if (entry != null) {
                entry!.remove();
              } else {
                Navigator.pop(context);
              }
              launchUrl(
                Uri.parse('https://www.123pan.com/s/Jucxjv-NwYYd.html'),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('本软件开源免费,国内下载：123云盘'),
          )
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: Text(S.current.cancel),
          onPressed: () {
            if (entry != null) {
              entry!.remove();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        ElevatedButton(
          child: Text(S.current.update),
          onPressed: () {
            if (entry != null) {
              entry!.remove();
            } else {
              Navigator.pop(context);
            }
            launchUrl(
              Uri.parse('https://github.com/liuchuancong/pure_live/releases'),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
      ],
    );
  }
}
