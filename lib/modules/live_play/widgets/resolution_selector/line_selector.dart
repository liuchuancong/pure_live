import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class LineSelector extends StatelessWidget {
  const LineSelector({super.key});

  LivePlayController get controller => Get.find<LivePlayController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = controller.state.value;

      if (!state.room.success || !state.player.hasPlaybackSource) {
        return const SizedBox.shrink();
      }

      final currentIndex = state.player.currentLineIndex.clamp(0, state.player.lineCount - 1);
      final switching = controller.playerController.isStreamSwitching.value;

      final currentLineName = i18n("toolbox_line", args: {"index": (currentIndex + 1).toString()});

      return PopupMenuButton<int>(
        key: const ValueKey('room-line-selector'),
        enabled: !switching,
        tooltip: i18n("select_play_line"),
        color: Get.theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        offset: const Offset(0.0, 5.0),
        onOpened: () {
          controller.updateUI(isMenuOpen: true);
        },
        onCanceled: () {
          controller.updateUI(isMenuOpen: false);
        },
        position: PopupMenuPosition.under,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kMinInteractiveDimension,
            minHeight: kMinInteractiveDimension,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (switching) ...[
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.8, color: Get.theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    currentLineName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Get.theme.textTheme.labelSmall?.copyWith(color: Get.theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
        onSelected: (newLineIndex) async {
          controller.updateUI(isMenuOpen: false);
          await controller.setResolution(ReloadDataType.changeLine, state.player.currentQuality, newLineIndex);
        },
        itemBuilder: (context) {
          return List.generate(state.player.lineCount, (index) {
            final isSelected = index == currentIndex;

            return PopupMenuItem<int>(
              value: index,
              child: Text(
                i18n("toolbox_line", args: {"index": (index + 1).toString()}),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: isSelected ? Get.theme.colorScheme.primary : null),
              ),
            );
          });
        },
      );
    });
  }
}
