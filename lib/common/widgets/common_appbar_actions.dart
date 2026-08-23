import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/routes/app_navigation.dart';

class CommonAppBarActions extends StatelessWidget {
  const CommonAppBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<int>(
          tooltip: i18n("more"),
          icon: const Icon(Remix.menu_search_line, size: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          offset: const Offset(0, 10),
          position: PopupMenuPosition.under,
          onSelected: (index) {
            switch (index) {
              case 0:
                Get.toNamed(RoutePath.kSearch);
                break;
              case 1:
                Get.toNamed(RoutePath.kToolbox);
                break;
              case 2:
                AppNavigator.toMultiview();
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
                  Text(i18n("search_live"), style: AppTextStyles.t14),
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
                  Text(i18n("open_link"), style: AppTextStyles.t14),
                ],
              ),
            ),

            PopupMenuItem(
              value: 2,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Remix.layout_grid_line, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(i18n("multiview_title"), style: AppTextStyles.t14),
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
