import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_shell.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_video.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_header.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class LivePlayContent extends StatelessWidget {
  const LivePlayContent({super.key, required this.controller, required this.isInPip, required this.mode});

  final LivePlayController controller;
  final bool isInPip;
  final VideoMode mode;

  @override
  Widget build(BuildContext context) {
    final manager = GlobalPlayerService.instance.player;

    if (isInPip) {
      return Theme(
        data: ThemeData.dark(),
        child: Container(key: const ValueKey('pip'), color: Colors.transparent, child: manager.buildPiPOverlay()),
      );
    }

    if (mode == VideoMode.normal) {
      return Container(key: const ValueKey('normal'), color: Colors.black, child: _buildNormalView(context));
    }

    return Container(
      color: Colors.black,
      child: LivePlayVideo(controller: controller),
    );
  }

  Widget _buildNormalView(BuildContext context) {
    final compactHeader = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: LivePlayHeader(controller: controller, compactHeader: compactHeader),
      body: LivePlayShell(controller: controller),
    );
  }
}
