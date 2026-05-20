import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/shield/danmu_shield_controller.dart';

class DanmuShieldBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => DanmuShieldController())];
  }
}
