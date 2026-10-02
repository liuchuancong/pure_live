import 'package:pure_live/core/index.dart';
import 'package:pure_live/modules/live/playback/controllers/live_play_controller.dart';

class LivePlayBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => LivePlayController(room: Get.arguments, site: Get.parameters["site"] ?? ""))];
  }
}
