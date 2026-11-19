import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/hongguo.dart';
import 'package:pure_live/modules/huya/huya.dart';
import 'package:pure_live/modules/music/music.dart';
import 'package:pure_live/modules/vod/vod.dart';
import 'package:pure_live/shared/shared.dart';

/// The app's one download surface: the four modules' queues under one roof.
///
/// The queues stay their own machines — each module's download page keeps
/// its lanes, its filters and its files, and this centre does not re-render
/// a single task. It answers the one question the four pages cannot: where
/// does everything I send to download actually live. The module segments
/// choose the queue; the module's own body fills the rest unchanged, so the
/// verbs a module built stay the ones it answers.
final class DownloadsCenterPage extends StatefulWidget {
  /// The download centre page.
  const DownloadsCenterPage({super.key});

  @override
  State<DownloadsCenterPage> createState() => _DownloadsCenterPageState();
}

class _DownloadsCenterPageState extends State<DownloadsCenterPage> {
  /// The four modules that download, in the segments' order.
  static const List<AppModule> _segments = [AppModule.vod, AppModule.music, AppModule.hongguo, AppModule.huya];

  /// The queue on show.
  AppModule _module = AppModule.vod;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The head names the roof once, and the module segments are its one
        // verb — the same row, the way the recorder centre's task/file
        // switch rides its toolbar.
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s4),
          child: ModulePageHead(
            title: t.navigation.downloadsCenter,
            actions: [
              DsSegmentedControl<AppModule>(
                value: _module,
                onChanged: (value) => setState(() => _module = value),
                segments: [
                  for (final module in _segments) DsSegment(value: module, label: Text(module.label(t))),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(index: _segments.indexOf(_module), children: [for (final module in _segments) _bodyOf(module)]),
        ),
      ],
    );
  }

  /// The module's own download page, kept intact under the roof.
  Widget _bodyOf(AppModule module) => switch (module) {
    AppModule.vod => const VodDownloadsPage(),
    AppModule.music => const MusicDownloadsView(),
    AppModule.hongguo => const HongguoDownloadsPage(),
    AppModule.huya => const HuyaDownloadsPage(),
    _ => const SizedBox.shrink(),
  };
}
