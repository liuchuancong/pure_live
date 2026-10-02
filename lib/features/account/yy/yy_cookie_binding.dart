import 'package:pure_live/core/index.dart';
import 'package:pure_live/features/account/yy/yy_cookie_controller.dart';

class YyCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => YyCookieBindingCookieController())];
  }
}
