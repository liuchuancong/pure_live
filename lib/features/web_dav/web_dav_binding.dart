import 'package:pure_live/core/index.dart';
import 'package:pure_live/features/web_dav/web_dav_controller.dart';

class WebDavBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => WebDavPageController())];
  }
}
