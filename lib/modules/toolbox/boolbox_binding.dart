import 'package:pure_live/core/index.dart';
import 'package:pure_live/modules/toolbox/toolbox_controller.dart';

class ToolBoxBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => ToolBoxController())];
  }
}
