import 'package:get/get.dart';

import 'history_controller.dart';


class HistoryBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => HistoryController())];
  }
}
