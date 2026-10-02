import 'package:pure_live/core/index.dart';
import 'package:pure_live/features/version/version_controller.dart';

class VersionBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => VersionController())];
  }
}
