import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class ResolutionSelector extends StatelessWidget {
  const ResolutionSelector({super.key});

  LivePlayController get controller => Get.find<LivePlayController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = controller.state.value;

      if (!state.room.success || state.player.qualites.isEmpty) {
        return const SizedBox.shrink();
      }

      final currentIndex = state.player.currentQuality;
      final currentQualityName = state.player.qualites[currentIndex].quality;

      return PopupMenuButton<int>(
        tooltip: i18n('toolbox_select_quality'),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            currentQualityName,
            style: Get.theme.textTheme.labelSmall?.copyWith(color: Get.theme.colorScheme.primary),
          ),
        ),
        onSelected: (newQualityIndex) {
          controller.updateUI(isMenuOpen: false);

          controller.setResolution(ReloadDataType.changeQuality, newQualityIndex, state.player.currentLineIndex);
        },
        itemBuilder: (context) {
          return List.generate(state.player.qualites.length, (index) {
            final qualityRate = state.player.qualites[index];

            final isSelected = index == currentIndex;

            return PopupMenuItem<int>(
              value: index,
              child: Text(
                qualityRate.quality,
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
