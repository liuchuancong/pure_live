import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/modules/huya/pages/huya_downloads_pane.dart';
import 'package:pure_live/shared/shared.dart' show LiveWindow;

/// 虎牙视频's download queue as its own page — the pane the settings carry,
/// reading as the station's own destination: one row per video, its phase
/// and its progress, the verbs at the row's end. Reached from the rail,
/// where the other stations keep their download managers.
final class HuyaDownloadsPage extends StatelessWidget {
  /// The page.
  const HuyaDownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    return ListView(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s16),
      children: const [HuyaDownloadsPane()],
    );
  }
}
