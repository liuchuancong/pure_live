import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/account/yy/yy_cookie_controller.dart';

class YyCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => YyCookieBindingCookieController())];
  }
}
