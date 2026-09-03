import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/keyboard/video_keyboard.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_content.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_back_scope.dart';

class LivePlayPage extends GetView<LivePlayController> {
  const LivePlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final manager = GlobalPlayerService.instance.player;
      final isInPip = manager.isInPip.value || manager.isPipPreparing.value;

      final state = controller.state.value;
      final mode = state.ui.screenMode;
      final videoController = state.player.videoController;
      final globalState = GlobalPlayerState.to;
      final presentationActive =
          !isInPip &&
          (mode != VideoMode.normal ||
              globalState.isFullscreen.value ||
              globalState.isWindowFullscreen.value);

      final child = LivePlayContent(controller: controller, isInPip: isInPip, mode: mode);

      final content = _withLocalGiftEffect(child);

      // Keep desktop route shortcuts mounted even when metadata loading ends
      // in an offline/error placeholder before a VideoController exists.
      // Otherwise the visible back button works while Escape silently does
      // nothing on exactly those failure states.
      final page = VideoKeyboardShortcuts(
        controller: videoController,
        child: Container(
          color: Colors.black,
          width: double.infinity,
          height: double.infinity,
          child: content,
        ),
      );

      return LivePlayBackScope(
        presentationActive: presentationActive,
        onExitPresentation: controller.exitPresentationForSystemBack,
        child: page,
      );
    });
  }

  Widget _withLocalGiftEffect(Widget child) {
    final message = controller.localGiftEffect.value;

    if (message == null) {
      return child;
    }

    final color = Color.fromARGB(255, message.color.r, message.color.g, message.color.b);

    final fullEffect = message.data is Map && message.data['effect'] == 'full';

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(message),
              tween: Tween(begin: .72, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (context, scale, effectChild) {
                return Transform.scale(scale: scale, child: effectChild);
              },
              child: Container(
                constraints: BoxConstraints(maxWidth: fullEffect ? 440 : 320),
                padding: EdgeInsets.symmetric(
                  horizontal: fullEffect ? 28 : 20,
                  vertical: fullEffect ? 24 : 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: .94), Colors.black.withValues(alpha: .78)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: .45)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .55),
                      blurRadius: fullEffect ? 42 : 24,
                    ),
                  ],
                ),
                child: Text(
                  message.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fullEffect ? 20 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
