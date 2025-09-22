import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/keep_alive_wrapper.dart';
import 'package:pure_live/modules/home/home_controller.dart';

class HomeMobileViewV2 extends GetView<HomeController> {
  const HomeMobileViewV2({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      bottomNavigationBar: TabBar(
        controller: controller.tabController,
        isScrollable: false,
        // tabAlignment: TabAlignment.center,
        // labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        // labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: const BoxDecoration(),
        tabs: [
          Tab(
            icon: const Icon(Icons.favorite_rounded),
            text: S.current.favorites_title,
          ),
          Tab(
            icon: const Icon(CustomIcons.popular),
            text: S.current.popular_title,
          ),
          Tab(
            icon: const Icon(Icons.area_chart_rounded),
            text: S.current.areas_title,
          ),
        ],
      ),
      body: TabBarView(
        controller: controller.tabController,
        children:
            controller.bodys.map((e) => KeepAliveWrapper(child: e)).toList(),
      ),
    );
  }
}
