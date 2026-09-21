import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/account/taobao/taobao_cookie_controller.dart';

class TaobaoCookieBinding extends Binding {
  @override
  List<Bind> dependencies() => [Bind.lazyPut(() => TaobaoCookieController())];
}
