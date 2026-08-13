import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/search/search_controller.dart' as pure_live;

class SearchPage extends GetView<pure_live.SearchController> {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: TextField(
          controller: controller.searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: i18n("search_input_hint"),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
            prefixIcon: IconButton(
              onPressed: () {
                if (Navigator.canPop(Get.context!)) {
                  Navigator.of(Get.context!).pop();
                }
              },
              icon: const Icon(Icons.arrow_back),
            ),
            suffixIcon: IconButton(onPressed: controller.doSearch, icon: const Icon(Icons.search)),
          ),
          onSubmitted: (e) {
            controller.doSearch();
          },
        ),
        bottom: TabBar(
          controller: controller.tabController,
          padding: EdgeInsets.zero,
          tabs: [
            Tab(text: i18n('site_all')),
            ...Sites().availableSites().map((e) => Tab(text: e.name)),
          ],
          isScrollable: true,
        ),
      ),
      body: Obx(() {
        if (controller.loading.v) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!controller.searched.v) {
          return AppStatusView(
            type: AppStatusType.empty,
            icon: Icons.travel_explore_rounded,
            title: i18n('native_search_title'),
            subtitle: i18n('native_search_desc'),
          );
        }
        if (controller.results.isEmpty) {
          return AppStatusView(
            type: AppStatusType.empty,
            icon: Icons.search_off_rounded,
            title: i18n('search_no_results'),
            subtitle: controller.errorMessage.v,
            buttonText: controller.index.v == 0 ? null : i18n('continue_web_search'),
            onButtonPressed: controller.index.v == 0 ? null : controller.openWebSearch,
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
            const spacing = 8.0;
            final itemWidth = (width - 16 - spacing * (columns - 1)) / columns;
            return Column(
              children: [
                if (controller.errorMessage.v.isNotEmpty)
                  MaterialBanner(
                    content: Text(controller.errorMessage.v),
                    actions: [
                      if (controller.index.v != 0)
                        TextButton(onPressed: controller.openWebSearch, child: Text(i18n('continue_web_search'))),
                      TextButton(
                        onPressed: () => controller.errorMessage.v = '',
                        child: Text(MaterialLocalizations.of(context).closeButtonLabel),
                      ),
                    ],
                  ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    cacheExtent: 480,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      mainAxisExtent: itemWidth * 9 / 16 + 72,
                    ),
                    itemCount: controller.results.length,
                    itemBuilder: (context, index) => RoomCard(room: controller.results[index], dense: true),
                  ),
                ),
              ],
            );
          },
        );
      }),
    );
  }
}
