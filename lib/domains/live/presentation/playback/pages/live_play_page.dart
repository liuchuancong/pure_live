import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/platform/platform_utils.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';
import 'package:pure_live/core/player/presentation/player_back_scope.dart';
import 'package:pure_live/domains/live/presentation/playback/states/ui_state.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/keyboard/video_keyboard.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/layout/live_play_content.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/live_play_controller.dart';

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
      final player = GlobalPlayerService.instance.player;
      final presentationActive =
          !isInPip && (mode != VideoMode.normal || player.isSystemFullscreen.value || player.isWindowFullscreen.value);

      final child = LivePlayContent(controller: controller, isInPip: isInPip, mode: mode);

      final content = _withLocalGiftEffect(child);

      // The room is black by design - but a wallpaper is meant to run through
      // the whole app, so the windowed canvas steps aside while one is showing.
      // Presentation modes (fullscreen, PiP, portrait placement) keep their own
      // opaque backdrop: there the video is the only subject on screen.
      final bool wallpaperOwnsCanvas = AppCanvasScope.ownedByBackgroundOf(context);
      final Color canvasColor = wallpaperOwnsCanvas && !isInPip && !presentationActive
          ? Colors.transparent
          : Colors.black;

      // Keep desktop route shortcuts mounted even when metadata loading ends
      // in an offline/error placeholder before a VideoController exists.
      // Otherwise the visible back button works while Escape silently does
      // nothing on exactly those failure states.
      final page = VideoKeyboardShortcuts(
        controller: videoController,
        child: Container(color: canvasColor, width: double.infinity, height: double.infinity, child: content),
      );

      return PlayerBackScope(
        presentationActive: presentationActive,
        onExitPresentation: controller.exitPresentationForSystemBack,
        onBackRequest: _enterSystemPipOnBack,
        child: page,
      );
    });
  }

  Future<bool> _enterSystemPipOnBack() async {
    if (!PlatformUtils.isAndroid) return false;
    final manager = GlobalPlayerService.instance.player;
    if (!SettingsService.to.player.floatPlay.v) return false;
    if (manager.isInPip.value || manager.isPipPreparing.value) return false;
    if (!manager.isPlayingNow) return false;
    try {
      await controller.enterPipPresentation();
      // enablePip completing without throwing means the presentation driver
      // applied the pip request; isInPip itself flips on the driver's change
      // stream one microtask later.
      return true;
    } catch (_) {
      return false;
    }
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
                padding: EdgeInsets.symmetric(horizontal: fullEffect ? 28 : 20, vertical: fullEffect ? 24 : 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color.withValues(alpha: .94), Colors.black.withValues(alpha: .78)]),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: .45)),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: .55), blurRadius: fullEffect ? 42 : 24)],
                ),
                child: Text(
                  message.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: fullEffect ? 20 : 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
