import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/utils.dart';

import '../../common/widgets/refresh_grid_util.dart';
import 'history_controller.dart';

class HistoryPage extends GetView<HistoryController> {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          scrolledUnderElevation: 0,
          title: Text(S.current.history),
          actions: [
            IconButton(
              tooltip: S.current.clear_history,
              icon: const Icon(Icons.cleaning_services_outlined),
              onPressed: () async {
                var result = await Utils.showAlertDialog(S.current.clear_history_confirm, title: S.current.clear_history);
                if (result) {
                  final SettingsService settings = Get.find<SettingsService>();
                  settings.clearHistory();
                  controller.refreshData();
                }
              },
            ),
          ],
        ),
        body: RefreshGridUtil.buildRoomCard(controller));
  }
}
