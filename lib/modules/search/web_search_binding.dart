import 'package:get/get.dart';
import 'web_search_controller.dart';

class WebSearchBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => WebSearchController())];
  }
}
