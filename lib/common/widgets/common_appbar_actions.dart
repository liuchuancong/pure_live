import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/search/search_controller.dart' as pure_live;

class CommonAppBarActions extends StatelessWidget {
  const CommonAppBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: "录制中心",
          onPressed: () {
            Get.toNamed(RoutePath.kRecordPage);
          },
          icon: const Icon(Remix.download_2_fill, size: 22),
        ),

        PopupMenuButton<int>(
          tooltip: "更多",
          icon: const Icon(Remix.more_2_fill, size: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          offset: const Offset(0, 10),
          position: PopupMenuPosition.under,

          onSelected: (index) {
            switch (index) {
              case 0:
                Get.put(pure_live.SearchController());
                Get.toNamed(RoutePath.kSearch);
                break;

              case 1:
                Get.toNamed(RoutePath.kToolbox);
                break;
            }
          },

          itemBuilder: (context) => [
            PopupMenuItem(
              value: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Remix.search_line, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  const Text("搜索直播", style: TextStyle(fontSize: 14)),
                ],
              ),
            ),

            PopupMenuItem(
              value: 1,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Remix.link, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  const Text("链接访问", style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(width: 4),
      ],
    );
  }
}
