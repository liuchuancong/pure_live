import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/favorite_areas_controller.dart';

class FavoriteAreasBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => FavoriteAreasController())];
  }
}
