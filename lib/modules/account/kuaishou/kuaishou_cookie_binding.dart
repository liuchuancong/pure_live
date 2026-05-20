import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/account/kuaishou/kuaishou_cookie_controller.dart';

class KuaishouCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => KuaishouCookieController())];
  }
}
