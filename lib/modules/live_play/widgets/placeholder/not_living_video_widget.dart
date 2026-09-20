import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/dialogs/play_other.dart';
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
      child: Column(children: [_buildHeader(context), _buildContent()]),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final titleStyle = AppTextStyles.t14.copyWith(color: Colors.white, decoration: TextDecoration.none);
    final titlePainter = TextPainter(
      text: TextSpan(text: 'Ag', style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final scaledContentHeight = titlePainter.height + 8;
    final headerHeight = scaledContentHeight > 55 ? scaledContentHeight : 55.0;

    return Container(
      key: const ValueKey('offline-room-header'),
      height: headerHeight,
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                key: const ValueKey('offline-room-title'),
                _offlineRoomTitle(controller.room),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: titleStyle,
              ),
            ),
          ),

          if (GlobalPlayerState.to.fullscreenUI) ...[
            IconButton(
              icon: const Icon(Icons.swap_horiz_outlined),
              tooltip: i18n('switch_live_room'),
              visualDensity: VisualDensity.standard,
              constraints: const BoxConstraints(
                minWidth: kMinInteractiveDimension,
                minHeight: kMinInteractiveDimension,
              ),
              color: Colors.white,
              onPressed: () {
                unawaited(
                  showDialog<void>(
                    context: context,
                    builder: (_) => PlayOther(controller: controller),
                  ),
                );
              },
            ),
            const DatetimeInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      key: const ValueKey('offline-room-exit-fullscreen'),
      tooltip: i18n('exit_fullscreen'),
      visualDensity: VisualDensity.standard,
      constraints: const BoxConstraints(minWidth: kMinInteractiveDimension, minHeight: kMinInteractiveDimension),
      onPressed: _exitFullscreen,
      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
    );
  }

  void _exitFullscreen() {
    controller.setNormalScreen();

    GlobalPlayerState.to.isFullscreen.value = false;

    GlobalPlayerState.to.isWindowFullscreen.value = false;
  }

  Widget _buildContent() {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          key: const ValueKey('offline-room-content-scroll'),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (constraints.maxHeight - 16).clamp(0, double.infinity).toDouble()),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(i18n('play_video_failed'), style: AppTextStyles.t16.copyWith(color: Colors.white)),
                  ),
                  Text(
                    i18n('room_offline'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    i18n('switch_other_room_hint'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.t14.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _offlineRoomTitle(LiveRoom room) {
  for (final candidate in [room.title, room.nick, room.roomId]) {
    final value = candidate?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return i18n('untitled_room');
}
