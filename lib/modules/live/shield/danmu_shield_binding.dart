import 'package:pure_live/core/index.dart';
import 'package:pure_live/modules/live/shield/danmu_shield_controller.dart';

class DanmuShieldBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => DanmuShieldController())];
  }
}
