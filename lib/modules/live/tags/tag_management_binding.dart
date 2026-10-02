import 'package:pure_live/core/index.dart';
import 'package:pure_live/modules/live/tags/tag_management_controller.dart';

class TagManagementBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => TagManagementController())];
  }
}
