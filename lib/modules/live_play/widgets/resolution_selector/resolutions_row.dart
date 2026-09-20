import 'audience_info.dart';
import 'line_selector.dart';
import 'resolution_selector.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class ResolutionsRow extends StatelessWidget {
  const ResolutionsRow({super.key, required this.controller});

  final LivePlayController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = controller.state.value;

      if (!state.room.success) {
        return Container(height: 56);
      }

      final bodyText = TextPainter(
        text: TextSpan(text: 'Ag', style: Theme.of(context).textTheme.bodySmall),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final contentHeight = bodyText.height + 8;
      final rowHeight = contentHeight > 56 ? contentHeight : 56.0;

      return Container(
        height: rowHeight,
        padding: const EdgeInsets.all(4.0),
        child: Row(
          children: [
            if (controller.site != Sites.iptvSite)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AudienceInfo(controller: controller),
                  ),
                ),
              ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: ResolutionSelector(controller: controller),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: LineSelector(controller: controller),
              ),
            ),
          ],
        ),
      );
    });
  }
}
