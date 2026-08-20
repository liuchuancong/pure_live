import 'audience_info.dart';
import 'line_selector.dart';
import 'resolution_selector.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class ResolutionsRow extends StatelessWidget {
  const ResolutionsRow({super.key});

  LivePlayController get controller => Get.find<LivePlayController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = controller.state.value;

      if (!state.room.success) {
        return Container(height: 55);
      }

      return Container(
        height: 55,
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            const Padding(padding: EdgeInsets.all(8), child: AudienceInfo()),
            const Spacer(),
            const ResolutionSelector(),
            const LineSelector(),
          ],
        ),
      );
    });
  }
}
