import 'package:pure_live/core/index.dart';
import 'package:pure_live/modules/live/areas/favorite_areas_controller.dart';

class FavoriteAreasBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => FavoriteAreasController())];
  }
}
