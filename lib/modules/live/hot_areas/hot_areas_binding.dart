import 'package:pure_live/core/index.dart';
import 'package:pure_live/modules/live/hot_areas/hot_areas_controller.dart';

class HotAreasBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => HotAreasController())];
  }
}
