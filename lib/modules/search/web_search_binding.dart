import 'web_search_controller.dart';
import 'package:pure_live/common/index.dart';

class WebSearchBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => WebSearchController())];
  }
}
