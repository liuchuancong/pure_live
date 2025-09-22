import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/settings/settings_card_v2.dart';
import 'package:pure_live/modules/hot_areas/hot_areas_controller.dart';
import 'package:pure_live/modules/util/site_logo_widget.dart';

class HotAreasPage extends GetView<HotAreasController> {
  const HotAreasPage({super.key});

  List<SwitchListTile> _initListData() {
    return controller.sites.map((site) {
      return SwitchListTile(
          title: Row(
            children: [
              SiteWidget.getSiteLogeImage(site.id)!,
              const SizedBox(width: 5),
              Text(Sites.getSiteName(site.id)),
            ],
          ),
          value: site.show,
          activeThumbColor: Theme.of(Get.context!).colorScheme.primary,
          onChanged: (bool value) => controller.onChanged(site.id, value));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.platform_show),
      ),
      body: Obx(() => ListView(
            children: [
              SettingsCardV2(
                children: _initListData(),
              )
            ],
          )),
    );
  }
}
