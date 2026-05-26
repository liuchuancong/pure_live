import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';

class TagManagementBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => TagManagementController())];
  }
}
