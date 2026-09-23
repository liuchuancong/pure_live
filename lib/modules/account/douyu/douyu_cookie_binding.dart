import 'package:pure_live/get/get.dart';
import 'package:pure_live/modules/account/douyu/douyu_cookie_controller.dart';

class DouyuCookieBinding extends Binding {
  @override
  List<Bind> dependencies() => [Bind.lazyPut(() => DouyuCookieController())];
}
