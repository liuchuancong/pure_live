import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/widgets/play_other.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller_panel.dart';

class NotLivingVideoWidget extends StatelessWidget {
  const NotLivingVideoWidget({super.key, required this.controller});

  final LivePlayController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildHeader(), _buildContent()]),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 55,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.transparent, Colors.black45],
        ),
      ),
      child: Row(
        children: [
          if (GlobalPlayerState.to.fullscreenUI) _buildBackButton(),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                controller.room.title!,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.t14.copyWith(color: Colors.white, decoration: TextDecoration.none),
              ),
            ),
          ),

          if (GlobalPlayerState.to.fullscreenUI) ...[
            IconButton(
              icon: const Icon(Icons.swap_horiz_outlined),
              tooltip: i18n('switch_live_room'),
              color: Colors.white,
              onPressed: () {
                Get.dialog(PlayOther(controller: Get.find<LivePlayController>()));
              },
            ),
            const DatetimeInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: _exitFullscreen,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ),
    );
  }

  void _exitFullscreen() {
    controller.setNormalScreen();

    GlobalPlayerState.to.isFullscreen.value = false;

    GlobalPlayerState.to.isWindowFullscreen.value = false;
  }

  Widget _buildContent() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(i18n('play_video_failed'), style: AppTextStyles.t16.copyWith(color: Colors.white)),
            ),
            Text(i18n('room_offline'), style: const TextStyle(color: Colors.white)),
            Text(i18n('switch_other_room_hint'), style: AppTextStyles.t14.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
