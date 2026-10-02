import 'search_controller.dart';
import 'package:pure_live/core/index.dart' hide SearchController;

class SearchBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => SearchController())];
  }
}
