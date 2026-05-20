import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/version/version_controller.dart';

class VersionBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => VersionController())];
  }
}
