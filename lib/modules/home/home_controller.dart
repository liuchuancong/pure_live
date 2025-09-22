import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_page.dart';
import 'package:pure_live/modules/favorite/favorite_page.dart';
import 'package:pure_live/modules/popular/popular_page.dart';

class HomeController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  int index = 0;
  final isCustomSite = false.obs;

  HomeController() {
    final pIndex = 0;
    tabController = TabController(
      initialIndex: pIndex == -1 ? 0 : pIndex,
      length: bodys.length,
      vsync: this,
    );
    index = pIndex == -1 ? 0 : pIndex;
  }

  final List<GetView> bodys = const [
    FavoritePage(),
    PopularPage(),
    AreasPage(),
  ];

  @override
  void onInit() async {
    for (var site in bodys) {
      Get.put(site.controller);
    }
    super.onInit();
  }
}
