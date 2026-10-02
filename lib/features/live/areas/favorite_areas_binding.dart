import 'package:pure_live/core/index.dart';
import 'package:pure_live/features/live/areas/favorite_areas_controller.dart';

class FavoriteAreasBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => FavoriteAreasController())];
  }
}
