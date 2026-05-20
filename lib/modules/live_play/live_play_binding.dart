import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';

class LivePlayBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => LivePlayController(room: Get.arguments, site: Get.parameters["site"] ?? ""))];
  }
}
