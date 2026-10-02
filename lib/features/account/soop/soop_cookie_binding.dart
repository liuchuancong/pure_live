import 'package:pure_live/core/index.dart';
import 'package:pure_live/features/account/soop/soop_cookie_controller.dart';

class SoopCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => SoopCookieBindingCookieController())];
  }
}
