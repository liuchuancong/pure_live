import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/account/soop/soop_cookie_controller.dart';

class SoopCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(SoopCookieBindingCookieController.new)];
  }
}
